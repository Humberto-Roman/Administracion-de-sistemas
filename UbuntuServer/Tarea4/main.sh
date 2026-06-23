#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/comunes.sh"
source "$DIR/lib/diagnostico.sh"
source "$DIR/lib/dns.sh"
source "$DIR/lib/dhcp.sh"
source "$DIR/lib/ssh.sh"

function menu() {
    echo -e "\n1. Diagnóstico\n2. DNS\n3. DHCP\n4. SSH\n5. Salir"
    read -p "Opción: " op
    case $op in
        1) diagnostico_sistema;;
        2) instalar_y_configurar_dns;;
        3) instalar_y_configurar_dhcp;;
        4) instalar_ssh;;
        5) exit;;
    esac
    menu
}
verificar_root; menu