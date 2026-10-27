# Cleanup Explorer context menu

applyRegEdits "Remove Visual Studio from Explorer context menu" @(
    @("RemoveKey", "HKCR:\Directory\Background\shell\AnyCode"),
    @("RemoveKey", "HKCR:\Directory\shell\AnyCode")
)

applyRegEdits "Remove 'Edit with Paint 3D' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\SystemFileAssociations\.3mf\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.bmp\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.fbx\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.gif\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.jfif\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.jpe\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.jpeg\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.jpg\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.png\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.tif\Shell\3D Edit"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\.tiff\Shell\3D Edit")
)


applyRegEdits "Remove 'Share' / 'Give access to' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\*\shellex\ContextMenuHandlers\ModernSharing"),
    @("RemoveKey", "HKCR:\*\shellex\ContextMenuHandlers\Sharing"),
    @("RemoveKey", "HKCR:\Directory\Background\shellex\ContextMenuHandlers\Sharing"),
    @("RemoveKey", "HKCR:\Directory\shellex\ContextMenuHandlers\Sharing"),
    @("RemoveKey", "HKCR:\Drive\shellex\ContextMenuHandlers\Sharing"),
    @("RemoveKey", "HKCR:\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing"),
    @("RemoveKey", "HKCR:\UserLibraryFolder\shellex\ContextMenuHandlers\Sharing")
)

applyRegEdits "Remove VLC from Explorer context menu" @(
    @("RemoveKey", "HKCR:\directory\shell\AddToPlaylistVLC"),
    @("RemoveKey", "HKCR:\directory\shell\PlayWithVLC")
)

applyRegEdits "Remove Winamp from Explorer context menu" @(
    @("RemoveKey", "HKCR:\directory\shell\Winamp.Bookmark"),
    @("RemoveKey", "HKCR:\directory\shell\Winamp.Enqueue"),
    @("RemoveKey", "HKCR:\directory\shell\Winamp.Play")
)

applyRegEdits "Remove Windows Media Player from Explorer context menu" @(
    @("RemoveKey", "HKCR:\SystemFileAssociations\Directory.Audio\shell\Enqueue"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\Directory.Audio\shell\Play"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\Directory.Video\shell\Enqueue"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\Directory.Video\shell\Play"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\Directory.Image\shell\Enqueue"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\Directory.Image\shell\Play"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\audio\shell\Enqueue"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\audio\shell\Play"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\video\shell\Enqueue"),
    @("RemoveKey", "HKCR:\SystemFileAssociations\video\shell\Play")
)

applyRegEdits "Remove WizTree from Explorer context menu" @(
    @("RemoveKey", "HKCR:\directory\shell\WizTree"),
    @("RemoveKey", "HKCR:\directory\background\shell\WizTree"),
    @("RemoveKey", "HKCR:\Folder\shell\WizTree")
)

applyRegEdits "Remove 'Open Git GUI here' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\directory\shell\git_gui"),
    @("RemoveKey", "HKCR:\directory\background\shell\git_gui")
)

applyRegEdits "Remove 'Open Linux shell here' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\directory\shell\WSL"),
    @("RemoveKey", "HKCR:\directory\background\shell\WSL")
)

applyRegEdits "Remove 'Restore previous versions' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\AllFilesystemObjects\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"),
    @("RemoveKey", "HKCR:\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"),
    @("RemoveKey", "HKCR:\Directory\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"),
    @("RemoveKey", "HKCR:\Drive\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}")
)

applyRegEdits "Remove 'Add to library' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\Folder\shellex\ContextMenuHandlers\Library Location")
)

applyRegEdits "Remove 'Pin to Quick access' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\Folder\shell\pintohome")
)

applyRegEdits "Remove 'Pin to Start Menu' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\exefile\shellex\ContextMenuHandlers\PintoStartScreen"),
    @("RemoveKey", "HKCR:\mscfile\shellex\ContextMenuHandlers\PintoStartScreen"),
    @("RemoveKey", "HKCR:\Folder\shellex\ContextMenuHandlers\PintoStartScreen"),
    @("RemoveKey", "HKCR:\Microsoft.Website\shellex\ContextMenuHandlers\PintoStartScreen")
)

