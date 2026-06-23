#!/bin/bash
function diagnostico_sistema() {
    echo "Hostname: $(hostname)"
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
    df -h /
}