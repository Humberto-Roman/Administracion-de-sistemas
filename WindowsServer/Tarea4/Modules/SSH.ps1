function Install-SSH {
    $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name }
    Set-Service sshd -StartupType Automatic
    Start-Service sshd
    New-NetFirewallRule -DisplayName "OpenSSH Server" -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow
    Write-Host "SSH habilitado en puerto 22"
}