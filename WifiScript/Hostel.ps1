# Delete an existing Wi-Fi profile
Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList '/c netsh wlan delete profile name="KIIT-WIFI-NET."'

# Add a new Wi-Fi profile
Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList '/c netsh wlan add profile filename="C:\Users\Paritosh Dot\Documents\KIIT_WIFI_ISSUE\Hostel\Wi-Fi-KIIT-WIFI-NET..xml"'

# Connect to the Wi-Fi network
Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList '/c netsh wlan connect name="KIIT-WIFI-NET."'


Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Keyboard {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

    public const int KEYEVENTF_KEYDOWN = 0x0000;
    public const int KEYEVENTF_KEYUP = 0x0002;

    public const byte VK_LWIN = 0x5B; // Windows key
    public const byte VK_A = 0x41;   // A key
    public const byte VK_TAB = 0x09; // Tab key
    public const byte VK_ENTER = 0x0D; // Enter key

    public static void PressKey(byte key) {
        keybd_event(key, 0, KEYEVENTF_KEYDOWN, 0);
        keybd_event(key, 0, KEYEVENTF_KEYUP, 0);
    }

    public static void PressWinA() {
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYDOWN, 0);
        keybd_event(VK_A, 0, KEYEVENTF_KEYDOWN, 0);
        keybd_event(VK_A, 0, KEYEVENTF_KEYUP, 0);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, 0);
    }
}
"@

# Perform the sequence
[Keyboard]::PressWinA()          # Press Win + A
Start-Sleep -Milliseconds 900    # Wait longer to ensure the action completes

[Keyboard]::PressKey(0x09)       # Press Tab
Start-Sleep -Milliseconds 300    # Wait to ensure the action is registered

[Keyboard]::PressKey(0x0D)       # Press Enter


# Wait for the prompt window to appear
 Start-Sleep -Seconds 2  # Adjust this as needed

# Send username
[System.Windows.Forms.SendKeys]::SendWait("UserName")
[System.Windows.Forms.SendKeys]::SendWait("{TAB}")  # Move to password field

# Send password
[System.Windows.Forms.SendKeys]::SendWait("Password")
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")  # Press OK