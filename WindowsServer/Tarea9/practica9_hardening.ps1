#Requires -Modules ActiveDirectory, GroupPolicy -RunAsAdministrator

Import-Module ActiveDirectory, GroupPolicy

# 1. Crear usuarios delegados
$domainDN = (Get-ADDomain).DistinguishedName
$delegated = @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")
foreach ($user in $delegated) {
    if (-not (Get-ADUser -Filter { SamAccountName -eq $user })) {
        New-ADUser -Name $user -SamAccountName $user -AccountPassword (ConvertTo-SecureString "TempP@ssw0rd" -AsPlainText -Force) -Enabled $true
    }
}

# 2. RBAC con dsacls
dsacls "OU=Cuates,$domainDN" /I:S /G "DOMAIN\admin_identidad:CCDC;Reset Password;user"
dsacls "OU=No Cuates,$domainDN" /I:S /G "DOMAIN\admin_identidad:CCDC;Reset Password;user"
dsacls $domainDN /I:S /D "DOMAIN\admin_storage:Reset Password"
dsacls $domainDN /I:S /G "DOMAIN\admin_politicas:GR"
dsacls $domainDN /I:S /D "DOMAIN\admin_politicas:Write"
dsacls "CN=Policies,CN=System,$domainDN" /I:S /G "DOMAIN\admin_politicas:CCDC;Write" /T
dsacls $domainDN /I:S /D "DOMAIN\admin_auditoria:Write"
Add-LocalGroupMember -Group "Event Log Readers" -Member "DOMAIN\admin_auditoria" -ErrorAction SilentlyContinue

# 3. Fine-Grained Password Policies
$adminPol = Get-ADFineGrainedPasswordPolicy -Identity "Admins-Policy" -ErrorAction SilentlyContinue
if (-not $adminPol) {
    New-ADFineGrainedPasswordPolicy -Name "Admins-Policy" -Precedence 10 -ComplexityEnabled $true -MinPasswordLength 12 -MaxPasswordAge "30.00:00:00" -LockoutThreshold 3 -LockoutDuration "00:30:00" -LockoutObservationWindow "00:30:00"
    Add-ADFineGrainedPasswordPolicySubject -Identity "Admins-Policy" -Subjects "Domain Admins"
    foreach ($u in $delegated) { Add-ADFineGrainedPasswordPolicySubject -Identity "Admins-Policy" -Subjects $u }
}
$stdPol = Get-ADFineGrainedPasswordPolicy -Identity "Users-Policy" -ErrorAction SilentlyContinue
if (-not $stdPol) {
    New-ADFineGrainedPasswordPolicy -Name "Users-Policy" -Precedence 20 -ComplexityEnabled $true -MinPasswordLength 8 -MaxPasswordAge "42.00:00:00" -LockoutThreshold 5 -LockoutDuration "00:30:00" -LockoutObservationWindow "00:30:00"
    Add-ADFineGrainedPasswordPolicySubject -Identity "Users-Policy" -Subjects "Domain Users"
}

# 4. Auditoría avanzada
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable
Set-GPRegistryValue -Name "Default Domain Policy" -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -ValueName "AuditBaseObjects" -Type DWord -Value 3
gpupdate /force

# 5. MFA (WinOTP descarga y bloqueo)
$winotpUrl = "https://github.com/winotp/winotp/releases/download/v1.4.0/WinOTP-1.4.0.msi"
$installer = "$env:TEMP\WinOTP.msi"
Invoke-WebRequest -Uri $winotpUrl -OutFile $installer
Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /quiet /norestart" -Wait
# Ajustar umbral de bloqueo para Admins-Policy (ya en 3)
Set-ADFineGrainedPasswordPolicy -Identity "Admins-Policy" -LockoutThreshold 3 -LockoutDuration "00:30:00" -LockoutObservationWindow "00:30:00"

Write-Host "Hardening completado. Configure los tokens TOTP manualmente."