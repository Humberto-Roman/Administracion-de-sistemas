#!/bin/bash
source "$(dirname "$0")/comunes.sh"
function instalar_dhcp() { instalar_paquete isc-dhcp-server; }
function configurar_dhcp() {
    local iface="$1" subnet="$2" mask="$3" start="$4" end="$5"
    cat <<EOF >/etc/dhcp/dhcpd.conf
authoritative;
default-lease-time 600; max-lease-time 1200;
subnet $subnet netmask $mask {
    range $start $end;
    option routers $subnet.1;
    option domain-name-servers $subnet.1;
    option domain-name "reprobados.com";
}
EOF
    sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$iface\"/" /etc/default/isc-dhcp-server
    dhcpd -t -cf /etc/dhcp/dhcpd.conf && systemctl restart isc-dhcp-server && systemctl enable isc-dhcp-server
}
function instalar_y_configurar_dhcp() {
    verificar_root
    local iface=$(detectar_interfaz_interna)
    local ip_srv=$(preguntar_ip "IP del servidor DHCP")
    configurar_ip_estatica "$iface" "$ip_srv"
    instalar_dhcp
    local subnet=$(preguntar_ip "Subred")
    local mask=$(preguntar_ip "Máscara")
    local ini=$(preguntar_ip "Rango inicial")
    local fin=$(preguntar_ip "Rango final")
    configurar_dhcp "$iface" "$subnet" "$mask" "$ini" "$fin"
}