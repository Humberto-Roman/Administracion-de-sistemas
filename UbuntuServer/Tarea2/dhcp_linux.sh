#!/bin/bash
set -e
function verificar_root() {
    [ "$(id -u)" -ne 0 ] && echo "Ejecute como root" && exit 1
}
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

function instalar_dhcp() {
    if dpkg -l | grep -qw isc-dhcp-server; then
        echo "[OK] isc-dhcp-server ya instalado"
    else
        apt-get update -qq && apt-get install -y isc-dhcp-server
    fi
}

function configurar_dhcp() {
    read -p "Nombre del ámbito: " NOMBRE
    IP_RED=$(preguntar_ip "Red (ej. 192.168.100.0)")
    MASK=$(preguntar_ip "Máscara (ej. 255.255.255.0)")
    INICIO=$(preguntar_ip "Rango inicial")
    FIN=$(preguntar_ip "Rango final")
    read -p "Tiempo concesión (s) [600]: " LEASE; LEASE=${LEASE:-600}
    ROUTER=$(preguntar_ip "Router/Gateway")
    DNS=$(preguntar_ip "DNS")

    [ "${INICIO%.*}" != "${FIN%.*}" ] && echo "Error: rango inconsistente" && exit 2

    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(enp|eth|ens)' | grep -v lo | head -1)
    [ -z "$IFACE" ] && read -p "Interfaz: " IFACE
    echo "Interfaz: $IFACE"

    cat <<EOF > /etc/dhcp/dhcpd.conf
authoritative;
default-lease-time $LEASE;
max-lease-time $((LEASE*2));
subnet $IP_RED netmask $MASK {
    range $INICIO $FIN;
    option routers $ROUTER;
    option domain-name-servers $DNS;
    option domain-name "reprobados.com";
}
EOF
    sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server
    dhcpd -t -cf /etc/dhcp/dhcpd.conf && systemctl restart isc-dhcp-server && systemctl enable isc-dhcp-server
    echo "DHCP configurado"
}

function monitorear() {
    echo "Estado: $(systemctl is-active isc-dhcp-server)"
    grep -E "lease|binding" /var/lib/dhcp/dhcpd.leases | tail -20
    read -p "Enter para continuar"
}

function menu() {
    while true; do
        echo -e "\n1. Instalar/Configurar DHCP\n2. Monitorear\n3. Salir"
        read -p "Opción: " op
        case $op in
            1) instalar_dhcp; configurar_dhcp;;
            2) monitorear;;
            3) exit;;
        esac
    done
}

verificar_root; menu