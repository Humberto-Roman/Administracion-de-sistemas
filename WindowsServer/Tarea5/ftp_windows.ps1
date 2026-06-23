#Requires -RunAsAdministrator

$ftpRoot = "C:\srv\ftp"
$siteName = "FTP Reprobados"
$userName = "ftpuser"
$password = "ftppass"

# Instalar rol FTP
$features = @("Web-Server", "Web-Ftp-Server", "Web-Ftp-Service", "Web-Ftp-Ext")
foreach ($f in $features) {
    if (-not (Get-WindowsFeature -Name $f).Installed) {
        Install-WindowsFeature -Name $f -IncludeManagementTools
    }
}

# Crear estructura de directorios
$dirs = @("$ftpRoot\http\linux\apache", "$ftpRoot\http\linux\nginx", "$ftpRoot\http\linux\tomcat",
          "$ftpRoot\http\windows\iis", "$ftpRoot\http\windows\apache", "$ftpRoot\http\windows\nginx")
foreach ($d in $dirs) { New-Item -Path $d -ItemType Directory -Force }

# Crear usuario local
if (-not (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue)) {
    $pass = ConvertTo-SecureString $password -AsPlainText -Force
    New-LocalUser -Name $userName -Password $pass -PasswordNeverExpires
}
# Permisos en la carpeta
$acl = Get-Acl $ftpRoot
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($userName, "Read,Write", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $ftpRoot $acl

# Crear sitio FTP (si no existe)
$existing = Get-WebSite | Where-Object { $_.Name -eq $siteName }
if (-not $existing) {
    New-WebSite -Name $siteName -PhysicalPath $ftpRoot -Port 21 -Force
    Set-WebConfiguration -Filter "system.ftpServer/security/authentication/basicAuthentication" -Value @{enabled="true"}
    Set-WebConfiguration -Filter "system.ftpServer/security/authorization" -Value @{accessType="Allow"; users="*"; permissions="Read,Write"}
    Set-WebConfigurationProperty -Filter system.applicationHost/sites/site[@name='$siteName']/ftpServer/security/ssl -Name controlChannelPolicy -Value "SslAllow"
    Set-WebConfigurationProperty -Filter system.applicationHost/sites/site[@name='$siteName']/ftpServer/security/ssl -Name dataChannelPolicy -Value "SslAllow"
    Restart-WebItem "IIS:\Sites\$siteName"
    Write-Host "Sitio FTP '$siteName' creado en puerto 21."
} else {
    Write-Host "[OK] El sitio FTP ya existe."
}

# Firewall
New-NetFirewallRule -DisplayName "FTP Server" -Direction Inbound -LocalPort 21 -Protocol TCP -Action Allow
Write-Host "FTP listo. Usuario: $userName, Contraseña: $password"