# irm zez.dev | iex

echo ""
echo "   _____             _          _       ___           __                      _____      __            "
echo "  /__  /  ___  ____ ( )_____   | |     / (_)___  ____/ /___ _      _______   / ___/___  / /___  ______ "
echo "    / /  / _ \/_  / |// ___/   | | /| / / / __ \/ __  / __ \ | /| / / ___/   \__ \/ _ \/ __/ / / / __ \"
echo "   / /__/  __/ / /_  (__  )    | |/ |/ / / / / / /_/ / /_/ / |/ |/ (__  )   ___/ /  __/ /_/ /_/ / /_/ /"
echo "  /____/\___/ /___/ /____/     |__/|__/_/_/ /_/\__,_/\____/|__/|__/____/   /____/\___/\__/\__,_/ .___/ "
echo "                                                                                              /_/      "
echo ""


$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if ($isAdmin) {echo "Running as Administrator"} else {echo "Running as standard user. Some tweaks may not be applied."}

$isWindows11 = ((Get-CimInstance -ClassName Win32_OperatingSystem).Version -ge "10.0.22000")
if ($isWindows11) {echo "Detected Windows 11"} else {echo "Detected Windows 10 or lower"}

$needsExplorerRestart = $false
$needsSignOut = $false
$needsAdmin = $false

if (-not (Test-Path "HKU:")) {New-PSDrive HKU Registry HKEY_USERS | Out-Null}
if (-not (Test-Path "HKCR:")) {New-PSDrive -Name "HKCR" -PSProvider Registry -Root "HKEY_CLASSES_ROOT" | Out-Null}

§include utils.ps1

§include taskbar.ps1
§include explorer.ps1
§include explorerContextMenu.ps1
§include explorerQuickAccess.ps1

if ($isWindows11) {
    applyRegEdits "Set start menu layout to 'More Recommendations'" @(
        @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Start_Layout", 0x02)
    )

    applyRegEdits "Enable clock in notification center" @(
        @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowClockInNotificationCenter", 0x01)
    )
    
    # Removes Widgets from the Taskbar
    # Is blocked by the UCPD: https://www.elevenforum.com/t/enable-or-disable-userchoice-protection-driver-ucpd-in-windows-11-and-10.24267/
    # https://forums.mydigitallife.net/threads/taskbarda-widgets-registry-change-is-now-blocked.88547/
    # Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0x00

    applyRegEdits "Set scrollbars to always show" @(
        @("SetProperty", "HKCU:\Control Panel\Accessibility", "DynamicScrollbars", 0, @{signout=$true})
    )
    applyRegEdits "Increase scrollbar size" @(
        @("SetProperty", "HKCU:/Control Panel\Desktop\WindowMetrics", "ScrollHeight", "-330", @{signout=$true}),
        @("SetProperty", "HKCU:/Control Panel\Desktop\WindowMetrics", "ScrollWidth", "-330", @{signout=$true})
    )

    §writeFile {"src": "w11_terminal.json", "dest": "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json", "applyConfigValues": true, "msg": "Applied Windows Terminal settings"}
}

applyRegEdits "Disable window shake to minimize" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "DisallowShaking", 1)
)

if (Test-Path "HKCU:\Software\Microsoft\Office\16.0\Common") {
    applyRegEdits "Disable smooth cursor in Office apps" @(
        @("NewKey", "HKCU:\Software\Microsoft\Office\16.0\Common\Graphics"),
        @("SetProperty", "HKCU:\Software\Microsoft\Office\16.0\Common\Graphics", "DisableAnimations", 1)
    )
}

applyRegEdits "Disable sticky keys" @(
    @("SetProperty", "HKCU:\Control Panel\Accessibility\StickyKeys", "Flags", 506, @{signout=$true})
)

applyRegEdits "Disable filter keys" @(
    @("SetProperty", "HKCU:\Control Panel\Accessibility\Keyboard Response", "Flags", 122)
)

applyRegEdits "Disable toggle keys" @(
    @("SetProperty", "HKCU:\Control Panel\Accessibility\ToggleKeys", "Flags", 58)
)

#Feels too weird
#echo "Setting drive letters to be before labels"
#Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowDriveLettersFirst" -Value 4

