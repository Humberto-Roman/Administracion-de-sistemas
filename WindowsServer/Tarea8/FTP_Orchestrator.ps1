#Requires -RunAsAdministrator
$FtpServer = "192.168.100.1"
$FtpUser = "ftpuser"
$FtpPass = "ftppass"
$FtpBase = "/http"

function Get-FtpList($Path) {
    $uri = "ftp://${FtpServer}/${Path}/"
    $request = [System.Net.FtpWebRequest]::Create($uri)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $request.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $FtpPass)
    $request.EnableSsl = $true
    $response = $request.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $list = $reader.ReadToEnd()
    $reader.Close(); $response.Close()
    $items = $list -split "`n" | ForEach-Object { ($_ -split '\s+')[-1] } | Where-Object { $_ -and $_ -ne '.' -and $_ -ne '..' }
    return $items
}

function Download-Ftp($Remote, $Local) {
    Invoke-WebRequest -Uri "ftp://${FtpServer}/${Remote}" -Credential (New-Object PSCredential($FtpUser, (ConvertTo-SecureString $FtpPass -AsPlainText -Force))) -OutFile $Local
}

function Install-FromFTP {
    $oses = Get-FtpList "$FtpBase"
    if (-not $oses) { Write-Error "No se encontraron OS en FTP"; return }
    Write-Host "Sistemas disponibles:"; for ($i=0; $i -lt $oses.Count; $i++) { Write-Host "$($i+1). $($oses[$i])" }
    $idx = [int](Read-Host "Número") - 1; $os = $oses[$idx]
    $services = Get-FtpList "$FtpBase/$os"
    Write-Host "Servicios:"; for ($i=0; $i -lt $services.Count; $i++) { Write-Host "$($i+1). $($services[$i])" }
    $idx = [int](Read-Host "Número") - 1; $svc = $services[$idx]
    $files = Get-FtpList "$FtpBase/$os/$svc" | Where-Object { $_ -match '\.(msi|zip|exe|deb)$' }
    Write-Host "Instaladores:"; for ($i=0; $i -lt $files.Count; $i++) { Write-Host "$($i+1). $($files[$i])" }
    $idx = [int](Read-Host "Número") - 1; $file = $files[$idx]
    $localPath = "C:\Temp\$file"
    Download-Ftp "$FtpBase/$os/$svc/$file" $localPath
    # Verificar hash si existe
    $hashFile = "$file.sha256"
    try {
        $hashUri = "ftp://${FtpServer}/${FtpBase}/$os/$svc/$hashFile"
        $web = New-Object System.Net.WebClient
        $web.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $FtpPass)
        $hashContent = $web.DownloadString($hashUri)
        $expected = ($hashContent -split '\s+')[0].ToLower()
        $localHash = (Get-FileHash -Path $localPath -Algorithm SHA256).Hash.ToLower()
        if ($localHash -eq $expected) { Write-Host "Integridad OK" } else { Write-Error "Hash no coincide"; return }
    } catch { Write-Host "Sin archivo de hash, continuando." }
    # Instalar según extensión
    switch -Wildcard ($file) {
        '*.msi' { Start-Process msiexec.exe -ArgumentList "/i `"$localPath`" /quiet /norestart" -Wait }
        '*.zip' { Expand-Archive -Path $localPath -DestinationPath "C:\$svc" -Force }
    }
    Write-Host "Instalación completada."
}

Install-FromFTP