#Requires -RunAsAdministrator
$domain = "reprobados.com"

function Generate-Cert {
    $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$domain" }
    if (-not $cert) { $cert = New-SelfSignedCertificate -DnsName $domain -CertStoreLocation "Cert:\LocalMachine\My" }
    return $cert
}

function Enable-IIS-SSL {
    $cert = Generate-Cert
    if (-not (Get-WebBinding -Name "Default Web Site" -Protocol https -ErrorAction SilentlyContinue)) {
        New-WebBinding -Name "Default Web Site" -Protocol https -Port 443 -IPAddress "*"
    }
    & netsh http add sslcert ipport=0.0.0.0:443 certhash=$($cert.Thumbprint) appid="{00000000-0000-0000-0000-000000000000}" 2>$null
    Add-WebConfigurationProperty -Filter system.webServer/httpProtocol/customHeaders -Name "." -Value @{name="Strict-Transport-Security";value="max-age=31536000"}
    Restart-Service W3SVC
    Write-Host "IIS SSL activado"
}

function Enable-IISFTP-SSL {
    $cert = Generate-Cert
    $siteName = "FTP Reprobados"
    Set-WebConfiguration -Filter "system.ftpServer/security/ssl" -Value @{serverCertHash=$cert.Thumbprint; controlChannelPolicy="SslRequire"; dataChannelPolicy="SslRequire"} -Location "$siteName"
    Restart-Service FTPSVC
    Write-Host "IIS-FTP SSL activado"
}

function Enable-ApacheSSL {
    $cert = Generate-Cert
    $sslDir = "C:\Apache24\conf\ssl"
    if (-not (Test-Path $sslDir)) { mkdir $sslDir }
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$sslDir\$domain.key" -out "$sslDir\$domain.crt" -subj "/CN=$domain"
    $conf = @"
Listen 443
<VirtualHost _default_:443>
    DocumentRoot "C:/Apache24/htdocs"
    ServerName $domain
    SSLEngine on
    SSLCertificateFile "$sslDir\$domain.crt"
    SSLCertificateKeyFile "$sslDir\$domain.key"
    Header always set Strict-Transport-Security "max-age=31536000"
</VirtualHost>
"@
    Set-Content "C:\Apache24\conf\extra\httpd-ssl.conf" -Value $conf
    Add-Content "C:\Apache24\conf\httpd.conf" "Include conf/extra/httpd-ssl.conf"
    Restart-Service Apache2.4
    Write-Host "Apache SSL activado"
}

function Enable-NginxSSL {
    $sslDir = "C:\nginx\conf\ssl"
    if (-not (Test-Path $sslDir)) { mkdir $sslDir }
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$sslDir\$domain.key" -out "$sslDir\$domain.crt" -subj "/CN=$domain"
    $sslBlock = @"
server {
    listen 443 ssl;
    server_name $domain;
    ssl_certificate $sslDir\$domain.crt;
    ssl_certificate_key $sslDir\$domain.key;
    add_header Strict-Transport-Security "max-age=31536000" always;
    location / { root html; index index.html; }
}
"@
    Add-Content "C:\nginx\conf\nginx.conf" $sslBlock
    Restart-Service nginx
    Write-Host "Nginx SSL activado"
}

function SSL-Menu {
    while ($true) {
        Write-Host "`n1. IIS HTTP`n2. IIS FTP`n3. Apache`n4. Nginx`n5. Volver"
        $op = Read-Host "Seleccione"
        switch ($op) {
            '1' { Enable-IIS-SSL }
            '2' { Enable-IISFTP-SSL }
            '3' { Enable-ApacheSSL }
            '4' { Enable-NginxSSL }
            '5' { return }
        }
    }
}

SSL-Menu