applyRegEdits "Set wallpaper quality to 100%" @(
    @("SetProperty", "HKCU:/Control Panel/Desktop", "JPEGImportQuality", 100)
)

applyRegEdits "Set blue accent color" @(
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "AccentColor", 0xffb16300), #abgr
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "AccentColorInactive", 0x003c3c3c), #dark gray, abgr - text color is 0.6 × bg + 102, impossible to get the same output as the file explorer
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "ColorizationColor", 0xc40063B1), #argb
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "ColorizationColorBalance", 0x59),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "ColorizationAfterglow", 0xc40063B1),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "ColorizationAfterglowBalance", 0x0A),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "ColorizationBlurBalance", 0x01),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "EnableWindowColorization", 0x01),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/DWM", "ColorizationGlassAttribute", 0x01),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Themes/Personalize", "ColorPrevalence", 0x01),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Themes/Personalize", "AppsUseLightTheme", 0x00),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Themes/History", "AutoColor", 0x00),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Explorer/Accent", "AccentPalette", ([byte[]](134,202,255,0,95,178,242,0,30,145,234,0,0,99,177,0,0,66,117,0,0,45,79,0,0,32,56,0,0,204,106,0))),
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Explorer/Accent", "StartColorMenu", 0xff754200),
    #This value has to be the last, as it triggers a change. https://www.reddit.com/r/Windows11/comments/sw15u0/dark_theme_did_you_notice_the_ugly_pale_accent/
    @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Explorer/Accent", "AccentColorMenu", 0xffb16300)
)

§include setRegistryFavorites.ps1


$taskManagerSettings = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskManager").Preferences
if ($taskManagerSettings[28] -eq 0) {
    Write-Host "Already set Task Manager to expanded view" -ForegroundColor DarkGray
} else {
    $taskManagerSettings[28] = 0 #1 for compact view, 0 for expanded view
    Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskManager" -Name "Preferences" -Value $taskManagerSettings
    echo "Set Task Manager to expanded view"
}

applyRegEdits "Fix console colors for Python" @(
    @("SetProperty", "HKCU:/Console", "VirtualTerminalLevel", 1)
)

# In the registry, those values are stored in little endian
function hexToAABBGGRR {
    #todo
}

$consoleWidth = ###consoleWidth###
$consoleHeight = ###consoleHeight###

$colors = @(
    "###black###", "###blue###", "###green###", "###cyan###", "###red###", "###purple###", "###yellow###", "###white###", 
    "###brightBlack###", "###brightBlue###", "###brightGreen###", "###brightCyan###", "###brightRed###", "###brightPurple###", "###brightYellow###", "###brightWhite###", 
)
$regPaths = @(
    "HKCU:\Console",
    "HKCU:\Console\%SystemRoot%_system32_cmd.exe",
    "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",
    "HKCU:\Console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe",
    #S-1-5-18 is the SYSTEM account
    "HKU:\S-1-5-18\Console",
    "HKU:\S-1-5-18\Console\%SystemRoot%_system32_cmd.exe",
    "HKU:\S-1-5-18\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",
    "HKU:\S-1-5-18\Console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe"
    #Those two don't work
    #"HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell_ise.exe",
    #"HKCU:\Console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell_ise.exe"
)

