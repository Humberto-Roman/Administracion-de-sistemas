#!/bin/bash
set -e
DOMINIO="reprobados.com"
ZONA="/var/cache/bind/db.$DOMINIO"
NAMED_CONF="/etc/bind/named.conf.local"
INTERFAZ=""

function validar_ip() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}
function preguntar_ip() {
    local msg="$1" ip
    while true; do
        read -p "$msg: " ip
        validar_ip "$ip" && echo "$ip" && return
        echo "Formato inválido"
    done
}

function verificar_root() {
    [ "$EUID" -ne 0 ] && echo "Ejecute como root" && exit 1
}

function detectar_interfaz() {
    INTERFAZ=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(enp|eth|ens)' | grep -v lo | head -1)
    if [ -z "$INTERFAZ" ]; then
        read -p "Interfaz interna: " INTERFAZ
    fi
}

function tiene_ip_estatica() {
    ip -4 addr show dev "$INTERFAZ" | grep -q 'inet ' && ! ip -4 addr show dev "$INTERFAZ" | grep -q dynamic
}

function configurar_ip() {
    local ip="$1" mask="${2:-24}"
    cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFAZ:
      addresses:
        - $ip/$mask
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF
    netplan apply && sleep 2
}

function instalar_bind() {
    dpkg -l bind9 &>/dev/null || apt-get update && apt-get install -y bind9 bind9utils bind9-doc
    systemctl enable bind9
}

function crear_zona() {
    local ip_servidor="$1" ip_cliente="$2"
    cat <<EOF > "$ZONA"
\$TTL 604800
@   IN SOA ns1.$DOMINIO. admin.$DOMINIO. (
        $(date +%Y%m%d)01
        604800
        86400
        2419200
        604800 )
@   IN NS  ns1.$DOMINIO.
@   IN A   $ip_cliente
www IN A   $ip_cliente
ns1 IN A   $ip_servidor
EOF
    chown bind:bind "$ZONA" && chmod 644 "$ZONA"
    if ! grep -q "zone \"$DOMINIO\"" "$NAMED_CONF"; then
        cat <<EOF >> "$NAMED_CONF"
zone "$DOMINIO" {
    type master;
    file "$ZONA";
};
EOF
    fi
    named-checkconf && named-checkzone "$DOMINIO" "$ZONA"
    systemctl restart bind9
}

verificar_root
detectar_interfaz

if tiene_ip_estatica; then
    IP_SERVER=$(ip -4 addr show dev "$INTERFAZ" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo "IP estática existente: $IP_SERVER"
else
    IP_SERVER=$(preguntar_ip "IP estática para el servidor DNS")
    read -p "Máscara CIDR [24]: " MASK; MASK=${MASK:-24}
    configurar_ip "$IP_SERVER" "$MASK"
fi

instalar_bind
IP_CLIENT=$(preguntar_ip "IP del cliente destino (registros A)")
crear_zona "$IP_SERVER" "$IP_CLIENT"
echo "DNS configurado"