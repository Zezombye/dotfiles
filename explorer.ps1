
applyRegEdits "Set Explorer to display hidden files" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Hidden", 1)
)
applyRegEdits "Set Explorer to display file extensions" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "HideFileExt", 0)
)
applyRegEdits "Set Explorer to display system files" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowSuperHidden", 1)
)
applyRegEdits "Set Explorer to open to Downloads folder" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "LaunchTo", 3)
)

#todo: sometimes makes explorer crash on startup? check the LaunchTo property above if so
applyRegEdits "Set Explorer to display path for libraries" @(
    #Desktop
    @("RemoveProperty", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}", "ParsingName"),
    #Documents
    @("RemoveProperty", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}", "ParsingName"),
    #Downloads
    @("RemoveProperty", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}", "ParsingName"),
    #Music
    @("RemoveProperty", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}", "ParsingName"),
    #Pictures
    @("RemoveProperty", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}", "ParsingName"),
    #Videos
    @("RemoveProperty", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}", "ParsingName")
)

if ($isWindows11) {
    
    applyRegEdits "Remove Gallery from Explorer sidebar" @(
        @("SetProperty", "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}", "System.IsPinnedToNameSpaceTree", 0x00)
    )
    applyRegEdits "Restore old Explorer right click menu" @(
        @("SetProperty", "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32", "(default)", "")
    )
    applyRegEdits "Set compact mode in Explorer" @(
        @("SetProperty", "HKCU:/Software/Microsoft/Windows/CurrentVersion/Explorer\Advanced", "UseCompactMode", 1)
    )
    #https://www.elevenforum.com/t/restore-classic-file-explorer-with-ribbon-in-windows-11.620/
    applyRegEdits "Enable ribbon in Explorer" @(
        @("SetProperty", "HKCU:\Software\Classes\CLSID\{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}", "(default)", "CLSID_ItemsViewAdapter"),
        @("SetProperty", "HKCU:\Software\Classes\CLSID\{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}\InProcServer32", "(default)", ""),
        @("SetProperty", "HKCU:\Software\Classes\CLSID\{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}", "(default)", "CLSID_ItemsViewAdapter"),
        @("SetProperty", "HKCU:\Software\Classes\CLSID\{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}\InProcServer32", "(default)", "")
    )
}
