. (Join-Path $PSScriptRoot "Common.ps1")

$profileName = "KIIT-WIFI-DU"
$repoRoot = Split-Path $PSScriptRoot -Parent
$profileXmlPath = Join-Path $repoRoot "Campus-25\Wi-Fi-KIIT-WIFI-DU.xml"

# Delete an existing Wi-Fi profile
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c netsh wlan delete profile name=`"$profileName`""

# Add a new Wi-Fi profile
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c netsh wlan add profile filename=`"$profileXmlPath`""

# Inject the EAP (PEAP/MSCHAPv2) credential so Windows has a cached
# credential and never shows the interactive "Windows Security" sign-in box.
$cred = Get-KiitCredential
Set-WlanEapCredential -ProfileName $profileName -Credential $cred

# Connect to the Wi-Fi network
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c netsh wlan connect name=`"$profileName`""