foreach ($regPath in $regPaths) {

    $cmdType = @{
        "Console" = "default console";
        "%SystemRoot%_system32_cmd.exe" = "cmd.exe";
        "%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe" = "PowerShell";
        "%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe" = "32-bit PowerShell"
    }[$regPath.Split('\')[-1]]

    if ($regPath.startsWith("HKU:\S-1-5-18")) {
        $user = "SYSTEM"
    } else {
        $user = "current user"
    }
    $modifications = @()
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $colorValue = hexToAABBGGRR $colors[$i]
        $colorValue = + "0x$colorValue"
        $regKey = "ColorTable{0:d2}" -f $i
        $modifications += ,@("SetProperty", $regPath, $regKey, $colorValue)
    }
    applyRegEdits "Set $user $cmdType colors" $modifications

    applyRegEdits "Set $user $cmdType additional properties" @(
        @("SetProperty", $regPath, "ScreenColors", 0x00000007), # black on white
        @("SetProperty", $regPath, "PopupColors", 0x00000007), # black on white
        @("SetProperty", $regPath, "FaceName", "Consolas"),
        @("SetProperty", $regPath, "FontFamily", 0x00000036), # Consolas
        @("SetProperty", $regPath, "FontWeight", 0x00000190), # 400
        @("SetProperty", $regPath, "FontSize", 0x00100000),   # 16px
        @("SetProperty", $regPath, "HistoryBufferSize", 999),
        @("SetProperty", $regPath, "HistoryNoDup", 1),
        @("SetProperty", $regPath, "WindowSize", (($consoleHeight -shl 16) -bor $consoleWidth))
    )
}

#Depending on how you launch Powershell/CMD, the settings will be read from the shortcut files instead of the registry.
#We therefore need to patch the shortcuts directly as well.
function patchShortcut {
    param (
        [string]$shortcutDesc,
        [string]$shortcutPath,
        [string]$shortcutContentBase64,
        [int]$colorOffset,
        [int]$sizeOffset
    )

    $shortcutContent = [System.Convert]::FromBase64String($shortcutContentBase64)
    if (-not (Test-Path -LiteralPath $shortcutPath)) {
        New-Item -Path $shortcutPath -ItemType File -Force | Out-Null
    }
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $offset = $colorOffset + ($i * 4) + 1 # +1 for the first byte which is always 0
        $colors[$i] | ForEach-Object { $shortcutContent[$offset++] = $_ }
    }
    if ($sizeOffset) {
        $shortcutContent[$sizeOffset] = $consoleWidth
        $shortcutContent[$sizeOffset + 4] = $consoleWidth
        $shortcutContent[$sizeOffset + 6] = $consoleHeight
    }
    
    $existingContent = Get-Content -LiteralPath $shortcutPath -Encoding Byte
    if (@(Compare-Object $existingContent $shortcutContent -SyncWindow 0).Length -eq 0) {
        Write-Host "Already patched $shortcutDesc shortcut" -ForegroundColor DarkGray
        return
    }

    Set-Content -LiteralPath $shortcutPath -Value $shortcutContent -Encoding Byte
    echo "Patched $shortcutDesc shortcut"
}

patchShortcut "powershell" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" "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" 0x87E 0x7FF

