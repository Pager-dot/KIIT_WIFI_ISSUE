# Shared helpers for KIIT Wi-Fi scripts: credential caching + programmatic
# EAP credential injection so Windows never has to show the interactive
# "Windows Security" sign-in box (PEAP / MSCHAPv2, EAP type 25 outer / 26 inner).

$script:KiitWifiCredentialPath = Join-Path $env:LOCALAPPDATA "KiitWifi\credential.xml"

function Get-KiitCredential {
    if (Test-Path $script:KiitWifiCredentialPath) {
        return Import-Clixml -Path $script:KiitWifiCredentialPath
    }

    $cred = Get-Credential -Message "Enter your KIIT Wi-Fi credentials"

    $credDir = Split-Path $script:KiitWifiCredentialPath -Parent
    if (-not (Test-Path $credDir)) {
        New-Item -ItemType Directory -Path $credDir -Force | Out-Null
    }
    $cred | Export-Clixml -Path $script:KiitWifiCredentialPath

    return $cred
}

function Reset-KiitWifiCredential {
    if (Test-Path $script:KiitWifiCredentialPath) {
        Remove-Item -Path $script:KiitWifiCredentialPath -Force
    }
    return Get-KiitCredential
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WlanEap {
    [DllImport("wlanapi.dll")]
    public static extern int WlanOpenHandle(
        uint dwClientVersion,
        IntPtr pReserved,
        out uint pdwNegotiatedVersion,
        out IntPtr phClientHandle);

    [DllImport("wlanapi.dll")]
    public static extern int WlanCloseHandle(
        IntPtr hClientHandle,
        IntPtr pReserved);

    [DllImport("wlanapi.dll", CharSet = CharSet.Unicode)]
    public static extern int WlanSetProfileEapXmlUserData(
        IntPtr hClientHandle,
        [MarshalAs(UnmanagedType.LPStruct)] Guid pInterfaceGuid,
        [MarshalAs(UnmanagedType.LPWStr)] string strProfileName,
        uint dwFlags,
        [MarshalAs(UnmanagedType.LPWStr)] string strEapXmlUserData,
        IntPtr pReserved);
}
"@

# WLAN_SET_EAPHOST_DATA_ALL_USERS = 0x00000001; we only set the current user's data.
$script:WLAN_SET_EAPHOST_DATA_CURRENT_USER = 0

function Set-WlanEapCredential {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [Parameter(Mandatory = $true)][System.Management.Automation.PSCredential]$Credential
    )

    $username = $Credential.UserName
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Credential.Password)
    try {
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)

        $escapedUser = [System.Security.SecurityElement]::Escape($username)
        $escapedPass = [System.Security.SecurityElement]::Escape($password)

        $eapXmlUserData = @"
<?xml version="1.0"?>
<EapHostUserCredentials xmlns="http://www.microsoft.com/provisioning/EapHostUserCredentials" xmlns:eapCommon="http://www.microsoft.com/provisioning/EapCommon" xmlns:baseEap="http://www.microsoft.com/provisioning/BaseEapMethodUserCredentials">
  <EapMethod>
    <eapCommon:Type>25</eapCommon:Type>
    <eapCommon:AuthorId>0</eapCommon:AuthorId>
  </EapMethod>
  <Credentials xmlns:baseEap="http://www.microsoft.com/provisioning/BaseEapUserPropertiesV1" xmlns:MsPeap="http://www.microsoft.com/provisioning/MsPeapUserPropertiesV1" xmlns:MsChapV2="http://www.microsoft.com/provisioning/MsChapV2UserPropertiesV1">
    <baseEap:Eap>
      <baseEap:Type>25</baseEap:Type>
      <MsPeap:EapType>
        <baseEap:Eap>
          <baseEap:Type>26</baseEap:Type>
          <MsChapV2:EapType>
            <MsChapV2:Username>$escapedUser</MsChapV2:Username>
            <MsChapV2:Password>$escapedPass</MsChapV2:Password>
            <MsChapV2:LogonDomain></MsChapV2:LogonDomain>
          </MsChapV2:EapType>
        </baseEap:Eap>
      </MsPeap:EapType>
    </baseEap:Eap>
  </Credentials>
</EapHostUserCredentials>
"@

        [uint32]$negotiatedVersion = 0
        [IntPtr]$clientHandle = [IntPtr]::Zero
        $openResult = [WlanEap]::WlanOpenHandle(2, [IntPtr]::Zero, [ref]$negotiatedVersion, [ref]$clientHandle)
        if ($openResult -ne 0) {
            throw "WlanOpenHandle failed with error code $openResult"
        }

        try {
            $interfaceGuid = Get-WlanInterfaceGuid
            $setResult = [WlanEap]::WlanSetProfileEapXmlUserData(
                $clientHandle, $interfaceGuid, $ProfileName,
                $script:WLAN_SET_EAPHOST_DATA_CURRENT_USER, $eapXmlUserData, [IntPtr]::Zero)
            if ($setResult -ne 0) {
                throw "WlanSetProfileEapXmlUserData failed for profile '$ProfileName' with error code $setResult"
            }
        }
        finally {
            [WlanEap]::WlanCloseHandle($clientHandle, [IntPtr]::Zero) | Out-Null
        }
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($bstr)
    }
}

function Get-WlanInterfaceGuid {
    $interfaceLine = (netsh wlan show interfaces) | Select-String "GUID"
    if (-not $interfaceLine) {
        throw "Could not find a wireless interface GUID via 'netsh wlan show interfaces'."
    }
    $guidString = ($interfaceLine -split ":", 2)[1].Trim()
    return [Guid]$guidString
}
