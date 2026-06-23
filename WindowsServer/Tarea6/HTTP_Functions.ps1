#Requires -RunAsAdministrator

. "$PSScriptRoot\Comunes.ps1"  # asume que Comunes.ps1 está en el mismo directorio o ajusta ruta

function Check-PortInUse($Port) {
    $conn = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue
    return $conn.TcpTestSucceeded
}

function Install-ChocoIfNeeded {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Install-IIS {
    Install-WindowsFeatureIdempotent Web-Server
    Install-WindowsFeatureIdempotent Web-Mgmt-Console
    $port = do {
        $p = Read-Host "Puerto de escucha (80/8080/8888)"
    } while ($p -notmatch '^\d+$' -or [int]$p -lt 80 -or [int]$p -gt 65535 -or (Check-PortInUse $p))
    Remove-WebBinding -Name "Default Web Site" -Port 80 -ErrorAction SilentlyContinue
    New-WebBinding -Name "Default Web Site" -Port $port -Protocol http
    Set-WebBinding -Name "Default Web Site" -BindingInformation "*:${port}:"
    if ($port -ne 80) { Remove-NetFirewallRule -DisplayName "HTTP-80" -ErrorAction SilentlyContinue }
    New-NetFirewallRule -DisplayName "HTTP-$port" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow
    Set-WebConfigurationProperty -Filter system.webServer/security/requestFiltering -Name removeServerHeader -Value $true
    Remove-WebConfigurationProperty -Filter system.webServer/httpProtocol/customHeaders -Name "X-Powered-By" -ErrorAction SilentlyContinue
    $html = "<html><body><h1>IIS - Puerto $port</h1></body></html>"
    Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $html
    Write-Host "IIS configurado en puerto $port"
}

function Install-ApacheWin {
    Install-ChocoIfNeeded
    $versions = (choco list apache-httpd --all --limit-output | Select-String -Pattern '^\S+\|(\S+)' | ForEach-Object { $_.Matches.Groups[1].Value }) | Sort-Object -Unique -Descending
    Write-Host "Versiones disponibles: $($versions -join ', ')"
    $version = Read-Host "Versión exacta (ej. 2.4.59)"
    $port = Read-Host "Puerto"
    while ($port -notmatch '^\d+$' -or (Check-PortInUse $port)) { $port = Read-Host "Puerto inválido/en uso" }
    choco install apache-httpd --version=$version -y --params='"/quiet"'
    $conf = "C:\Apache24\conf\httpd.conf"
    (Get-Content $conf) -replace 'Listen 80', "Listen $port" | Set-Content $conf
    Add-Content $conf "ServerTokens Prod"
    Add-Content $conf "ServerSignature Off"
    Add-Content $conf "TraceEnable off"
    $html = "<html><body><h1>Apache $version - Puerto $port</h1></body></html>"
    Set-Content -Path "C:\Apache24\htdocs\index.html" -Value $html
    Restart-Service Apache2.4
    if ($port -ne 80) { Remove-NetFirewallRule -DisplayName "Apache-80" -ErrorAction SilentlyContinue }
    New-NetFirewallRule -DisplayName "Apache-$port" -LocalPort $port -Protocol TCP -Action Allow
    Write-Host "Apache $version en puerto $port"
}

function Install-NginxWin {
    Install-ChocoIfNeeded
    $versions = (choco list nginx --all --limit-output | Select-String -Pattern '^\S+\|(\S+)' | ForEach-Object { $_.Matches.Groups[1].Value }) | Sort-Object -Unique -Descending
    Write-Host "Versiones: $($versions -join ', ')"
    $version = Read-Host "Versión exacta"
    $port = Read-Host "Puerto"
    while ($port -notmatch '^\d+$' -or (Check-PortInUse $port)) { $port = Read-Host "Puerto inválido/en uso" }
    choco install nginx --version=$version -y
    $conf = "C:\nginx\conf\nginx.conf"
    (Get-Content $conf) -replace 'listen\s+80;', "listen $port;" | Set-Content $conf
    if (!(Select-String -Path $conf -Pattern "server_tokens off")) { (Get-Content $conf) -replace 'http {', "http {`n    server_tokens off;" | Set-Content $conf }
    $html = "<html><body><h1>Nginx $version - Puerto $port</h1></body></html>"
    Set-Content -Path "C:\nginx\html\index.html" -Value $html
    Restart-Service nginx
    if ($port -ne 80) { Remove-NetFirewallRule -DisplayName "Nginx-80" -ErrorAction SilentlyContinue }
    New-NetFirewallRule -DisplayName "Nginx-$port" -LocalPort $port -Protocol TCP -Action Allow
    Write-Host "Nginx $version en puerto $port"
}

function Menu-WebServers {
    while ($true) {
        Write-Host "`n1. IIS`n2. Apache`n3. Nginx`n4. Volver"
        $op = Read-Host "Seleccione"
        switch ($op) {
            '1' { Install-IIS }
            '2' { Install-ApacheWin }
            '3' { Install-NginxWin }
            '4' { return }
        }
    }
}

Menu-WebServers