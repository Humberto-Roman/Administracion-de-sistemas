#!/bin/bash
source "$(dirname "$0")/comunes.sh"
WEB_ROOT_APACHE="/var/www/html"
WEB_ROOT_NGINX="/var/www/html"
TOMCAT_HOME="/opt/tomcat"

function puerto_en_uso() { ss -tulpn | grep -q ":$1 "; }

function instalar_apache() {
    instalar_paquete apache2
    echo "Versión: $(apache2 -v | grep -oP 'Apache/\K[^ ]+')"
    while true; do
        read -p "Puerto (80/8080/8888): " PUERTO
        [[ $PUERTO =~ ^[0-9]+$ ]] && [ "$PUERTO" -ge 80 -a "$PUERTO" -le 65535 ] && ! puerto_en_uso "$PUERTO" && break
        echo "Puerto inválido o en uso"
    done
    sed -i "s/Listen 80/Listen $PUERTO/" /etc/apache2/ports.conf
    [ "$PUERTO" != "80" ] && ufw delete allow 80/tcp
    ufw allow "$PUERTO"/tcp
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    echo "TraceEnable off" >> /etc/apache2/conf-available/security.conf
    a2enmod headers
    echo "Header always set X-Frame-Options SAMEORIGIN" > /etc/apache2/conf-available/security-headers.conf
    echo "Header always set X-Content-Type-Options nosniff" >> /etc/apache2/conf-available/security-headers.conf
    a2enconf security-headers
    echo "<html><body><h1>Apache - Puerto $PUERTO</h1></body></html>" > $WEB_ROOT_APACHE/index.html
    systemctl restart apache2
}

function instalar_nginx() {
    instalar_paquete nginx
    echo "Versión: $(nginx -v 2>&1 | grep -oP 'nginx/\K[^ ]+')"
    while true; do
        read -p "Puerto: " PUERTO
        [[ $PUERTO =~ ^[0-9]+$ ]] && [ "$PUERTO" -ge 80 -a "$PUERTO" -le 65535 ] && ! puerto_en_uso "$PUERTO" && break
    done
    sed -i "s/listen 80 default_server/listen $PUERTO default_server/" /etc/nginx/sites-available/default
    [ "$PUERTO" != "80" ] && ufw delete allow 80/tcp
    ufw allow "$PUERTO"/tcp
    sed -i '/http {/a \    server_tokens off;' /etc/nginx/nginx.conf
    echo "add_header X-Frame-Options SAMEORIGIN;" > /etc/nginx/conf.d/security-headers.conf
    echo "add_header X-Content-Type-Options nosniff;" >> /etc/nginx/conf.d/security-headers.conf
    echo "<html><body><h1>Nginx - Puerto $PUERTO</h1></body></html>" > $WEB_ROOT_NGINX/index.html
    systemctl restart nginx
}

function instalar_tomcat() {
    apt-get install -y default-jre
    LTS="9.0.78"; LATEST="10.1.25"
    echo "1. LTS $LTS  2. Latest $LATEST"
    read -p "Versión: " ver; [ "$ver" = "2" ] && TOMCAT_VERSION="$LATEST" || TOMCAT_VERSION="$LTS"
    MAJOR=$(echo $TOMCAT_VERSION | cut -d. -f1)
    wget -qO- "https://dlcdn.apache.org/tomcat/tomcat-$MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz" | tar xz -C /opt
    mv /opt/apache-tomcat-$TOMCAT_VERSION $TOMCAT_HOME
    useradd -r -d $TOMCAT_HOME -s /bin/false tomcat
    chown -R tomcat:tomcat $TOMCAT_HOME
    while true; do
        read -p "Puerto (8080/8888): " PUERTO
        [[ $PUERTO =~ ^[0-9]+$ ]] && [ "$PUERTO" -ge 1024 ] && ! puerto_en_uso "$PUERTO" && break
    done
    sed -i "s/port=\"8080\"/port=\"$PUERTO\"/" $TOMCAT_HOME/conf/server.xml
    [ "$PUERTO" != "8080" ] && ufw delete allow 8080/tcp
    ufw allow "$PUERTO"/tcp
    echo "<html><body><h1>Tomcat $TOMCAT_VERSION - Puerto $PUERTO</h1></body></html>" > $TOMCAT_HOME/webapps/ROOT/index.html
    cat <<EOF > /etc/systemd/system/tomcat.service
[Unit] Description=Tomcat
[Service] Type=forking User=tomcat ExecStart=$TOMCAT_HOME/bin/startup.sh ExecStop=$TOMCAT_HOME/bin/shutdown.sh
[Install] WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable tomcat && systemctl start tomcat
}

function menu_servidores_web() {
    echo -e "\n1. Apache\n2. Nginx\n3. Tomcat\n4. Volver"
    read -p "Opción: " opt
    case $opt in
        1) instalar_apache;;
        2) instalar_nginx;;
        3) instalar_tomcat;;
        4) return;;
    esac
    menu_servidores_web
}