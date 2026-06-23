#!/bin/bash
# ============================================================
#  Script de automatización DHCP - Servidor Linux
#  Práctica 2 - Versión final corregida
# ============================================================

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function verificar_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${ROJO}ERROR: Debe ejecutar como root (sudo).${NC}"
        exit 1
    fi
}

function validar_ip() {
    local ip="$1"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
        [ "$o1" -le 255 ] && [ "$o2" -le 255 ] && [ "$o3" -le 255 ] && [ "$o4" -le 255 ] && return 0
    fi
    return 1
}

function validar_subred() {
    [ "${1%.*}" = "${2%.*}" ]
}

function mostrar_error() {
    echo -e "\n${ROJO}╔════════════════════════════════════════════╗${NC}" >&2
    echo -e "${ROJO}║  ERROR: $1${NC}" >&2
    echo -e "${ROJO}║  $2${NC}" >&2
    echo -e "${ROJO}╚════════════════════════════════════════════╝${NC}\n" >&2
}

function mostrar_ok() {
    echo -e "  ${VERDE}[OK]${NC} $1" >&2
}

function mostrar_info() {
    echo -e "  ${CYAN}[*]${NC} $1" >&2
}

function mostrar_advertencia() {
    echo -e "\n${AMARILLO}╔════════════════════════════════════════════╗${NC}" >&2
    echo -e "${AMARILLO}║  ADVERTENCIA:${NC}" >&2
    echo -e "${AMARILLO}║  $1${NC}" >&2
    echo -e "${AMARILLO}╚════════════════════════════════════════════╝${NC}\n" >&2
}

function preguntar_ip() {
    local mensaje="$1" ip
    while true; do
        read -p "$(echo -e ${AMARILLO}"$mensaje: "${NC})" ip
        [ -z "$ip" ] && mostrar_error "Campo vacío" "Debe ingresar una dirección IP." && continue
        if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            mostrar_error "Formato inválido" "Ejemplo: 192.168.100.1\n  Usted ingresó: '$ip'"
            continue
        fi
        IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
        if [ "$o1" -gt 255 ] || [ "$o2" -gt 255 ] || [ "$o3" -gt 255 ] || [ "$o4" -gt 255 ]; then
            mostrar_error "Octeto fuera de rango" "Cada número debe estar entre 0 y 255."
            continue
        fi
        echo "$ip"
        return 0
    done
}

function preguntar_mascara() {
    local validas="255.0.0.0 255.128.0.0 255.192.0.0 255.224.0.0 255.240.0.0 255.248.0.0 255.252.0.0 255.254.0.0 255.255.0.0 255.255.128.0 255.255.192.0 255.255.224.0 255.255.240.0 255.255.248.0 255.255.252.0 255.255.254.0 255.255.255.0 255.255.255.128 255.255.255.192 255.255.255.224 255.255.255.240 255.255.255.248 255.255.255.252"
    local mascara
    while true; do
        mascara=$(preguntar_ip "Máscara de subred (ej. 255.255.255.0)")
        [[ " $validas " =~ " $mascara " ]] && echo "$mascara" && return 0
        mostrar_error "Máscara no estándar" "'$mascara' no es una máscara válida.\n  Ejemplo: 255.255.255.0"
    done
}

function preguntar_rango() {
    local tipo="$1" otro="$2" ip
    while true; do
        ip=$(preguntar_ip "Rango $tipo (ej. 192.168.100.50)")
        if [ "$tipo" = "final" ] && [ -n "$otro" ]; then
            ! validar_subred "$otro" "$ip" && mostrar_error "Subred diferente" "Inicial ($otro) y final ($ip) no coinciden en subred." && continue
            IFS='.' read -r i1 i2 i3 i4 <<< "$otro"
            IFS='.' read -r f1 f2 f3 f4 <<< "$ip"
            [ "$f1" = "$i1" ] && [ "$f2" = "$i2" ] && [ "$f3" = "$i3" ] && [ "$f4" -le "$i4" ] && mostrar_error "Rango inválido" "Final ($ip) debe ser MAYOR que inicial ($otro)." && continue
        fi
        echo "$ip" && return 0
    done
}

