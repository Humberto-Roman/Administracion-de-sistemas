Write-Host "===== DIAGNÓSTICO DEL SISTEMA =====" -ForegroundColor Cyan
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "`nIPs (IPv4):"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } |
    Format-Table IPAddress, InterfaceAlias -AutoSize
Write-Host "`nEspacio en disco (unidades fijas):"
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } |
    Format-Table Name,
        @{Name="Usado(GB)";Expression={[math]::Round($_.Used/1GB,2)}},
        @{Name="Libre(GB)";Expression={[math]::Round($_.Free/1GB,2)}} -AutoSize
Write-Host "====================================="