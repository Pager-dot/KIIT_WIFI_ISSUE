# Script for Fixing wifi issue for KP-1

This project automates connecting to a KIIT WiFi network, including the 802.1X (PEAP/MSCHAPv2) login, using a PowerShell script.

## Why ??

Tired of having this show up

![Problem image](Problem.png)

## How it works

KIIT's Wi-Fi uses WPA2-Enterprise with PEAP (outer) + MSCHAPv2 (inner) 802.1X
authentication (`useOneX=true` in the exported profile XML). There are
actually **two different popups** that can show up when connecting, for two
unrelated reasons, and the script prevents both:

### 1. The "Windows Security — Sign in" box (username/password)

Windows shows this whenever it has no cached credential for the profile —
which is exactly the state right after `netsh wlan add profile` (a fresh
profile has no saved credential yet), or after your KIIT password changes.

Instead of typing into that popup (the old approach used `SendKeys` and
`keybd_event` to blindly Tab/Enter/type through it, which broke every time
Windows changed the dialog's focus order), the script calls the Windows
`WlanSetProfileEapXmlUserData` API directly — the same private API Windows
itself uses internally to save your credential when you check "remember my
credentials" — to inject the username/password into the profile *before*
connecting. Windows then already has a valid cached credential and never
needs to ask.

This lives in `WifiScript/Common.ps1`:
- `Get-KiitCredential` prompts once via a normal `Get-Credential` dialog and
  caches the result with `Export-Clixml`, which encrypts the password via
  Windows DPAPI (tied to your Windows user + machine — unreadable if the
  file is copied elsewhere, and never stored as plaintext).
- `Set-WlanEapCredential` builds the exact XML blob `WlanSetProfileEapXmlUserData`
  expects (schema pulled straight from `C:\Windows\schemas\EAPHost\*.xsd` and
  `C:\Windows\schemas\EAPMethods\*.xsd` — these are undocumented-in-practice
  APIs, so getting the XML shape right required reading Windows' own schema
  files rather than guessing) and pushes it into the named profile via
  P/Invoke into `wlanapi.dll`.

### 2. The "Continue connecting?" certificate prompt

This is a *different* popup, unrelated to your credentials. KIIT's RADIUS
server (a Cisco/Aruba ClearPass box, `CN=CPPM_02`) presents a **self-signed
certificate**. Windows can't validate a self-signed cert against any public
root of trust, so by default (`DisableUserPromptForServerValidation=false`
in the profile XML) it always asks you to manually confirm before trusting
it — and that confirmation is never remembered, so it comes back every time
Windows does a fresh 802.1X handshake.

The fix is the same idea IT departments use for managed devices: **pin the
server's actual certificate thumbprint** into the profile's
`<TrustedRootCA>` list, then set `DisableUserPromptForServerValidation=true`.
Windows then validates the connection silently against that pinned
thumbprint instead of asking — real validation still happens, it's just no
longer interactive. (Setting that flag *without* first pinning the correct
thumbprint is actively worse — Windows fails the connection silently instead
of prompting, which looks like the network just stops working. The thumbprint
must be verified first.)

The current thumbprint for `KIIT-WIFI-NET.` (used by both the Hostel and
Library/Campus profiles) is already pinned in
`Hostel/Wi-Fi-KIIT-WIFI-NET..xml` and `Universal/Wi-Fi-KIIT-WIFI-NET..xml`.
If KIIT ever rotates that certificate, or if `KIIT-WIFI-DU`
(`Campus-25.ps1`) turns out to use a different RADIUS server, you'll see the
"Continue connecting?" box again — click **Show certificate details**, note
the **Server thumbprint** field, and add it as an extra `<TrustedRootCA>`
entry in the relevant profile XML (multiple entries are allowed; keep the
old one too in case it's still valid on other access points).

## Features

- Manages WiFi profiles (`delete`, `add`, `connect`) using `netsh` commands.
- Automatically retries the connection if the first attempt fails (the KIIT
  RADIUS/access points occasionally flake on the first 802.1X attempt — the
  same thing a manual second click in the Wi-Fi flyout used to fix). The
  script explicitly disconnects and waits for the interface to go fully idle
  before retrying, since retrying too soon just cancels the previous attempt
  instead of giving it a clean shot.
- Prompts once for your KIIT username/password and caches them encrypted
  (via Windows DPAPI, through `Export-Clixml`) at
  `%LOCALAPPDATA%\KiitWifi\credential.xml` — never stored in the repo or in
  plaintext.
- Easily executable through a desktop shortcut.

## Requirements

- Windows OS
- PowerShell

## Usage

1. **Setup the Script (for KP-1 Hostel):**
   - Check if you are connected to the KIIT wifi (if not, please do so).
   - Paste the following command in your PowerShell terminal:
     ```
     netsh wlan export profile name="KIIT-WIFI-NET." folder="C:\path\to\KIIT_WIFI_ISSUE\Hostel" key=clear
     ```
   - Change the folder location to wherever you keep this repo.
   - Copy `WifiScript/Common.ps1` and `WifiScript/Hostel.ps1` alongside your
     copy of the repo (or just use the ones already here).
   - In `Hostel.ps1`, change the `netsh wlan add profile filename=...` path
     to point at your exported XML file if your folder layout differs.
   - You do **not** need to hardcode a username/password anywhere — the
     first time you run the script it will prompt you for your KIIT
     credentials once via a normal Windows credential dialog.

2. **Create a Shortcut (for KP-1 Hostel):**
   - Right-click and create a new shortcut.
   - Set the target to:
     ```cmd
     powershell -ExecutionPolicy Bypass -File "C:\path\to\KIIT_WIFI_ISSUE\WifiScript\Hostel.ps1"
     ```
   - Replace the path with wherever your copy of `Hostel.ps1` lives.

3. **Run the Script (for KP-1 Hostel):**
   - Double-click the shortcut to execute the script.
   - On first run you'll be prompted once for your KIIT username/password.

4. **Optional: Change Shortcut Icon:**
   - Right-click the shortcut → **Properties** → **Change Icon**.

5. **Setup the Script (for College/Library/Labs):**
   - Repeat the above process using `Campus-25.ps1` or `Library.ps1` and the
     matching exported profile for that network.

6. **After a KIIT password reset:**
   - Run `WifiScript/Reset-Credential.ps1` once — it clears the cached
     credential and prompts you for the new one. Then just run your usual
     connect script as normal.

## Note

Earlier versions of this repo automated the popup with simulated keystrokes
and had a hardcoded username/password committed in plaintext in the scripts.
That approach was removed because it was fragile (broke on Windows UI
updates) and insecure (leaked credentials into git history). If you forked
this before this change and had your own credentials committed, rotate your
KIIT password.

`Campus-25.ps1` (`KIIT-WIFI-DU`) has the sign-in fix but its certificate
thumbprint hasn't been verified against a live connection yet — you may
still see the "Continue connecting?" box there until someone pins it (see
"How it works" above for the steps).

Please contribute to this repo — it can solve a lot of people's problems with KIIT wifi.