. "$PSScriptRoot\Comunes.ps1"
function Install-DnsRole { Install-WindowsFeatureIdempotent DNS }
function New-DnsZoneAndRecords { param($Domain,$ServerIP,$ClientIP)
    $zone = Get-DnsServerZone -Name $Domain -ErrorAction SilentlyContinue
    if ($zone) { Remove-DnsServerZone -Name $Domain -Force }
    Add-DnsServerPrimaryZone -Name $Domain -ZoneFile "$Domain.dns"
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "@" -IPv4Address $ClientIP
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "www" -IPv4Address $ClientIP
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "ns1" -IPv4Address $ServerIP
    Set-DnsServerResourceRecord -ZoneName $Domain -Name "@" -NS -NameServer "ns1.$Domain"
}
function Install-And-ConfigureDNS {
    $iface = Get-InternalInterface
    $serverIP = Read-ValidIP "IP del servidor DNS"
    Set-StaticIP -InterfaceAlias $iface -IPAddress $serverIP
    Install-DnsRole
    $clientIP = Read-ValidIP "IP del cliente destino"
    New-DnsZoneAndRecords -Domain "reprobados.com" -ServerIP $serverIP -ClientIP $clientIP
    Restart-Service DNS
}