patchShortcut "powershell x86" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell (x86).lnk" "TAAAAAEUAgAAAAAAwAAAAAAAAEbfAgAAIAAAAJuvlrfNas0Bm6+Wt81qzQGAHQKo3WrNAQDwBgAAAAAAAQAAAAAAAAAAAAAAAAAAAPEBFAAfUOBP0CDqOmkQotgIACswMJ0ZAC9DOlwAAAAAAAAAAAAAAAAAAAAAAAAAUgAxAAAAAADHQgKwMABXaW5kb3dzADwACAAEAO+++kDALMdCArAqAAAAHxAAAAAAAQAAAAAAAAAAAAAAAAAAAFcAaQBuAGQAbwB3AHMAAAAWAFYAMQAAAAAAuELmrRAAU3lzV09XNjQAAD4ACAAEAO+++kDBLLhC5q0qAAAAiRwAAAAAAQAAAAAAAAAAAAAAAAAAAFMAeQBzAFcATwBXADYANAAAABgAaAAxAAAAAAD6QKBBEABXSU5ET1d+MQAAUAAIAAQA7776QKBB+kCgQSoAAACHHQAAAAABAAAAAAAAAAAAAAAAAAAAVwBpAG4AZABvAHcAcwBQAG8AdwBlAHIAUwBoAGUAbABsAAAAGABKADEAAAAAALhC660UAHYxLjAAADYACAAEAO+++kCgQbhC660qAAAAiB0AAAAAAQAAAAAAAAAAAAAAAAAAAHYAMQAuADAAAAAUAGgAMgAA8AYA+kCaGiAAcG93ZXJzaGVsbC5leGUAAEoACAAEAO+++kBXC/pAVwsqAAAA//kAAAAAAQAAAAAAAAAAAAAAAAAAAHAAbwB3AGUAcgBzAGgAZQBsAGwALgBlAHgAZQAAAB4AAABuAAAAHAAAAAEAAAAcAAAAMwAAAAAAAABtAAAAFwAAAAMAAABzLe50EAAAAE9TRGlzawBDOlxXaW5kb3dzXFN5c1dPVzY0XFdpbmRvd3NQb3dlclNoZWxsXHYxLjBccG93ZXJzaGVsbC5leGUAAC4AUABlAHIAZgBvAHIAbQBzACAAbwBiAGoAZQBjAHQALQBiAGEAcwBlAGQAIAAoAGMAbwBtAG0AYQBuAGQALQBsAGkAbgBlACkAIABmAHUAbgBjAHQAaQBvAG4AcwBRAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAFcAaQBuAGQAbwB3AHMAXABTAHkAcwBXAE8AVwA2ADQAXABXAGkAbgBkAG8AdwBzAFAAbwB3AGUAcgBTAGgAZQBsAGwAXAB2ADEALgAwAFwAcABvAHcAZQByAHMAaABlAGwAbAAuAGUAeABlABUAJQBIAE8ATQBFAEQAUgBJAFYARQAlACUASABPAE0ARQBQAEEAVABIACUAOwAlAFMAeQBzAHQAZQBtAFIAbwBvAHQAJQBcAHMAeQBzAHcAbwB3ADYANABcAFcAaQBuAGQAbwB3AHMAUABvAHcAZQByAFMAaABlAGwAbABcAHYAMQAuADAAXABwAG8AdwBlAHIAcwBoAGUAbABsAC4AZQB4AGUAFAMAAAEAAKAlU3lzdGVtUm9vdCVcc3lzd293NjRcV2luZG93c1Bvd2VyU2hlbGxcdjEuMFxwb3dlcnNoZWxsLmV4ZQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACUAUwB5AHMAdABlAG0AUgBvAG8AdAAlAFwAcwB5AHMAdwBvAHcANgA0AFwAVwBpAG4AZABvAHcAcwBQAG8AdwBlAHIAUwBoAGUAbABsAFwAdgAxAC4AMABcAHAAbwB3AGUAcgBzAGgAZQBsAGwALgBlAHgAZQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAABQAAoCkAAADVAAAAHAAAAAsAAKCwMVLW8bJXSKTOqOfG6n0n1QAAAGAAAAADAACgWAAAAAAAAABsZWVob2xtMTYAAAAAAAAAmpqyu7ZVLUqI6zLq13xnQNkHI1xpM+IRvnAAHMQt9AuamrK7tlUtSojrMurXfGdA2QcjXGkz4hG+cAAcxC30C8wAAAACAACgBwDzAHgAuAt4ADIA0ADQAAAAAAAAAAAACAAQADYAAACQAQAAQwBvAG4AcwBvAGwAYQBzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkAAAAAAAAAAQAAAAEAAAABAAAA5wMAAAQAAAAAAAAABAUGAAAAgAAAgAAAAICAAIAAAAABJFYA7u3wAMDAwACAgIAAAAD/AAD/AAAA//8A/wAAAP8A/wD//wAA////ADABAAAJAACgkQAAADFTUFPiilhGvEw4Q7v8E5MmmG3OdQAAAAQAAAAAHwAAADIAAABTAC0AMQAtADUALQAyADEALQAyADEAMgA3ADUAMgAxADEAOAA0AC0AMQA2ADAANAAwADEAMgA5ADIAMAAtADEAOAA4ADcAOQAyADcANQAyADcALQAxADEAOAAwADYANAAzAAAAAAAAAJMAAAAxU1BTBwZXDJYD3kOdYeMh199QJhEAAAADAAAAAAsAAAD//wAAEQAAAAEAAAAACwAAAP//AAARAAAAAgAAAAALAAAA//8AABEAAAAEAAAAAAsAAAAAAAAAEQAAAAYAAAAAAgAAAP8AAAARAAAABQAAAAALAAAA//8AABEAAAAKAAAAAAsAAAAAAAAAAAAAAAAAAAAAAAAA" 0x87E 0x7FF

patchShortcut "cmd" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk" "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" 0x49F


