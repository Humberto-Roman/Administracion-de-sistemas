#!/bin/bash
FTP_HOST="192.168.100.1"
FTP_USER="ftpuser"
FTP_PASS="ftppass"
FTP_BASE="/http"

function ftp_listar() { curl -s --ftp-ssl -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$1/" | grep -oP '(?<=href=")[^"]*' | grep -v '^\.\./$' | sed 's|/$||'; }
function ftp_descargar() { curl -# --ftp-ssl -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$1" -o "$2"; }

function instalar_desde_ftp() {
    echo "Conectando al FTP..."
    local oses=($(ftp_listar "$FTP_BASE"))
    [ ${#oses[@]} -eq 0 ] && return
    echo "OS disponibles:"; for i in "${!oses[@]}"; do echo "$((i+1)). ${oses[$i]}"; done
    read -p "Número: " idx_os; carpeta_os="${oses[$((idx_os-1))]}"
    local servicios=($(ftp_listar "$FTP_BASE/$carpeta_os"))
    echo "Servicios:"; for i in "${!servicios[@]}"; do echo "$((i+1)). ${servicios[$i]}"; done
    read -p "Número: " idx_srv; servicio="${servicios[$((idx_srv-1))]}"
    local archivos=($(ftp_listar "$FTP_BASE/$carpeta_os/$servicio" | grep -E '\.(deb|tar\.gz|sh)$'))
    echo "Instaladores:"; for i in "${!archivos[@]}"; do echo "$((i+1)). ${archivos[$i]}"; done
    read -p "Número: " idx_file; archivo="${archivos[$((idx_file-1))]}"
    ftp_descargar "$FTP_BASE/$carpeta_os/$servicio/$archivo" "/tmp/$archivo"
    # Verificar hash si existe .sha256
    if ftp_listar "$FTP_BASE/$carpeta_os/$servicio" | grep -q "${archivo}.sha256"; then
        ftp_descargar "$FTP_BASE/$carpeta_os/$servicio/${archivo}.sha256" "/tmp/${archivo}.sha256"
        cd /tmp; sha256sum -c "${archivo}.sha256" && echo "OK" || { echo "Hash mismatch"; return; }
    fi
    case "$archivo" in
        *.deb) dpkg -i "/tmp/$archivo"; apt-get install -f -y;;
        *.tar.gz) echo "Instalación manual requerida";;
        *.sh) bash "/tmp/$archivo";;
    esac
}