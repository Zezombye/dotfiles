
# Taskbar

applyRegEdits "Remove taskbar search" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search", "SearchboxTaskbarMode", 0, @{explorerRestart=(-not $isWindows11)})
)
applyRegEdits "Remove taskbar task view button" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0, @{explorerRestart=$true})
)
applyRegEdits "Remove taskbar contacts button" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People", "PeopleBand", 0, @{explorerRestart=$true})
)
applyRegEdits "Disable bing search in search menu" @(
    @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search", "BingSearchEnabled", 0)
)

if ($isWindows11) {
    applyRegEdits "Set taskbar to be left aligned" @(
        @("SetProperty", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarAl", 0x00)
    )
}
