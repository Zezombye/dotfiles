
$notepadplusplusPath = "$env:ProgramFiles\Notepad++\notepad++.exe"
if (-not (Test-Path -LiteralPath $notepadplusplusPath)) {
    Write-Host "Could not find Notepad++ install path at '$notepadplusplusPath'. Install it at https://notepad-plus-plus.org/downloads/ if necessary." -ForegroundColor Yellow
} else {
    #Todo: maybe on a new windows install notepad++ is not registered. Potentially gotta use Register-FTA
    $ConfigPath = "$env:APPDATA\Notepad++\config.xml"
    $Xml = [xml](Get-Content -Path $ConfigPath)
    $Node = $Xml.SelectSingleNode("//GUIConfig[@name='ScintillaPrimaryView']")

    $areNppModificationsRequired = $false
    if ($Node) {
        if ($Node.GetAttribute("Wrap") -eq "yes") {
            Write-Host "Already enabled Notepad++ line wrap" -ForegroundColor DarkGray
        } else {
            $Node.SetAttribute("Wrap", "yes")
            $areNppModificationsRequired = $true
            echo "Enabled Notepad++ line wrap"
        }
        if ($Node.GetAttribute("scrollBeyondLastLine") -eq "yes") {
            Write-Host "Already enabled Notepad++ scroll beyond last line" -ForegroundColor DarkGray
        } else {
            $Node.SetAttribute("scrollBeyondLastLine", "yes")
            $areNppModificationsRequired = $true
            echo "Enabled Notepad++ scroll beyond last line"
        }
    }
    else {
        Write-Error "Could not find 'ScintillaPrimaryView' node in config.xml"
    }

    #Set new document to be LF instead of CRLF
    $Node = $Xml.SelectSingleNode("//GUIConfig[@name='NewDocDefaultSettings']")
    if ($Node) {
        if ($Node.GetAttribute("format") -eq "2") {
            Write-Host "Already set Notepad++ new document line ending to LF" -ForegroundColor DarkGray
        } else {
            $Node.SetAttribute("format", "2")
            $areNppModificationsRequired = $true
            echo "Set Notepad++ new document line ending to LF"
        }
    }
    else {
        Write-Error "Could not find 'NewDocDefaultSettings' node in config.xml"
    }
    
    if ($areNppModificationsRequired) {
        if (Get-Process -Name "notepad++" -ErrorAction SilentlyContinue) {
            Write-Host "Notepad++ is running, close it then relaunch this script to modify the notepad++ config" -ForegroundColor Yellow
        } else {
            $Xml.Save($ConfigPath)
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