applyRegEdits "Remove 'New -> Microsoft Access file' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\.accdb\Access.Application.16\ShellNew"),
    @("RemoveKey", "HKCR:\.mdb\ShellNew")
)
applyRegEdits "Remove 'New -> Bitmap image' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\.bmp\ShellNew")
)
applyRegEdits "Remove 'New -> Microsoft Publisher file' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\.pub\Publisher.Document.16\ShellNew")
)
applyRegEdits "Remove 'New -> Microsoft Visio Drawing' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\.vsdx\Visio.Drawing.15\ShellNew")
)
applyRegEdits "Remove 'New -> RTF file' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\.rtf\ShellNew")
)
applyRegEdits "Remove 'New -> Contact' from Explorer context menu" @(
    @("RemoveKey", "HKCR:\.contact\ShellNew")
)

if ($isWindows11) {
    #https://old.reddit.com/r/Windows11/comments/1i0o7d7/is_there_a_tool_that_lets_you_easily_modify/m6zqu16/
    applyRegEdits "Remove 'Open with Notepad' from Explorer context menu" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{CA6CC9F1-867A-481E-951E-A28C5E4F01EA}", "Edit in Notepad", @{explorerRestart=$true})
    )
    applyRegEdits "Remove 'Share' from Explorer context menu" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}", "Share", @{explorerRestart=$true})
    )
    applyRegEdits "Remove 'Ask Copilot' from Explorer context menu" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}", "Ask Copilot", @{explorerRestart=$true})
    )
    applyRegEdits "Remove 'Edit with Photos / Create with Designer / Edit with Clipchamp' from Explorer context menu" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{BFE0E2A4-C70C-4AD7-AC3D-10D1ECEBB5B4}", "Edit with Photos", @{explorerRestart=$true}),
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{1100CBCD-B822-43F0-84CB-16814C2F6B44}", "Erase Object with Photos", @{explorerRestart=$true}),
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{7A53B94A-4E6E-4826-B48E-535020B264E5}", "Create with Designer", @{explorerRestart=$true}),
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{9AAFEDA2-97B6-43EA-9466-9DE90501B1B6}", "Visual Search with Bing", @{explorerRestart=$true}),
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{8AB635F8-9A67-4698-AB99-784AD929F3B4}", "Edit with Clipchamp", @{explorerRestart=$true})
    )
    applyRegEdits "Remove 'Cast to Device' from Explorer context menu" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{7AD84985-87B4-4a16-BE58-8B72A5B390F7}", "Cast to Device", @{explorerRestart=$true})
    )
    applyRegEdits "Remove 'Open in Terminal' from Explorer context menu" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Shell Extensions/Blocked/", "{9F156763-7844-4DC4-B2B1-901F640F5155}", "Open in Terminal", @{explorerRestart=$true})
    )
}

# Add useful stuff to Explorer context menu

applyRegEdits "Set 'Set as desktop wallpaper' to shift + right click only" @(
    @("SetProperty", "HKCR:\SystemFileAssociations\.bmp\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.dib\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.gif\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.jfif\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.jpe\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.jpeg\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.jpg\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.png\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.tif\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.tiff\Shell\setdesktopwallpaper", "Extended", ""),
    @("SetProperty", "HKCR:\SystemFileAssociations\.wdp\Shell\setdesktopwallpaper", "Extended", "")
)

applyRegEdits "Display 'Open Powershell here' in Explorer context menu without shift" @(
    @("RemoveProperty", "HKCR:\Directory\shell\Powershell", "Extended", @{grantPermissions=$true}),
    @("SetProperty", "HKCR:\Directory\shell\Powershell", "Icon", "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe", @{grantPermissions=$true}),
    @("RemoveProperty", "HKCR:\Directory\background\shell\Powershell", "Extended", @{grantPermissions=$true}),
    @("SetProperty", "HKCR:\Directory\background\shell\Powershell", "Icon", "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe", @{grantPermissions=$true})
)

