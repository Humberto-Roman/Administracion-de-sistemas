#Requires -RunAsAdministrator

param(
    [string]$ServerIP,
    [string]$ClientIP,
    [string]$Domain = "reprobados.com",
    [string]$InterfaceAlias,
    [switch]$Force,
    [int]$PrefixLength = 24
)

function Test-IPv4 {
    param([string]$IP)
    return $IP -match '^\d{1,3}(\.\d{1,3}){3}$'
}

function Get-ValidIP {
    param([string]$Message)
    do {
        $ip = Read-Host $Message
    } while (-not (Test-IPv4 $ip))
    return $ip
}

function Get-InternalInterface {
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -notmatch 'Loopback|Hyper-V|TAP' } |
        Select-Object -First 1 -ExpandProperty InterfaceAlias
}

function Set-StaticIP {
    param($InterfaceAlias, $IPAddress, $PrefixLength = 24)
    $existing = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($existing) { Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue }
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $null
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses ("127.0.0.1","8.8.8.8")
}

# Detectar interfaz interna
if (-not $InterfaceAlias) {
    $InterfaceAlias = Get-InternalInterface
    Write-Host "Interfaz detectada: $InterfaceAlias"
}

# Configurar IP estática si no se pasa o no existe
if (-not $ServerIP) {
    $ipInfo = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($ipInfo -and $ipInfo.PrefixOrigin -eq 'Manual') {
        $ServerIP = $ipInfo.IPAddress
        Write-Host "IP estática existente: $ServerIP"
    } else {
        $ServerIP = Get-ValidIP "IP estática del servidor DNS"
        $PrefixLength = Read-Host "Prefijo de red (CIDR, default 24)"
        if (-not $PrefixLength) { $PrefixLength = 24 }
        Set-StaticIP -InterfaceAlias $InterfaceAlias -IPAddress $ServerIP -PrefixLength $PrefixLength
    }
} else {
    Set-StaticIP -InterfaceAlias $InterfaceAlias -IPAddress $ServerIP -PrefixLength $PrefixLength
}

# Instalar rol DNS
$dnsFeature = Get-WindowsFeature -Name DNS
if (-not $dnsFeature.Installed) {
    Write-Host "Instalando rol DNS..." -ForegroundColor Cyan
    Install-WindowsFeature -Name DNS -IncludeManagementTools
} elseif ($Force) {
    Write-Host "Forzando reconfiguración..."
} else {
    Write-Host "[OK] Rol DNS ya instalado. Use -Force para reconfigurar."
    exit
}

# Obtener IP del cliente destino
if (-not $ClientIP) {
    $ClientIP = Get-ValidIP "IP del cliente destino (registros @ y www)"
}

# Crear zona
$zone = Get-DnsServerZone -Name $Domain -ErrorAction SilentlyContinue
if ($zone -and $Force) { Remove-DnsServerZone -Name $Domain -Force }
if (-not $zone -or $Force) {
    Add-DnsServerPrimaryZone -Name $Domain -ZoneFile "$Domain.dns"
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "@" -IPv4Address $ClientIP
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "www" -IPv4Address $ClientIP
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "ns1" -IPv4Address $ServerIP
    Set-DnsServerResourceRecord -ZoneName $Domain -Name "@" -NS -NameServer "ns1.$Domain"
    Write-Host "Zona $Domain creada."
} else {
    Write-Host "La zona ya existe, use -Force para sobrescribir."
    exit
}

# Verificar servicio
$dnsService = Get-Service DNS
if ($dnsService.Status -ne 'Running') { Start-Service DNS }

# Pruebas
Write-Host "`nPrueba local con Resolve-DnsName:"
Resolve-DnsName -Name $Domain -Server 127.0.0.1 -Type A
Resolve-DnsName -Name "www.$Domain" -Server 127.0.0.1 -Type A
Write-Host "`nPrueba con nslookup:"
nslookup $Domain 127.0.0.1
nslookup www.$Domain 127.0.0.1

Write-Host "===== CONFIGURACIÓN DNS COMPLETADA ====="