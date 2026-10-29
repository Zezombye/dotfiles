
function setRegistryFavorites {
    param (
        [string]$favoritesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites",
        [string]$titleSuffix = ""
    )
    $favorites = @(
        "HKCR:\AllFilesystemObjects",
        "HKCR:\CLSID",
        "HKCR:\Directory",
        "HKCR:\Drive",
        "HKCR:\Folder",
        "HKCR:\Local Settings",
        "HKCR:\SystemFileAssociations",

        "HKCU:",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",

        "HKLM:",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows NT\CurrentVersion",

        "HKLM:\System\CurrentControlSet",
        "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
    )
    $hiveNames = @{HKCR = "HKEY_CLASSES_ROOT"; HKCU = "HKEY_CURRENT_USER"; HKLM = "HKEY_LOCAL_MACHINE"; HKU = "HKEY_USERS"}
    #Favorites are grouped by the first pattern their regedit path matches, with a separator between groups. Favorites added in regedit start with "Computer\" (localized)
    $groupPatterns = @(
        "^([^\\]+\\)?HKEY_CLASSES_ROOT",
        "^([^\\]+\\)?HKEY_CURRENT_USER",
        "^([^\\]+\\)?HKEY_LOCAL_MACHINE(?!\\SYSTEM(\\|$))",
        "^([^\\]+\\)?HKEY_LOCAL_MACHINE\\SYSTEM",
        "^([^\\]+\\)?HKEY_USERS",
        ""
    )
    function getFavoriteGroup {
        param ([string]$regeditPath)
        for ($i = 0; $i -lt $groupPatterns.Count; $i++) {
            if ($regeditPath -match $groupPatterns[$i]) {return $i}
        }
    }

    if (-not (Test-Path -LiteralPath $favoritesPath)) {
        New-Item -Path $favoritesPath -Force | Out-Null
    }
    $key = Get-Item -LiteralPath $favoritesPath
    #Name -> regedit path
    $allFavorites = @{}
    foreach ($name in $key.GetValueNames()) {
        #Separators are recreated below
        if ($name -notmatch "^ +$") {$allFavorites[$name] = $key.GetValue($name)}
    }
    foreach ($favorite in $favorites) {
        $hive, $subKeyPath = $favorite -split ":", 2
        $allFavorites[$favorite] = $hiveNames[$hive] + $subKeyPath
    }

    #Replace spaces with "~" so that "Windows NT\" comes after "Windows\"
    $sortedNames = $allFavorites.Keys | Sort-Object {getFavoriteGroup $allFavorites[$_]}, {$_.Replace(" ", "~")}
    $newFavorites = [ordered]@{}
    $nbSeparators = 0
    $previousGroup = $null
    foreach ($name in $sortedNames) {
        $group = getFavoriteGroup $allFavorites[$name]
        if ($null -ne $previousGroup -and $group -ne $previousGroup) {
            #Separators are favorites named with spaces, as names must be unique
            $nbSeparators++
            $newFavorites[" " * $nbSeparators] = ""
        }
        $newFavorites[$name] = $allFavorites[$name]
        $previousGroup = $group
    }

    $existingText = ($key.GetValueNames() | ForEach-Object {"$_=$($key.GetValue($_))"}) -join "`n"
    $newText = ($newFavorites.GetEnumerator() | ForEach-Object {"$($_.Key)=$($_.Value)"}) -join "`n"
    if ($newText -eq $existingText) {
        Write-Host "Already set Regedit favorites$titleSuffix" -ForegroundColor DarkGray
        return
    }
    #Delete all favorites then add them back, as regedit shows them in insertion order. https://superuser.com/questions/1860659/where-is-the-ordering-of-windows-regedit-favorites-menu-stored
    Remove-ItemProperty -Path $favoritesPath -Name "*"
    foreach ($favorite in $newFavorites.GetEnumerator()) {
        Set-ItemProperty -LiteralPath $favoritesPath -Name $favorite.Key -Value $favorite.Value
    }
    echo "Set Regedit favorites$titleSuffix"
}
setRegistryFavorites
if ($applyToDefaultUser) {
    setRegistryFavorites (getDefaultUserRegPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites") " for default user"
}
