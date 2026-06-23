#!/bin/bash
set -e
function verificar_root() { [ "$EUID" -ne 0 ] && echo "Ejecute como root" && exit 1; }
function instalar_vsftpd() { dpkg -l vsftpd &>/dev/null && echo "[OK] vsftpd" || apt-get update -qq && apt-get install -y vsftpd; }

function configurar_ftp() {
    local ftp_root="/srv/ftp"
    mkdir -p "$ftp_root/http/linux/apache" "$ftp_root/http/linux/nginx" "$ftp_root/http/linux/tomcat"
    mkdir -p "$ftp_root/http/windows/iis" "$ftp_root/http/windows/apache" "$ftp_root/http/windows/nginx"
    useradd -r -d "$ftp_root" -s /bin/false ftpuser 2>/dev/null || true
    echo "ftpuser:ftppass" | chpasswd
    chown -R ftpuser:ftpuser "$ftp_root"

    cat <<EOF > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=21100
pasv_max_port=21110
local_root=$ftp_root
EOF

    systemctl restart vsftpd && systemctl enable vsftpd
    ufw allow 21/tcp; ufw allow 21100:21110/tcp
    echo "FTP listo: usuario ftpuser / ftppass"
}

verificar_root
instalar_vsftpd
configurar_ftp