#Requires -RunAsAdministrator
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\Modules\Comunes.ps1"
. "$scriptPath\Modules\Diagnostico.ps1"
. "$scriptPath\Modules\DNS.ps1"
. "$scriptPath\Modules\DHCP.ps1"
. "$scriptPath\Modules\SSH.ps1"

function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host "===== MENÚ PRINCIPAL (Windows) =====" -ForegroundColor Cyan
        Write-Host "1. Diagnóstico del sistema"
        Write-Host "2. Configurar servidor DNS"
        Write-Host "3. Configurar servidor DHCP"
        Write-Host "4. Instalar/Habilitar SSH"
        Write-Host "5. Salir"
        $op = Read-Host "Seleccione una opción"
        switch ($op) {
            '1' { Get-Diagnostico }
            '2' { Install-And-ConfigureDNS }
            '3' { Install-And-ConfigureDHCP }
            '4' { Install-SSH }
            '5' { exit }
            default { Write-Host "Opción inválida" }
        }
        Read-Host "Presione Enter para continuar"
    }
}

Show-Menu