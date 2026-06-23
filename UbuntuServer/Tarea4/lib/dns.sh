#!/bin/bash
source "$(dirname "$0")/comunes.sh"
function instalar_bind() { instalar_paquete bind9; instalar_paquete bind9utils; systemctl enable bind9; }
function crear_zona_dns() {
    local dominio="$1" ip_srv="$2" ip_cli="$3"
    local f="/var/cache/bind/db.$dominio"
    cat <<EOF >"$f"
\$TTL 604800
@   IN SOA ns1.$dominio. admin.$dominio. ($(date +%Y%m%d)01 604800 86400 2419200 604800)
@   IN NS ns1.$dominio.
@   IN A  $ip_cli
www IN A  $ip_cli
ns1 IN A  $ip_srv
EOF
    chown bind:bind "$f" && chmod 644 "$f"
    grep -q "zone \"$dominio\"" /etc/bind/named.conf.local || echo "zone \"$dominio\" { type master; file \"$f\"; };" >> /etc/bind/named.conf.local
    named-checkconf && named-checkzone "$dominio" "$f"
    systemctl restart bind9
}
function instalar_y_configurar_dns() {
    verificar_root
    local iface=$(detectar_interfaz_interna)
    local ip_srv=$(preguntar_ip "IP del servidor DNS")
    configurar_ip_estatica "$iface" "$ip_srv"
    instalar_bind
    local ip_cli=$(preguntar_ip "IP del cliente destino")
    crear_zona_dns "reprobados.com" "$ip_srv" "$ip_cli"
}