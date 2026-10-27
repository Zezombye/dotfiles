
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

        "HKCU:\Software\Microsoft\Windows\CurrentVersion",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",

        "HKLM:\Software\Microsoft\Windows\CurrentVersion",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows NT\CurrentVersion",
        "HKLM:\System\CurrentControlSet",
        "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
    )

    if (-not (Test-Path $favoritesPath)) {
        New-Item -Path $favoritesPath -Force | Out-Null
    }
    $existingProps = Get-ItemProperty $favoritesPath
    $existingFavorites = @{}
    
    foreach ($prop in $existingProps.PSObject.Properties) {
        if ($prop.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
            $existingFavorites[$prop.Name] = $prop.Value
        }
    }

    function Get-RegeditPath {
        param([string]$path)
        $path = $path -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
        $path = $path -replace '^HKCU:\\', 'HKEY_CURRENT_USER\'
        $path = $path -replace '^HKCR:\\', 'HKEY_CLASSES_ROOT\'
        $path = $path -replace '^HKU:\\',  'HKEY_USERS\'
        return $path
    }

    $allItems = [System.Collections.ArrayList]::new()

    foreach ($name in $existingFavorites.Keys) {
        $val = $existingFavorites[$name]
        $hive = "Other"
        
        if ($name -match "^HKCR:\\") { $hive = "HKCR" }
        elseif ($name -match "^HKCU:\\") { $hive = "HKCU" }
        elseif ($name -match "^HKLM:\\") { $hive = "HKLM" }
        elseif ($name -match "^HKU:\\")  { $hive = "HKU" }
        #Remove existing separators
        if ($name -match "^ +$") { continue }
        
        $allItems.Add([PSCustomObject]@{
            Name  = $name
            Value = $val
            Hive  = $hive
        }) | Out-Null
    }

    $nbAddedFavorites = 0
    foreach ($favPath in $favorites) {
        $alreadyExists = $allItems | Where-Object { $_.Name -eq $favPath }
        
        if (-not $alreadyExists) {
            $regVal = Get-RegeditPath -path $favPath
            
            $hive = "Other"
            if ($favPath -match "^HKCR:\\") { $hive = "HKCR" }
            elseif ($favPath -match "^HKCU:\\") { $hive = "HKCU" }
            elseif ($favPath -match "^HKLM:\\") { $hive = "HKLM" }
            elseif ($favPath -match "^HKU:\\")  { $hive = "HKU" }

            $allItems.Add([PSCustomObject]@{
                Name  = $favPath
                Value = $regVal
                Hive  = $hive
            }) | Out-Null
            $nbAddedFavorites++ | Out-Null
        }
    }

    if ($nbAddedFavorites -eq 0) {
        Write-Host "Already added Regedit favorites$titleSuffix" -ForegroundColor DarkGray
        return
    }

    #Order all favorites
    #Replace space with "~" so that "Windows NT\" comes after "Windows\"
    $sortExpr = @{ Expression = { $_.Name.Replace(' ', '~') } }
    $bucketHKCR = $allItems | Where-Object { $_.Hive -eq "HKCR" } | Sort-Object $sortExpr
    $bucketHKCU = $allItems | Where-Object { $_.Hive -eq "HKCU" } | Sort-Object $sortExpr
    $bucketHKLM = $allItems | Where-Object { $_.Hive -eq "HKLM" } | Sort-Object $sortExpr
    $bucketHKU  = $allItems | Where-Object { $_.Hive -eq "HKU" }  | Sort-Object $sortExpr
    $bucketOther= $allItems | Where-Object { $_.Hive -eq "Other" }| Sort-Object $sortExpr

    $global:spaceCounter = 1
    function Get-Separator {
        $sep = " " * $global:spaceCounter
        $global:spaceCounter++
        return [PSCustomObject]@{ Name = $sep; Value = "" }
    }
    $finalList = @()

    if ($bucketHKCR) { 
        $finalList += $bucketHKCR
    }
    if ($bucketHKCU) { 
        if ($bucketHKCR) {
            $finalList += (Get-Separator) 
        }
        $finalList += $bucketHKCU
    }
    if ($bucketHKLM) {
        if ($bucketHKCR -or $bucketHKCU) {
            $finalList += (Get-Separator) 
        }
        $finalList += $bucketHKLM
    }
    if ($bucketHKU) { 
        if ($bucketHKCR -or $bucketHKCU -or $bucketHKLM) {
            $finalList += (Get-Separator) 
        }
        $finalList += $bucketHKU
    }
    if ($bucketOther) {
        if ($bucketHKCR -or $bucketHKCU -or $bucketHKLM -or $bucketHKU) {
            $finalList += (Get-Separator) 
        }
        $finalList += $bucketOther
    }

    #Delete all existing favorites then replace, as the order is determined by the insertion order. https://superuser.com/questions/1860659/where-is-the-ordering-of-windows-regedit-favorites-menu-stored

    #echo ($finalList | ConvertTo-Json)
    Remove-ItemProperty -Path $favoritesPath -Name "*"
    foreach ($item in $finalList) {
        if ($item) {
            Set-ItemProperty -Path $favoritesPath -Name $item.Name -Value $item.Value
        }
    }
    Write-Host "Added $nbAddedFavorites Regedit Favorites$titleSuffix"
}
setRegistryFavorites
if ($applyToDefaultUser) {
    setRegistryFavorites (getDefaultUserRegPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites") " for default user"
}
