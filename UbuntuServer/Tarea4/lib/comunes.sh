#!/bin/bash
function validar_ip() { [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; }
function preguntar_ip() { local msg="$1" ip; while true; do read -p "$msg: " ip; validar_ip "$ip" && echo "$ip" && return; echo "Inválido"; done; }
function verificar_root() { [ "$EUID" -ne 0 ] && echo "Se requiere root" && exit 1; }
function instalar_paquete() { dpkg -l "$1" &>/dev/null && echo "[OK] $1" || { apt-get update -qq && apt-get install -y "$1"; }; }
function detectar_interfaz_interna() { ip -o link show | awk -F': ' '{print $2}' | grep -E '^(enp|eth|ens)' | grep -v lo | head -1; }
function configurar_ip_estatica() { local if="$1" ip="$2" mask="${3:-24}"; cat <<EOF >/etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    $if:
      addresses: [$ip/$mask]
      nameservers: {addresses: [8.8.8.8,1.1.1.1]}
EOF
netplan apply; sleep 2; }