#Requires -RunAsAdministrator

function Test-IPv4 {
    param([string]$IP)
    if ($IP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
        $octets = $IP -split '\.'
        foreach ($o in $octets) {
            if ([int]$o -lt 0 -or [int]$o -gt 255) { return $false }
        }
        return $true
    }
    return $false
}

function Read-ValidIP {
    param([string]$Message)
    do {
        $ip = Read-Host $Message
        if (-not (Test-IPv4 $ip)) {
            Write-Host "  [ERROR] Formato de IP no valido" -ForegroundColor Red
        }
    } while (-not (Test-IPv4 $ip))
    return $ip
}

function Install-DHCPRole {
    Write-Host "[*] Verificando rol DHCP..." -ForegroundColor Cyan
    $feature = Get-WindowsFeature -Name DHCP
    if (-not $feature.Installed) {
        Write-Host "  Instalando rol DHCP..." -ForegroundColor Yellow
        Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
        Restart-Computer -Force
    }
    Write-Host "  [OK] Rol DHCP instalado." -ForegroundColor Green
    
    Start-Service DHCPServer -ErrorAction SilentlyContinue
    Write-Host "  [OK] Servicio DHCP iniciado." -ForegroundColor Green
}

function New-DHCPConfiguration {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  CONFIGURACION DEL AMBITO DHCP" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    
    $scopeName = Read-Host "Nombre del ambito (Scope)"
    $scopeId = Read-ValidIP "Direccion de red (ej. 192.168.100.0)"
    $subnetMask = Read-Host "Mascara de subred (ej. 255.255.255.0)"
    $startRange = Read-ValidIP "Rango inicial (ej. 192.168.100.50)"
    
    do {
        $endRange = Read-ValidIP "Rango final (ej. 192.168.100.150)"
        $startOct = $startRange -split '\.'
        $endOct = $endRange -split '\.'
        if ([int]$endOct[3] -le [int]$startOct[3]) {
            Write-Host "  [ERROR] Rango final debe ser MAYOR que inicial" -ForegroundColor Red
        }
    } while ([int]$endOct[3] -le [int]$startOct[3])
    
    $leaseTime = Read-Host "Tiempo de concesion en segundos (600)"
    if ($leaseTime -eq "") { $leaseTime = "600" }
    $router = Read-ValidIP "Puerta de enlace - Router (ej. 192.168.100.1)"
    $dns = Read-ValidIP "Servidor DNS (ej. 192.168.100.1)"
    
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  RESUMEN" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Ambito: $scopeName" -ForegroundColor Green
    Write-Host "  Red: $scopeId" -ForegroundColor Green
    Write-Host "  Rango: $startRange -> $endRange" -ForegroundColor Green
    Write-Host "  Router: $router" -ForegroundColor Green
    Write-Host "  DNS: $dns" -ForegroundColor Green
    
    $confirm = Read-Host "`nAplicar configuracion? (S/n)"
    if ($confirm -ne "" -and $confirm -notmatch '^[Ss]$') { return }
    
    # Crear ambito con netsh (mas fiable que cmdlets)
    Write-Host "[*] Configurando ambito con netsh..." -ForegroundColor Cyan
    netsh dhcp server add scope $scopeId $subnetMask "$scopeName" 2>$null
    netsh dhcp server scope $scopeId add iprange $startRange $endRange 2>$null
    netsh dhcp server scope $scopeId set state 1 2>$null
    
    # Configurar opciones
    Write-Host "[*] Configurando opciones..." -ForegroundColor Cyan
    netsh dhcp server scope $scopeId add optionvalue 003 IPADDRESS $router 2>$null
    netsh dhcp server scope $scopeId add optionvalue 006 IPADDRESS $dns 2>$null
    netsh dhcp server scope $scopeId add optionvalue 015 STRING reprobados.com 2>$null
    
    Write-Host "  [OK] Servidor DHCP configurado!" -ForegroundColor Green
}

function Show-DHCPStatus {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  MONITOREO DHCP" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    $svc = Get-Service DHCPServer
    Write-Host "Estado: $($svc.Status)"
    Write-Host ""
    Write-Host "Ambitos:" -ForegroundColor Cyan
    netsh dhcp server show scope
    Write-Host ""
    Write-Host "Concesiones activas:" -ForegroundColor Cyan
    netsh dhcp server scope 192.168.100.0 show clients
    Read-Host "`nEnter para continuar"
}

# MENU
while ($true) {
    Clear-Host
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  DHCP - WINDOWS SERVER" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  1. Instalar / Configurar DHCP"
    Write-Host "  2. Monitorear concesiones"
    Write-Host "  3. Salir"
    $op = Read-Host "Opcion [1-3]"
    switch ($op) {
        '1' { Install-DHCPRole; New-DHCPConfiguration; Read-Host "Enter para continuar" }
        '2' { Show-DHCPStatus }
        '3' { exit }
    }
}