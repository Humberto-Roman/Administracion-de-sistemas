function Test-IPv4 { param($IP) return $IP -match '^\d{1,3}(\.\d{1,3}){3}$' }
function Read-ValidIP { param($Message) do { $ip = Read-Host $Message } while (-not (Test-IPv4 $ip)); return $ip }
function Get-InternalInterface { Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -notmatch 'Loopback|Hyper-V|TAP' } | Select-Object -First 1 -ExpandProperty InterfaceAlias }
function Set-StaticIP { param($InterfaceAlias, $IPAddress, $PrefixLength=24)
    $existing = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($existing) { Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false }
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $null
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses ("127.0.0.1","8.8.8.8")
}
function Install-WindowsFeatureIdempotent { param($Name)
    $feat = Get-WindowsFeature -Name $Name
    if (-not $feat.Installed) { Install-WindowsFeature -Name $Name -IncludeManagementTools }
    else { Write-Host "[OK] $Name ya instalado." }
}