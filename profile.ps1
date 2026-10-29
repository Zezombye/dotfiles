# irm zez.dev | iex

#https://www.it-connect.fr/comment-personnaliser-le-prompt-de-son-environnement-powershell/
#https://github.com/tbaheux/itconnect/blob/master/profile.ps1

#Automatically add HKU and HKCR registry drives
if (-not (Test-Path "HKU:")) {
    New-PSDrive HKU Registry HKEY_USERS | Out-Null
}
if (-not (Test-Path "HKCR:")) {
    New-PSDrive -Name "HKCR" -PSProvider Registry -Root "HKEY_CLASSES_ROOT" | Out-Null
}

function prompt {
    #profile.ps1 is also loaded when running scripts (powershell -File/-Command), but prompt is only called in interactive sessions, so terminal-only functions are defined at the first prompt
    if (-not $global:terminalFunctionsDefined) {
        $global:terminalFunctionsDefined = $true
        if (Get-Command git -ErrorAction SilentlyContinue) {
            #Same as gacp in main.sh
            function global:gacp {
                param ([string]$message = "")
                git add -A
                #PowerShell 5.1 does not pass empty arguments to native programs, so -m $message would fail with an empty message
                if ($LASTEXITCODE -eq 0) { git commit --allow-empty-message "--message=$message" }
                if ($LASTEXITCODE -eq 0) { git push }
            }
        }
    }

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    #Unlike $env:hostname, the hostname command returns the dns name (which isn't all uppercase)
    $currentHost = $(hostname)
    #Remove redundant domain name from user
    $currentUser = $currentUser -replace [regex]::Escape("$currentHost\".toUpper()), ''
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    $isInSsh = Test-Path env:SSH_CONNECTION
    #Disable admin indicator in ssh sessions, as it seems windows puts admin by default
    $adminPrompt = if ($currentSid -eq "S-1-5-18") { "[SYSTEM] " } elseif ($isAdmin -and -not $isInSsh) { "[Admin] " } else { "" }
    $sshPrompt = "$currentUser@$currentHost"
    $currentPath = (Get-Location).Path

    #feels too weird
    #$currentPath = $currentPath -replace [regex]::Escape($env:USERPROFILE), '~'

    try {
        $gitBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
        #If checking out a specific commit, we need to use --short
        if ($gitBranch -eq "HEAD") {
            $gitBranch = (git rev-parse --short HEAD 2>$null)
        }
        if ($gitBranch -eq "master" -or $gitBranch -eq "main") {
            $gitBranch = ""
        }
    } catch {
        $gitBranch = ""
    }
    $host.UI.RawUI.WindowTitle = "$adminPrompt$currentPath$(if ($gitBranch) { " ($gitBranch)" } else { '' }) - Powershell"
    Write-Host $adminPrompt -NoNewline -ForegroundColor Red
    if ($isInSsh) {
        Write-Host "$sshPrompt " -NoNewline -foregroundcolor magenta
    }
    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "$currentPath" -NoNewline -ForegroundColor Cyan
    if ($gitBranch) {
        if ($isInSsh) {
            Write-Host " $gitBranch" -NoNewline -ForegroundColor Yellow
        } else {
            Write-Host " $gitBranch" -NoNewline -ForegroundColor Magenta
        }
    }
    #It seems it is not possible to accurately detect if the last command failed
    #if ($? -eq $false) {
    #    Write-Host ">" -NoNewline -ForegroundColor Red
    #} else {
    #    Write-Host ">" -NoNewline -ForegroundColor White
    #}
    return "$([char]27)[0m> "
}
