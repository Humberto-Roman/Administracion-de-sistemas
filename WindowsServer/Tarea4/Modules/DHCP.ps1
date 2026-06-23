. "$PSScriptRoot\Comunes.ps1"
function Install-DhcpRole { Install-WindowsFeatureIdempotent DHCP }
function New-DhcpScope { param($ScopeId,$StartRange,$EndRange,$SubnetMask)
    Add-DhcpServerv4Scope -Name "Red Interna" -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -Router $ScopeId.1 -DnsServer $ScopeId.1
}
function Install-And-ConfigureDHCP {
    $iface = Get-InternalInterface
    $serverIP = Read-ValidIP "IP del servidor DHCP"
    Set-StaticIP -InterfaceAlias $iface -IPAddress $serverIP
    Install-DhcpRole
    $scope = Read-ValidIP "Subred (Scope ID)"
    $start = Read-ValidIP "Rango inicial"
    $end = Read-ValidIP "Rango final"
    $mask = Read-Host "Máscara de subred"
    New-DhcpScope -ScopeId $scope -StartRange $start -EndRange $end -SubnetMask $mask
    Restart-Service DHCPServer
}