# We can get conditional prompts with the autorun value, but only at startup (can't display git branch for example)
# Using environment variables is risky in batch, so don't add user@hostname when connecting via ssh to avoid potential command injection
# Powershell is too long to start up
# And it is too risky. If the autorun command has a syntax error, then you simply cannot connect via ssh
#if not %userdomain% == %computername% (
#    if not %userdomain% == WORKGROUP
#        (set prompt=$e[33m%userdomain%\\%username%@%computername%$e[92m $p$e[0m$g$s)
#    else
#        (set prompt=$e[33m%username%@%computername%$e[92m $p$e[0m$g$s)
#) else
#    (set prompt=$e[33m%username%@%computername%$e[92m $p$e[0m$g$s)

# Use fltmc to test admin rights - https://stackoverflow.com/a/28268802/4851350

applyRegEdits "Set cmd.exe prompt" @(
    @("SetProperty", "HKCU:\Environment", "PROMPT", '$e[92m$p$e[0m$g$s'),
    @("SetProperty", "HKCU:\Software\Microsoft\Command Processor", "AutoRun", @'

if defined ssh_connection
    (set prompt=$e[95m[SSH] $e[92m$p$e[0m$g$s)
else (
    fltmc > nul 2>&1
    && (set prompt=$e[91m[Admin] $e[92m$p$e[0m$g$s)
    || (set prompt=$e[92m$p$e[0m$g$s)
)
'@.Replace("`n", " "))
)
applyRegEdits "Set SYSTEM cmd.exe prompt" @(
    @("SetProperty", "HKU:\S-1-5-18\Environment", "PROMPT", '$e[91m[SYSTEM]$e[92m $p$e[0m$g ')
)


§writeFile {"src": "profile.ps1", "dest": "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1", "msg": "Set PowerShell profile"}
§writeFile {"src": "profile.ps1", "dest": "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "msg": "Set PowerShell profile"}
§writeFile {"src": "profile.ps1", "dest": "C:\WINDOWS\system32\config\systemprofile\Documents\WindowsPowerShell\profile.ps1", "msg": "Set PowerShell profile", "needsAdmin": true}
§writeFile {"src": "profile.ps1", "dest": "C:\WINDOWS\system32\config\systemprofile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "msg": "Set PowerShell profile", "needsAdmin": true}


§writeFile {"src": "bashrc.sh", "dest": "$env:USERPROFILE\.bashrc", "msg": "Set .bashrc"}

if (-not (Test-Path "$env:USERPROFILE\.bash_profile")) {
    echo "Creating .bash_profile to source .bashrc and .profile"
    [IO.File]::WriteAllText("$env:USERPROFILE\.bash_profile", @'
test -f ~/.profile && . ~/.profile
test -f ~/.bashrc && . ~/.bashrc
'@)
}

# Custom French keyboard

§writeFile {"src": "keyboard.klc", "dest": "$env:SystemRoot\System32\keyboard_fr_improved_zez.dev.dll", "msg": "Installed enhanced French keyboard dll", "needsAdmin": true}

$frenchKeyboardId = "0000040c"
applyRegEdits "Set enhanced French keyboard as substitute for standard French keyboard" @(
    @("SetProperty", "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$frenchKeyboardId", "Layout Text", "Fran$([char]0xE7)ais (am$([char]0xE9)lior$([char]0xE9)) - zez.dev", @{signout=$true}),
    @("SetProperty", "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$frenchKeyboardId", "Layout File", "keyboard_fr_improved_zez.dev.dll", @{signout=$true})
)

§include npp.ps1

# Refresh explorer to apply changes
$code = '
[System.Runtime.InteropServices.DllImport("Shell32.dll")]
private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
public static void Refresh() {
    SHChangeNotify(0x8000000, 0, IntPtr.Zero, IntPtr.Zero);
}
'
try {
    Add-Type -MemberDefinition $code -Namespace SHChange -Name Notify
    [SHChange.Notify]::Refresh()
} catch {}

if ($needsSignOut) {
    echo "Done! Please restart your computer or sign out and sign back in to apply all changes."
} elseif ($needsExplorerRestart) {
    echo "Done! Please restart explorer.exe to apply all changes."
} else {
    echo "Done!"
}
