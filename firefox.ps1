
#Only for the current user (new users get the default preferences below)
$firefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$firefoxPath = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
#Profiles are created when Firefox is first launched
if (-not (Test-Path -LiteralPath $firefoxProfilesPath) -and (Test-Path -LiteralPath $firefoxPath)) {
    #Firefox creates its profiles like a normal first launch, then exits once the screenshot is taken
    $firefoxScreenshotPath = "$env:TEMP\zez.dev_firefox_first_launch.png"
    Start-Process -FilePath $firefoxPath -ArgumentList "--headless", "--screenshot", "`"$firefoxScreenshotPath`"", "about:blank" -Wait
    Remove-Item -LiteralPath $firefoxScreenshotPath
    echo "Launched Firefox headless to create its profiles"
}
if (Test-Path -LiteralPath $firefoxProfilesPath) {
    foreach ($firefoxProfile in Get-ChildItem -LiteralPath $firefoxProfilesPath -Directory) {
        $firefoxProfileName = $firefoxProfile.Name
        $firefoxProfilePath = $firefoxProfile.FullName
        §writeFile {"src": "userChrome.css", "dest": "$firefoxProfilePath\chrome\userChrome.css", "msg": "Set Firefox userChrome.css for profile $firefoxProfileName"}
        #user.js is read at each startup, so Firefox does not need to be closed
        §writeFile {"src": "firefox_user.js", "dest": "$firefoxProfilePath\user.js", "msg": "Set Firefox preferences for profile $firefoxProfileName"}
    }
}
#Firefox loads all the files of defaults\pref as default preferences, for all users
if ($applyToDefaultUser -and (Test-Path -LiteralPath $firefoxPath)) {
    §writeFile {"src": "firefox_user.js", "dest": "$env:ProgramFiles\Mozilla Firefox\defaults\pref\zez.dev.js", "msg": "Set Firefox default preferences", "replace": {"user_pref(": "pref("}}
}