function preguntar_tiempo() {
    local t
    while true; do
        read -p "$(echo -e ${AMARILLO}"Tiempo de concesión en segundos (default 600): "${NC})" t
        t=${t:-600}
        [[ $t =~ ^[0-9]+$ ]] && [ "$t" -gt 0 ] && echo "$t" && return 0
        mostrar_error "Valor inválido" "Debe ser un número entero positivo."
    done
}

function preguntar_nombre() {
    local n
    while true; do
        read -p "$(echo -e ${AMARILLO}"Nombre del ámbito (Scope): "${NC})" n
        [ -z "$n" ] && mostrar_error "Campo vacío" "El nombre no puede estar vacío." && continue
        [[ $n =~ [\&\;\`\$\|] ]] && mostrar_error "Caracteres no permitidos" "Evite: & ; \` \$ |" && continue
        echo "$n" && return 0
    done
}

function preguntar_dns() {
    local router="$1" servidor="$2" dns
    while true; do
        dns=$(preguntar_ip "Servidor DNS (ej. 192.168.100.1)")
        if [ "$dns" = "$router" ] && [ "$dns" = "$servidor" ]; then
            mostrar_advertencia "DNS mismo IP que Router/DHCP ($dns). Válido solo en redes pequeñas."
            read -p "$(echo -e ${AMARILLO}"¿Usar otra IP para DNS? (s/N): "${NC})" cambiar
            [[ $cambiar =~ ^[Ss]$ ]] && continue
        fi
        echo "$dns" && return 0
    done
}

# ============================================================
#  FUNCIONES DE SISTEMA (SIN MENSAJES QUE CONTAMINEN SALIDAS)
# ============================================================

function detectar_interfaz_interna() {
    local interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(enp|eth|ens)' | grep -v 'lo'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        read -p "Interfaz manual: " iface
        echo "$iface"
        return
    fi
    
    # Buscar la que NO sea NAT
    for iface in "${interfaces[@]}"; do
        local ip_actual=$(ip -4 addr show dev "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [ -z "$ip_actual" ]; then
            echo "$iface"
            return
        elif [[ ! $ip_actual =~ ^10\.0\.2\. ]]; then
            echo "$iface"
            return
        fi
    done
    
    # Si no se detectó, devolver la primera
    echo "${interfaces[0]}"
}

function obtener_ip_actual() {
    ip -4 addr show dev "$1" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
}

function configurar_ip_estatica() {
    local iface="$1" ip="$2" mascara="$3" prefijo=24
    
    case "$mascara" in
        255.0.0.0) prefijo=8 ;;
        255.255.0.0) prefijo=16 ;;
        255.255.255.0) prefijo=24 ;;
    esac
    
    cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
    $iface:
      dhcp4: false
      addresses:
        - $ip/$prefijo
EOF
    chmod 600 /etc/netplan/01-netcfg.yaml
    netplan apply 2>/dev/null
    sleep 2
}

# ============================================================
#  FUNCIONES PRINCIPALES
# ============================================================

function instalar_dhcp() {
    echo -e "\n${CYAN}[*] Verificando instalación de isc-dhcp-server...${NC}"
    if dpkg -l 2>/dev/null | grep -qw isc-dhcp-server; then
        echo -e "  ${VERDE}[OK]${NC} isc-dhcp-server ya está instalado."
        return
    fi
    echo -e "  ${AMARILLO}Instalando...${NC}"
    apt-get update -qq 2>/dev/null
    apt-get install -y isc-dhcp-server 2>/dev/null
    echo -e "  ${VERDE}[OK]${NC} Instalación completada."
}

function configurar_dhcp() {
    echo -e "\n${AZUL}╔══════════════════════════════════════════╗${NC}"
    echo -e "${AZUL}║  CONFIGURACIÓN DEL SERVIDOR DHCP         ║${NC}"
    echo -e "${AZUL}╚══════════════════════════════════════════╝${NC}\n"
    
    NOMBRE_AMBITO=$(preguntar_nombre)
    echo ""
    IP_RED=$(preguntar_ip "Dirección de red (ej. 192.168.100.0)")
    echo ""
    MASCARA=$(preguntar_mascara)
    echo ""
    INICIO=$(preguntar_rango "inicial" "")
    echo ""
    FIN=$(preguntar_rango "final" "$INICIO")
    echo ""
    LEASE_TIME=$(preguntar_tiempo)
    echo ""
    ROUTER=$(preguntar_ip "Puerta de enlace - Router (ej. 192.168.100.1)")
    echo ""
    
    # Obtener IP actual del servidor para comparar con DNS
    INTERFAZ=$(detectar_interfaz_interna)
    IP_SERVIDOR=$(obtener_ip_actual "$INTERFAZ")
    
    DNS=$(preguntar_dns "$ROUTER" "$IP_SERVIDOR")
    
    # --- RESUMEN ---
    echo -e "\n${AZUL}╔══════════════════════════════════════════╗${NC}"
    echo -e "${AZUL}║  RESUMEN DE CONFIGURACIÓN                ║${NC}"
    echo -e "${AZUL}╚══════════════════════════════════════════╝${NC}\n"
    echo -e "  Ámbito:      ${VERDE}$NOMBRE_AMBITO${NC}"
    echo -e "  Red:         ${VERDE}$IP_RED${NC}"
    echo -e "  Máscara:     ${VERDE}$MASCARA${NC}"
    echo -e "  Rango:       ${VERDE}$INICIO → $FIN${NC}"
    echo -e "  Concesión:   ${VERDE}$LEASE_TIME seg${NC}"
    echo -e "  Router:      ${VERDE}$ROUTER${NC}"
    echo -e "  DNS:         ${VERDE}$DNS${NC}\n"
    
    read -p "$(echo -e ${AMARILLO}"¿Aplicar esta configuración? (S/n): "${NC})" CONFIRMAR
    CONFIRMAR=${CONFIRMAR:-S}
    [[ ! $CONFIRMAR =~ ^[Ss]$ ]] && echo -e "${AMARILLO}Cancelado.${NC}" && return 1
    
    # --- CONFIGURAR IP ESTÁTICA ---
    echo ""
    IP_ACTUAL=$(obtener_ip_actual "$INTERFAZ")
    
    if [ -z "$IP_ACTUAL" ]; then
        echo -e "  ${AMARILLO}[!]${NC} La interfaz $INTERFAZ no tiene IP."
        IP_SERVIDOR=$(preguntar_ip "IP estática para el servidor DHCP (ej. 192.168.100.1)")
        configurar_ip_estatica "$INTERFAZ" "$IP_SERVIDOR" "$MASCARA"
    fi
    
    # Verificar que la IP se aplicó
    IP_FINAL=$(obtener_ip_actual "$INTERFAZ")
    echo -e "  ${VERDE}[OK]${NC} IP configurada en $INTERFAZ: ${VERDE}$IP_FINAL${NC}"
    
    # --- CREAR CONFIGURACIÓN DHCP (MÉTODO PROBADO) ---
    echo -e "\n  ${CYAN}[*]${NC} Creando /etc/dhcp/dhcpd.conf..."
    
    rm -f /etc/dhcp/dhcpd.conf
    
    tee /etc/dhcp/dhcpd.conf > /dev/null << ENDCONF
authoritative;
default-lease-time ${LEASE_TIME};
max-lease-time $((LEASE_TIME * 2));

subnet ${IP_RED} netmask ${MASCARA} {
    range ${INICIO} ${FIN};
    option routers ${ROUTER};
    option domain-name-servers ${DNS};
    option domain-name "reprobados.com";
}
ENDCONF

    echo -e "  ${VERDE}[OK]${NC} Archivo creado."
    
    # --- CONFIGURAR INTERFAZ DE ESCUCHA ---
    echo -e "  ${CYAN}[*]${NC} Configurando interfaz de escucha: $INTERFAZ"
    tee /etc/default/isc-dhcp-server > /dev/null << ENDINT
INTERFACESv4="${INTERFAZ}"
ENDINT
    
    # --- VALIDAR SINTAXIS ---
    echo -e "  ${CYAN}[*]${NC} Validando sintaxis..."
    if dhcpd -t -cf /etc/dhcp/dhcpd.conf 2>&1; then
        echo -e "  ${VERDE}[OK]${NC} Sintaxis correcta."
    else
        echo -e "  ${ROJO}[ERROR]${NC} Error de sintaxis."
        return 1
    fi
    
    # --- REINICIAR SERVICIO ---
    echo -e "  ${CYAN}[*]${NC} Reiniciando servicio..."
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server 2>/dev/null
    
    if systemctl is-active --quiet isc-dhcp-server; then
        echo -e "\n${VERDE}╔══════════════════════════════════════════╗${NC}"
        echo -e "${VERDE}║  ¡SERVIDOR DHCP ACTIVO Y FUNCIONANDO!   ║${NC}"
        echo -e "${VERDE}╚══════════════════════════════════════════╝${NC}\n"
    else
        echo -e "\n${ROJO}[ERROR] El servicio no inició.${NC}"
        systemctl status isc-dhcp-server --no-pager -l
        return 1
    fi
}

function monitorear_dhcp() {
    echo -e "\n${AZUL}╔══════════════════════════════════════════╗${NC}"
    echo -e "${AZUL}║  MONITOREO DHCP                          ║${NC}"
    echo -e "${AZUL}╚══════════════════════════════════════════╝${NC}\n"
    
    echo -n "  Estado: "
    systemctl is-active --quiet isc-dhcp-server && echo -e "${VERDE}ACTIVO${NC}" || echo -e "${ROJO}INACTIVO${NC}"
    
    echo -e "\n  ${CYAN}Concesiones activas:${NC}"
    if [ -f /var/lib/dhcp/dhcpd.leases ]; then
        while IFS= read -r linea; do
            [[ $linea =~ lease\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]] && ip="${BASH_REMATCH[1]}" && read -r sig && [[ $sig =~ "binding state active" ]] && echo -e "    ${VERDE}●${NC} $ip"
        done < <(grep -E "lease|binding" /var/lib/dhcp/dhcpd.leases)
    else
        echo -e "    ${AMARILLO}Sin leases aún.${NC}"
    fi
    echo ""
    read -p "$(echo -e ${AMARILLO}"Presione Enter para continuar...${NC}")"
}

function menu() {
    while true; do
        clear
        echo -e "${AZUR}╔══════════════════════════════════════════╗${NC}"
        echo -e "${AZUR}║  CONFIGURACIÓN AUTOMÁTICA DHCP - LINUX  ║${NC}"
        echo -e "${AZUR}╚══════════════════════════════════════════╝${NC}\n"
        echo -e "  ${AMARILLO}1.${NC} Instalar / Configurar servidor DHCP"
        echo -e "  ${AMARILLO}2.${NC} Monitorear concesiones activas"
        echo -e "  ${AMARILLO}3.${NC} Salir\n"
        read -p "$(echo -e ${VERDE}"  Opción [1-3]: "${NC})" op
        case $op in
            1) instalar_dhcp; configurar_dhcp; read -p "$(echo -e ${AMARILLO}"Enter para continuar...${NC}")" ;;
            2) monitorear_dhcp ;;
            3) echo -e "\n${VERDE}Saliendo...${NC}\n"; exit 0 ;;
            *) echo -e "${ROJO}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================================
verificar_root
menu
