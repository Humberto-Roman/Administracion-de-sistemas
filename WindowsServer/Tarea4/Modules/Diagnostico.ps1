. "$PSScriptRoot\Comunes.ps1" # opcional si se carga desde Main
function Get-Diagnostico {
    Write-Host "Hostname: $env:COMPUTERNAME"
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' } | Format-Table IPAddress, InterfaceAlias
    Get-PSDrive -PSProvider FileSystem | Where-Object Used | Format-Table Name, @{n='Usado(GB)';e={[math]::Round($_.Used/1GB,2)}}, @{n='Libre(GB)';e={[math]::Round($_.Free/1GB,2)}} -AutoSize
}