#!/bin/bash
source "$(dirname "$0")/comunes.sh"
function instalar_ssh() {
    verificar_root
    instalar_paquete openssh-server
    systemctl enable ssh --now
    ufw allow 22/tcp 2>/dev/null || true
    echo "SSH activo"
}