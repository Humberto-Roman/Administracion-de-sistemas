#!/bin/bash
CERT_DIR="/etc/ssl/reprobados"
DOMAIN="reprobados.com"
function generar_certificado() {
    mkdir -p "$CERT_DIR"
    [ -f "$CERT_DIR/$DOMAIN.crt" ] || openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/$DOMAIN.key" -out "$CERT_DIR/$DOMAIN.crt" \
        -subj "/C=MX/ST=Estado/L=Ciudad/O=Reprobados/CN=$DOMAIN"
    chmod 600 "$CERT_DIR/$DOMAIN.key"
}
function activar_ssl_apache() {
    generar_certificado
    a2enmod ssl; a2ensite default-ssl 2>/dev/null
    cat <<EOF > /etc/apache2/sites-available/default-ssl.conf
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerName $DOMAIN
        DocumentRoot /var/www/html
        SSLEngine on
        SSLCertificateFile $CERT_DIR/$DOMAIN.crt
        SSLCertificateKeyFile $CERT_DIR/$DOMAIN.key
        Header always set Strict-Transport-Security "max-age=31536000"
    </VirtualHost>
</IfModule>
EOF
    a2ensite default-ssl
    systemctl restart apache2
}
function activar_ssl_nginx() {
    generar_certificado
    cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80; server_name $DOMAIN; return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl; server_name $DOMAIN;
    ssl_certificate $CERT_DIR/$DOMAIN.crt;
    ssl_certificate_key $CERT_DIR/$DOMAIN.key;
    add_header Strict-Transport-Security "max-age=31536000";
    root /var/www/html; index index.html;
}
EOF
    systemctl restart nginx
}
function activar_ssl_vsftpd() {
    generar_certificado
    grep -q "ssl_enable=YES" /etc/vsftpd.conf && return
    cat <<EOF >> /etc/vsftpd.conf
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
rsa_cert_file=$CERT_DIR/$DOMAIN.crt
rsa_private_key_file=$CERT_DIR/$DOMAIN.key
EOF
    systemctl restart vsftpd
}
function menu_ssl() {
    echo -e "\n1. Apache SSL\n2. Nginx SSL\n3. vsftpd SSL\n4. Volver"
    read -p "Opción: " opt
    case $opt in
        1) activar_ssl_apache;;
        2) activar_ssl_nginx;;
        3) activar_ssl_vsftpd;;
        4) return;;
    esac
    menu_ssl
}