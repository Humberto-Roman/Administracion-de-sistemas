#!/bin/bash
DOMINIO="reprobados.com"
read -p "Controlador de dominio: " DC
read -p "Admin del dominio: " ADMIN
read -s -p "Contraseña: " PASS
echo ""
apt-get update && apt-get install -y realmd sssd sssd-tools adcli krb5-user samba-common-bin
echo "$PASS" | realm join --user="$ADMIN" "$DOMINIO"
cat <<EOF > /etc/sssd/sssd.conf
[sssd]
domains = $DOMINIO
config_file_version = 2
services = nss, pam
[domain/$DOMINIO]
ad_domain = $DOMINIO
krb5_realm = $(echo $DOMINIO | tr '[:lower:]' '[:upper:]')
realmd_tags = manages-system joined-with-adcli
id_provider = ad
default_shell = /bin/bash
fallback_homedir = /home/%u@%d
use_fully_qualified_names = True
EOF
chmod 600 /etc/sssd/sssd.conf
systemctl restart sssd
echo "%domain\ admins@$DOMINIO ALL=(ALL) ALL" > /etc/sudoers.d/ad-admins
chmod 440 /etc/sudoers.d/ad-admins
echo "Unión completada."