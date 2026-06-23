#!/bin/bash
echo "===== DIAGNÓSTICO DEL SISTEMA ====="
echo "Hostname: $(hostname)"
echo "IPs (IPv4):"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
echo "Espacio en disco (raíz):"
df -h /
echo "===================================="