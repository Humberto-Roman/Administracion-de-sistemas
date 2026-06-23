#Requires -RunAsAdministrator

function Test-IPv4 {
    param([string]$IP)
    return $IP -match '^\d{1,3}(\.\d{1,3}){3}$'
}

function Read-ValidIP {
    param([string]$Message)
    do {
        $ip = Read-Host $Message
    } while (-not (Test-IPv4 $ip))
    return $ip
}

function Install-DHCPRole {
    $feature = Get-WindowsFeature -Name DHCP
    if (-not $feature.Installed) {
        Write-Host "Instalando rol DHCP..." -ForegroundColor Cyan
        Install-WindowsFeature -Name DHCP -IncludeManagementTools
        netsh dhcp add securitygroups
        Restart-Service dhcpserver
    } else {
        Write-Host "[OK] Rol DHCP ya instalado." -ForegroundColor Green
    }
}

function New-DHCPConfiguration {
    Write-Host "===== CONFIGURACIÓN DEL ÁMBITO DHCP =====" -ForegroundColor Yellow
    $scopeName = Read-Host "Nombre del ámbito"
    $scopeId = Read-ValidIP "Dirección de red (Scope ID, ej. 192.168.100.0)"
    $startRange = Read-ValidIP "Rango inicial (ej. 192.168.100.50)"
    $endRange = Read-ValidIP "Rango final (ej. 192.168.100.150)"
    $subnetMask = Read-ValidIP "Máscara de subred (ej. 255.255.255.0)"
    $leaseTime = Read-Host "Tiempo de concesión (segundos, default 600)"
    if (-not $leaseTime) { $leaseTime = 600 }
    $router = Read-ValidIP "Puerta de enlace (Router)"
    $dns = Read-ValidIP "Servidor DNS"

    Write-Host "Creando ámbito..." -ForegroundColor Green
    Add-DhcpServerv4Scope -Name $scopeName -StartRange $startRange -EndRange $endRange -SubnetMask $subnetMask -LeaseDuration ([TimeSpan]::FromSeconds($leaseTime)) -State Active
    Set-DhcpServerv4OptionValue -ScopeId $scopeId -Router $router
    Set-DhcpServerv4OptionValue -ScopeId $scopeId -DnsServer $dns
    Set-DhcpServerv4OptionValue -ScopeId $scopeId -DnsDomain "reprobados.com"
    Add-DhcpServerInDC -DnsName $env:COMPUTERNAME -IPAddress (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" }).IPAddress
    Write-Host "Ámbito '$scopeName' listo." -ForegroundColor Green
}

function Show-DHCPStatus {
    $service = Get-Service DHCPServer
    Write-Host "Estado del servicio: $($service.Status)"
    $scope = Read-Host "Scope ID para consultar leases (ej. 192.168.100.0)"
    Get-DhcpServerv4Lease -ScopeId $scope | Format-Table IPAddress, ClientId, HostName, AddressState
    Read-Host "Enter para continuar"
}

function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host "===== MENÚ PRINCIPAL DHCP (Windows) =====" -ForegroundColor Cyan
        Write-Host "1. Instalar/Configurar servidor DHCP"
        Write-Host "2. Monitorear concesiones activas"
        Write-Host "3. Salir"
        $op = Read-Host "Seleccione una opción"
        switch ($op) {
            '1' { Install-DHCPRole; New-DHCPConfiguration }
            '2' { Show-DHCPStatus }
            '3' { exit }
            default { Write-Host "Opción inválida." }
        }
    }
}

Show-Menu