#As https://superuser.com/a/1131932/1068224 points out, the default "Copy as Path" menu is hardcoded to only display on shift+right click.
#The only workaround is to create a Shell entry instead of a ShellEx entry.
#If we remove the existing ShellEx entry, the Shell entry stops working (why? idk.)
#I did not find a way to remove or hide that entry (putting it in HKCU:\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked does nothing), so unfortunately there are two "Copy as Path" entries on shift + right click.
#Remove-Item -LiteralPath "HKCR:\AllFilesystemObjects\shellex\ContextMenuHandlers\CopyAsPathMenu"
if (-not $isWindows11) {
    applyRegEdits "Display 'Copy as Path' in Explorer context menu without shift" @(
        @("SetProperty", "HKCR:\AllFilesystemObjects\shell\windows.copyaspath", "(default)", "@shell32.dll,-30328"),
        @("SetProperty", "HKCR:\AllFilesystemObjects\shell\windows.copyaspath", "InvokeCommandOnSelection", 1),
        @("SetProperty", "HKCR:\AllFilesystemObjects\shell\windows.copyaspath", "VerbHandler", "{f3d06e7c-1e45-4a26-847e-f9fcdee59be0}"),
        @("SetProperty", "HKCR:\AllFilesystemObjects\shell\windows.copyaspath", "Position", "Bottom")
    )
} else {
    #In windows 11, Copy as Path is visible without shift, so remove our additional entry.
    applyRegEdits "Remove additional 'Copy as Path' from Explorer context menu" @(
        @("RemoveKey", "HKCR:\AllFilesystemObjects\shell\windows.copyaspath")
    )
}

#https://winaero.com/find-your-current-wallpaper-image-path-in-windows-10/
$getCurrentWallpaperCommand = @'
    $data = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TranscodedImageCache" -ErrorAction SilentlyContinue).TranscodedImageCache
    if ($data -and $data.Count -gt 24) {
        $path = [System.Text.Encoding]::Unicode.GetString($data, 24, $data.Length - 24)
        $path = $path.Trim([char]0)
        Start-Process "explorer.exe" -ArgumentList "/select,`"$path`""
    }
'@
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($getCurrentWallpaperCommand))
$viewWallpaperLocation = if ((Get-WinSystemLocale).Name -eq "fr-FR") { "Voir l'emplacement du fond d'$([char]0xE9)cran" } else { "View wallpaper location" }
applyRegEdits "Add 'View wallpaper location' to Desktop context menu" @(
    @("SetProperty", "HKCR:\DesktopBackground\Shell\DesktopWallpaperLocation", "(default)", "$viewWallpaperLocation"),
    @("SetProperty", "HKCR:\DesktopBackground\Shell\DesktopWallpaperLocation", "Icon", "imageres.dll,-5346"),
    @("SetProperty", "HKCR:\DesktopBackground\Shell\DesktopWallpaperLocation\command", "(default)", "conhost.exe --headless powershell.exe -NoProfile -WindowStyle Hidden -EncodedCommand $encodedCommand")
)

#https://superuser.com/questions/920267/shellnew-icon-for-file-type
applyRegEdits "Add 'New -> File' to Explorer context menu" @(
    @("SetProperty", "HKCR:\.", "(default)", "No Extension"),
    @("SetProperty", "HKCR:\.\ShellNew", "NullFile", ""),
    @("SetProperty", "HKCR:\.\ShellNew", "IconPath", "C:\windows\system32\imageres.dll,2"),
    @("SetProperty", "HKCR:\.\ShellNew\Config", "NoExtension", ""),
    @("SetProperty", "HKCR:\No Extension", "FriendlyTypeName", "@shell32.dll,-4130")
)
