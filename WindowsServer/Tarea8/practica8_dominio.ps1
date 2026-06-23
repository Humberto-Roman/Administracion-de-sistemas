#Requires -Modules ActiveDirectory, GroupPolicy -RunAsAdministrator

Import-Module ActiveDirectory, GroupPolicy -ErrorAction Stop

# Instalar características
$features = @("FS-Resource-Manager", "RSAT-AD-PowerShell", "GPMC")
foreach ($f in $features) {
    if (-not (Get-WindowsFeature -Name $f).Installed) { Install-WindowsFeature -Name $f -IncludeManagementTools }
}

# Crear OUs
$ous = @("Cuates", "No Cuates")
$domainDN = (Get-ADDomain).DistinguishedName
foreach ($ou in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $ou } -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN
    }
}

# Importar usuarios desde CSV
$csvPath = Read-Host "Ruta del CSV (ej. C:\usuarios.csv)"
if (Test-Path $csvPath) {
    Import-Csv $csvPath | ForEach-Object {
        $ou = if ($_.Departamento -eq "Cuates") { "Cuates" } else { "No Cuates" }
        if (-not (Get-ADUser -Filter { SamAccountName -eq $_.SamAccountName })) {
            New-ADUser -Name $_.Nombre -SamAccountName $_.SamAccountName -UserPrincipalName "$($_.SamAccountName)@$((Get-ADDomain).DNSRoot)" -GivenName $_.Nombre -Surname $_.Apellido -Department $_.Departamento -Path "OU=$ou,$domainDN" -AccountPassword (ConvertTo-SecureString $_.Password -AsPlainText -Force) -Enabled $true
        }
    }
}

# Configurar Logon Hours (función auxiliar)
function Set-LogonHours {
    param($Group)
    $bytes = New-Object byte[] 21
    function Set-Bit($hour) { $bytes[$hour / 8] = $bytes[$hour / 8] -bor (1 -shl ($hour % 8)) }
    if ($Group -eq "Cuates") {
        for ($d=1; $d -le 5; $d++) { for ($h=8; $h -le 15; $h++) { Set-Bit ($d*24+$h) } }
    } else {
        for ($d=1; $d -le 5; $d++) {
            for ($h=15; $h -le 23; $h++) { Set-Bit ($d*24+$h) }
            if ($d -lt 5) { for ($h=0; $h -le 2; $h++) { Set-Bit (($d+1)*24+$h) } }
        }
    }
    Get-ADUser -Filter { Department -eq $Group } | Set-ADUser -LogonHours $bytes
}
Set-LogonHours "Cuates"
Set-LogonHours "No Cuates"

# GPO forzar cierre
$gpoName = "Forzar Cierre de Sesion"
if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
    $gpo = New-GPO -Name $gpoName
    Set-GPRegistryValue -Name $gpoName -Key "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -ValueName "ForceAutoLogoff" -Type DWord -Value 1
    foreach ($ou in @("OU=Cuates,$domainDN","OU=No Cuates,$domainDN")) { New-GPLink -Name $gpoName -Target $ou }
}

# FSRM Quotas y Screening
Import-Module FSRM
$quotaTemplates = @{"Cuota 5 MB"=5MB; "Cuota 10 MB"=10MB}
foreach ($t in $quotaTemplates.Keys) {
    if (-not (Get-FsrmQuotaTemplate -Name $t -ErrorAction SilentlyContinue)) { New-FsrmQuotaTemplate -Name $t -Size $quotaTemplates[$t] }
}
$sharePath = "C:\Perfiles"
New-Item -Path $sharePath -ItemType Directory -Force
Get-ADUser -Filter * -Properties Department | ForEach-Object {
    $dir = Join-Path $sharePath $_.SamAccountName
    New-Item -Path $dir -ItemType Directory -Force
    $template = if ($_.Department -eq "Cuates") { "Cuota 10 MB" } else { "Cuota 5 MB" }
    New-FsrmQuota -Path $dir -Template $template -ErrorAction SilentlyContinue
}
$fileGroup = "Bloqueo Multimedia/Ejecutables"
if (-not (Get-FsrmFileGroup -Name $fileGroup -ErrorAction SilentlyContinue)) {
    New-FsrmFileGroup -Name $fileGroup -IncludePattern @("*.mp3","*.mp4","*.exe","*.msi")
}
New-FsrmFileScreen -Path $sharePath -IncludeGroup $fileGroup -Active -ErrorAction SilentlyContinue

# AppLocker
Import-Module AppLocker
$notepadHash = (Get-FileHash "$env:SystemRoot\System32\notepad.exe" -Algorithm SHA256).Hash
$ruleAllow = New-AppLockerPolicy -RuleType Exe -User "DOMINIO\Cuates" -Action Allow -Condition FilePath -Path "$env:SystemRoot\System32\notepad.exe"
$ruleDeny = New-AppLockerPolicy -RuleType Exe -User "DOMINIO\No Cuates" -Action Deny -Condition Hash -Hash $notepadHash -HashType SHA256
$policy = Get-AppLockerPolicy -Effective -ErrorAction SilentlyContinue
if (-not $policy) { $policy = New-AppLockerPolicy -RuleType Exe -Action Allow -User Everyone -Condition Path -Path "*" } # default allow
$merged = Merge-AppLockerPolicy -Policy $policy, $ruleAllow, $ruleDeny
Set-AppLockerPolicy -Policy $merged
Set-Service AppIDSvc -StartupType Automatic; Start-Service AppIDSvc

Write-Host "Configuración completada."