. (Join-Path $PSScriptRoot "Common.ps1")

Reset-KiitWifiCredential | Out-Null
Write-Host "KIIT Wi-Fi credentials updated. Re-run your usual connect script to apply them."
