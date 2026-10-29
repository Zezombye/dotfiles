
$notepadplusplusPath = "$env:ProgramFiles\Notepad++\notepad++.exe"
if (-not (Test-Path -LiteralPath $notepadplusplusPath)) {
    Write-Host "Could not find Notepad++ install path at '$notepadplusplusPath'. Install it at https://notepad-plus-plus.org/downloads/ if necessary." -ForegroundColor Yellow
} else {
    #Todo: maybe on a new windows install notepad++ is not registered. Potentially gotta use Register-FTA
    $nppConfigPath = "$env:APPDATA\Notepad++\config.xml"
    $nppSettings = @(
        #GUIConfig name, attribute, value, message
        @("ScintillaPrimaryView", "Wrap", "yes", "Enabled Notepad++ line wrap"),
        @("ScintillaPrimaryView", "scrollBeyondLastLine", "yes", "Enabled Notepad++ scroll beyond last line"),
        #Set new document to be LF instead of CRLF
        @("NewDocDefaultSettings", "format", "2", "Set Notepad++ new document line ending to LF"),
        @("DarkMode", "enable", "yes", "Set Notepad++ dark mode")
    )

    function getNppConfigChanges {
        #Returns config.xml with $nppSettings applied, and the messages of the changed settings
        $xml = New-Object xml
        #Unlike Get-Content, uses the encoding of the xml declaration
        $xml.Load($nppConfigPath)
        $changedSettings = @()
        foreach ($setting in $nppSettings) {
            $guiConfigName, $attribute, $value, $message = $setting
            $node = $xml.SelectSingleNode("//GUIConfig[@name='$guiConfigName']")
            if (-not $node) {throw "Could not find '$guiConfigName' node in config.xml"}
            if ($node.GetAttribute($attribute) -ne $value) {
                $node.SetAttribute($attribute, $value)
                $changedSettings += $message
            }
        }
        return @{Xml = $xml; ChangedSettings = $changedSettings}
    }

    #Notepad++ creates config.xml when it exits, so if it was never run, launch and close it (if it is running for the first time, closing it is enough)
    if (-not (Test-Path -LiteralPath $nppConfigPath) -and (promptCloseProcess "notepad++") -and -not (Test-Path -LiteralPath $nppConfigPath)) {
        $nppProcess = Start-Process -FilePath $notepadplusplusPath -PassThru
        #The main window must exist to be closed
        $nppDeadline = (Get-Date).AddSeconds(30)
        while ($nppProcess.MainWindowHandle -eq 0) {
            if ($nppProcess.HasExited -or (Get-Date) -gt $nppDeadline) {throw "Notepad++ did not open its window"}
            Start-Sleep -Milliseconds 100
            $nppProcess.Refresh()
        }
        #Unlike killing it, closing the window makes Notepad++ write its config
        [void]$nppProcess.CloseMainWindow()
        if (-not $nppProcess.WaitForExit(30000)) {throw "Notepad++ did not close"}
        if (-not (Test-Path -LiteralPath $nppConfigPath)) {throw "Notepad++ did not create '$nppConfigPath'"}
        echo "Launched and closed Notepad++ to create its config"
    }

    if (-not (Test-Path -LiteralPath $nppConfigPath)) {
        Write-Host "Cannot set Notepad++ config, notepad++.exe is running" -ForegroundColor Yellow
    } else {
        $nppConfigChanges = getNppConfigChanges
        if ($nppConfigChanges.ChangedSettings.Count -eq 0) {
            Write-Host "Already set Notepad++ config" -ForegroundColor DarkGray
        } elseif (-not (promptCloseProcess "notepad++")) {
            Write-Host "Cannot set Notepad++ config, notepad++.exe is running" -ForegroundColor Yellow
        } else {
            #Notepad++ writes config.xml when it exits, so read it again in case it was just closed
            $nppConfigChanges = getNppConfigChanges
            $nppConfigChanges.Xml.Save($nppConfigPath)
            foreach ($message in $nppConfigChanges.ChangedSettings) {
                echo $message
            }
        }
    }

    #Don't associate .bat and .ps1, otherwise we can no longer run batch files from the command line
    try {
        [Registry.Utils]::DeleteKey("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.bat\UserChoice")
    } catch {}
    try {
        [Registry.Utils]::DeleteKey("Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ps1\UserChoice")
    } catch {}

    Set-FTA Applications\notepad++.exe .
    
    $extensions = @(

        #.log.1, .log.2, etc.
        #We don't know if it's a text file, but those extensions are typically only used for logs
        ".0",".1",".2",".3",".4",".5",".6",".7",".8",".9",".10",".11",".12",".13",".14",".15",".16",".17",".18",".19",".20",

        #Feel free to suggest more txt extensions
        #https://fileinfo.com/filetypes/text
        ".adoc",
        ".asc",
        ".asciidoc",
        ".asm",
        #".bat", #breaks execution of scripts
        ".bashrc",
        ".bash_login",
        ".bash_logout",
        ".bash_history",
        ".bash_profile",
        ".browserslistrc",
        ".c",
        ".cfg",
        ".cgi",
        ".cjs",
        ".conf",
        ".cpp",
        ".cs",
        ".css",
        ".dsc",
        ".editorconfig",
        ".env",
        ".gitattributes",
        ".gitconfig",
        ".gitignore",
        ".gradle",
        ".h",
        ".hpp",
        ".info",
        ".ini",
        ".js",
        ".json",
        ".jsx",
        ".lesshst",
        ".log",
        ".md",
        ".mjs",
        ".mts",
        ".mysql_history",
        ".nfo",
        ".node_repl_history",
        ".npmrc",
        ".php",
        ".pl",
        ".profile",
        ".properties",
        #".ps1",
        ".py",
        ".python_history",
        ".readme",
        ".rb",
        ".rs",
        ".rst",
        ".ruby-gemset",
        ".ruby-version",
        ".sass",
        ".scss",
        ".sh",
        ".sql",
        ".sqlite_history",
        ".sqliterc",
        ".toml",
        ".ts",
        ".tsx",
        ".txt",
        ".vbs",
        ".viminfo",
        ".vimrc",
        ".vscodeignore",
        ".vue",
        ".wsf",
        ".xml",
        ".yaml",
        ".yml"
    )
    foreach ($ext in $extensions) {
        Set-FTA Applications\notepad++.exe $ext
    }
}
