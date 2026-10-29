# Version: 2026-10-29
# irm zez.dev | iex

echo ""
echo "   _____             _          _       ___         __                      _____      __            "
echo "  /__  /  ___  ____ ( )_____   | |     / (_)___  ____/ /___ _      _______   / ___/___  / /___  ______ "
echo "    / /  / _ \/_  / |// ___/   | | /| / / / __ \/ __  / __ \ | /| / / ___/   \__ \/ _ \/ __/ / / / __ \"
echo "   / /__/  __/ / /_  (__  )    | |/ |/ / / / / / /_/ / /_/ / |/ |/ (__  )   ___/ /  __/ /_/ /_/ / /_/ /"
echo "  /____/\___/ /___/ /____/     |__/|__/_/_/ /_/\__,_/\____/|__/|__/____/   /____/\___/\__/\__,_/ .___/ "
echo "                                                                                              /_/      "
echo ""


$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
trap {
    Write-Host ($_ | Out-String) -ForegroundColor Red
    #A loaded hive locks the default profile files. Unloaded before the pause, in case the console is closed during it
    if ($applyToDefaultUser) {
        try {unloadDefaultUserHives} catch {Write-Host ($_ | Out-String) -ForegroundColor Red}
    }
    Read-Host "Press Enter to exit"
    break
}

$isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

function promptRelaunchAsAdmin {
    #Returns $true if the script was relaunched in a new elevated window
    if ($isAdmin) {return $false}
    $answer = Read-Host "Not running as Administrator. Relaunch as Administrator? [Y/n]"
    if ($answer -notin @("", "y", "yes")) {return $false}
    if ($PSCommandPath) {
        $arguments = @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    } else {
        #Launched with "irm zez.dev | iex", so there is no script file to relaunch
        $arguments = @("-NoExit", "-Command", "irm zez.dev | iex")
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    return $true
}
#Use return instead of exit, as exit would close the user's console when launched with iex
if (promptRelaunchAsAdmin) {return}

if ($isAdmin) {echo "Running as Administrator"} else {echo "Running as standard user. Some tweaks may not be applied."}

$isWindows11 = ((Get-CimInstance -ClassName Win32_OperatingSystem).Version -ge "10.0.22000")
if ($isWindows11) {echo "Detected Windows 11"} else {echo "Detected Windows 10 or lower"}

#Allow running local scripts (eg the npm.ps1 and pnpm.ps1 shims), for all users if admin, else for the current user
$executionPolicyScope, $executionPolicySuffix = if ($isAdmin) {"LocalMachine", ""} else {"CurrentUser", " for current user"}
if ((Get-ExecutionPolicy -Scope $executionPolicyScope) -in @("RemoteSigned", "Unrestricted", "Bypass")) {
    Write-Host "Already allowed PowerShell scripts$executionPolicySuffix" -ForegroundColor DarkGray
} else {
    try {
        Set-ExecutionPolicy RemoteSigned -Scope $executionPolicyScope -Force
    } catch {
        #Thrown although the policy is set, if a more specific scope overrides it (eg -ExecutionPolicy Bypass when relaunched as admin)
        if ($_.FullyQualifiedErrorId -notlike "ExecutionPolicyOverride,*") {throw}
    }
    echo "Allowed PowerShell scripts$executionPolicySuffix"
}

$needsExplorerRestart = $false
$needsSignOut = $false
$needsAdmin = $false

if (-not (Test-Path "HKU:")) {New-PSDrive HKU Registry HKEY_USERS | Out-Null}
if (-not (Test-Path "HKCR:")) {New-PSDrive -Name "HKCR" -PSProvider Registry -Root "HKEY_CLASSES_ROOT" | Out-Null}


$defaultUserHive = "zez.dev_DefaultUser"
$defaultUserClassesHive = "zez.dev_DefaultUser_Classes"
$defaultUserProfile = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList").Default

function loadDefaultUserHives {
    $hives = @(
        @($defaultUserHive, "$defaultUserProfile\NTUSER.DAT"),
        #HKCU\Software\Classes is stored in UsrClass.dat instead of NTUSER.DAT
        @($defaultUserClassesHive, "$defaultUserProfile\AppData\Local\Microsoft\Windows\UsrClass.dat")
    )
    foreach ($hive in $hives) {
        #The hive may still be loaded if a previous run was interrupted
        $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($hive[0])
        if ($key -ne $null) {
            $key.Close()
            continue
        }
        reg.exe load "HKU\$($hive[0])" $hive[1] | Out-Null
        if ($LASTEXITCODE -ne 0) {throw "Failed to load '$($hive[1])' into 'HKU\$($hive[0])'"}
    }
}

function unloadDefaultUserHives {
    #Registry handles must be released before the hives can be unloaded
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    foreach ($hiveName in @($defaultUserHive, $defaultUserClassesHive)) {
        $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($hiveName)
        if ($key -eq $null) {continue}
        $key.Close()
        reg.exe unload "HKU\$hiveName" | Out-Null
        if ($LASTEXITCODE -ne 0) {throw "Failed to unload 'HKU\$hiveName'"}
    }
}

function getDefaultUserRegPath {
    param ([string]$regPath)
    $regPath = $regPath.Replace("/", "\")
    if ($regPath -notmatch "^HKCU:") {throw "'$regPath' is not in HKCU"}
    if ($regPath -match "^HKCU:\\Software\\Classes(\\|$)") {
        return $regPath -replace "^HKCU:\\Software\\Classes", "HKU:\$defaultUserClassesHive"
    }
    return $regPath -replace "^HKCU:", "HKU:\$defaultUserHive"
}

#Processes for which the user chose to continue while they are running, so that they are not asked again
$ignoredRunningProcesses = @()

function promptCloseProcess {
    #Returns $true if the process is not running (asking the user to close it if it is), $false if the user chose to continue while it is running
    param ([string]$processName)
    while (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        if ($processName -in $script:ignoredRunningProcesses) {return $false}
        $answer = Read-Host "$processName.exe is running, settings cannot be edited. Continue anyway? [y/N]"
        if ($answer -in @("y", "yes")) {
            $script:ignoredRunningProcesses += $processName
            return $false
        }
    }
    return $true
}

function grantRegKeyPermissions {
    param ([string]$regPath)
    if (-not $regPath.startswith("HKCR:", "CurrentCultureIgnoreCase")) {
        throw "Unsupported hive for granting permissions to '$regPath'"
    }
    $regPath = $regPath.Substring(5)

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    using System.Security.AccessControl;

    public class RegistryOwnership
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern int RegOpenKeyEx(
            IntPtr hKey,
            string subKey,
            int ulOptions,
            int samDesired,
            out IntPtr hkResult);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern int RegCloseKey(IntPtr hKey);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern int RegSetKeySecurity(
            IntPtr hKey,
            int SecurityInformation,
            byte[] pSecurityDescriptor);

        public const int WRITE_OWNER = 0x00080000;
        public const int WRITE_DAC = 0x00040000;
        public static readonly IntPtr HKEY_CLASSES_ROOT = new IntPtr(unchecked((int)0x80000000));
        public const int OWNER_SECURITY_INFORMATION = 0x00000001;
        public const int DACL_SECURITY_INFORMATION = 0x00000004;
    }
"@

    # Enable SeRestorePrivilege and SeTakeOwnershipPrivilege
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class TokenManipulator
    {
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
            ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern IntPtr GetCurrentProcess();

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);

        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        internal struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }

        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

        public static bool AddPrivilege(string privilege)
        {
            IntPtr hproc = GetCurrentProcess();
            IntPtr htok = IntPtr.Zero;
            if (!OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok))
                return false;
            
            TokPriv1Luid tp;
            tp.Count = 1;
            tp.Luid = 0;
            tp.Attr = SE_PRIVILEGE_ENABLED;
            
            if (!LookupPrivilegeValue(null, privilege, ref tp.Luid))
                return false;
            
            return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        }
    }
"@

    [TokenManipulator]::AddPrivilege("SeRestorePrivilege") | Out-Null
    [TokenManipulator]::AddPrivilege("SeTakeOwnershipPrivilege") | Out-Null
    [TokenManipulator]::AddPrivilege("SeBackupPrivilege") | Out-Null

    $hKey = [IntPtr]::Zero
    # Open key with WRITE_OWNER access
    $result = [RegistryOwnership]::RegOpenKeyEx(
        [RegistryOwnership]::HKEY_CLASSES_ROOT,
        $regPath,
        0,
        [RegistryOwnership]::WRITE_OWNER,
        [ref]$hKey
    )
    if ($result -ne 0) {
        throw "Failed to open key '$regPath'. Error: $result"
    }

    $keyCR = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($regPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
    $aclCR = $keyCR.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
    $adminsSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $aclCR.SetOwner($adminsSid)
    $keyCR.SetAccessControl($aclCR)

    $AddACL = New-Object System.Security.AccessControl.RegistryAccessRule ($adminsSid,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $aclCR = $keyCR.GetAccessControl()
    $aclCR.SetAccessRule($AddACL)
    $keyCR.SetAccessControl($aclCR)
    $keyCR.Close()

    #[RegistryOwnership]::RegCloseKey([IntPtr]::Zero) | Out-Null

}

function applyRegEdits {
    #Generic function to edit/remove keys and properties, and check if the changes are already applied
    param (
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [array]$Modifications,
        [switch]$ForDefaultUser
    )
    #Fix for the array unrolling behavior
    if ($modifications[0] -is [string]) {
        $Modifications = @(,$Modifications)
    }

    $areModificationsRequired = $false

    $titleParts = $Title -split " ", 2
    $lowercaseTitle = $titleParts[0].ToLower() + " " + $titleParts[1]
    $titleParts[0] = switch ($titleParts[0]) {
        "Add"      { "Added" }
        "Remove"   { "Removed" }
        "Set"      { "Set" }
        "Increase" { "Increased" }
        "Enable"   { "Enabled" }
        "Disable"  { "Disabled" }
        "Restore"  { "Restored" }
        "Fix"      { "Fixed" }
        Default    { $titleParts[0] + "ed" }
    }
    $pastTenseTitle = $titleParts[0] + " " + $titleParts[1]
    $lowercasePastTenseTitle = $titleParts[0].ToLower() + " " + $titleParts[1]

    foreach ($mod in $Modifications) {
        $action = $mod[0]
        if (@("RemoveKey","NewKey","RemoveProperty","SetProperty") -notcontains $action) {
            throw "Unknown action '$action'"
        }
        $key = $mod[1]
        if (-not ($key)) {throw "No key specified for action '$action'"}
        $key = $key.replace("/", "\")
        $pathParts = $key -split "\\", 2
        $hiveName = $pathParts[0].TrimEnd(':') # Remove colon (HKCU: -> HKCU)
        $subKeyPath = if ($pathParts.Count -gt 1) { $pathParts[1] } else { "" }

        $rootKey = switch ($hiveName) {
            { $_ -eq "HKCR" } { [Microsoft.Win32.Registry]::ClassesRoot }
            { $_ -eq "HKCU" } { [Microsoft.Win32.Registry]::CurrentUser }
            { $_ -eq "HKLM" } { [Microsoft.Win32.Registry]::LocalMachine }
            { $_ -eq "HKU" } { [Microsoft.Win32.Registry]::Users }
            Default { throw "Unknown registry hive '$hiveName'" }
        }
        $hiveNameNeedsAdmin = ($hiveName -in @("HKLM","HKU","HKCR"))

        if ($action -eq "RemoveKey") {
            $additionalParams = $mod[2]
            
            $existingKey = $rootKey.OpenSubKey($subKeyPath, $false)
            if ($existingKey -eq $null) {continue}
            $existingKey.Close()
            
        } elseif ($action -eq "RemoveProperty") {
            $property = $mod[2]
            if (-not ($property)) { throw "No property specified for action '$action'" }
            $additionalParams = $mod[3]

            $existingKey = $rootKey.OpenSubKey($subKeyPath, $false)
            if ($existingKey -eq $null) {continue}
            
            $existingValue = $existingKey.GetValue($property)
            $existingKey.Close()
            if ($existingValue -eq $null) {continue}
            
        } elseif ($action -eq "NewKey") {
            $additionalParams = $mod[2]
            
            $existingKey = $rootKey.OpenSubKey($subKeyPath, $false)
            if ($existingKey -ne $null) {
                $existingKey.Close()
                continue
            }

        } elseif ($action -eq "SetProperty") {
            $property = $mod[2]
            if (-not ($property)) { throw "No property specified for action '$action'" }
            if ($property -eq "(default)") {$property = ""}
            $value = $mod[3]
            if ($null -eq $value) { throw "No value specified for action '$action'" }
            $additionalParams = $mod[4]

            $existingKey = $rootKey.OpenSubKey($subKeyPath, $false)
            if ($existingKey -ne $null) {
                $existingValue = $existingKey.GetValue($property)
                $existingKey.Close()
                if ($existingValue -ne $null -and $existingValue.getType().Name -eq "Byte[]") {
                    if (@(Compare-Object $existingValue $value -SyncWindow 0).Length -eq 0) {continue}
                } elseif ($existingValue -eq $value) {continue} 
            }
        }
        
        if ($hiveNameNeedsAdmin -and -not $isAdmin) {
            Write-Host "Cannot $lowercaseTitle, needs admin rights" -ForegroundColor Yellow
            return
        }
        
        if ($additionalParams.grantPermissions -eq $true) {
            grantRegKeyPermissions $key
        }

        $areModificationsRequired = $true

        if ($action -eq "RemoveKey") {
            $rootKey.DeleteSubKeyTree($subKeyPath)

        } elseif ($action -eq "RemoveProperty") {
            $rwKey = $rootKey.OpenSubKey($subKeyPath, $true)
            $rwKey.DeleteValue($property)
            $rwKey.Close()

        } elseif ($action -eq "NewKey") {
            $rootKey.CreateSubKey($subKeyPath).Close()

        } elseif ($action -eq "SetProperty") {
            $regKind = [Microsoft.Win32.RegistryValueKind]::String # Default
            if ($value -is [int]) {
                $regKind = [Microsoft.Win32.RegistryValueKind]::DWord
            } elseif ($value -is [long]) {
                $regKind = [Microsoft.Win32.RegistryValueKind]::QWord
            } elseif ($value -is [byte[]]) {
                $regKind = [Microsoft.Win32.RegistryValueKind]::Binary
            }
            if ($additionalParams -and $additionalParams.ContainsKey("Type")) {
                switch ($additionalParams["Type"]) {
                    "DWord"        { $regKind = [Microsoft.Win32.RegistryValueKind]::DWord }
                    "QWord"        { $regKind = [Microsoft.Win32.RegistryValueKind]::QWord }
                    "Binary"       { $regKind = [Microsoft.Win32.RegistryValueKind]::Binary }
                    "ExpandString" { $regKind = [Microsoft.Win32.RegistryValueKind]::ExpandString }
                    "MultiString"  { $regKind = [Microsoft.Win32.RegistryValueKind]::MultiString }
                }
            }

            $rwKey = $rootKey.CreateSubKey($subKeyPath, $true)
            $rwKey.SetValue($property, $value, $regKind)
            $rwKey.Close()
        }
    }

    if ($areModificationsRequired) {
        Write-Host "$pastTenseTitle"
    } else {
        Write-Host "Already $lowercasePastTenseTitle" -ForegroundColor DarkGray
    }

    if ($areModificationsRequired -and -not $ForDefaultUser -and $additionalParams.explorerRestart -eq $true) {
        $script:needsExplorerRestart = $true
    }
    if ($areModificationsRequired -and -not $ForDefaultUser -and $additionalParams.signout -eq $true) {
        $script:needsSignOut = $true
    }

    if ($applyToDefaultUser -and -not $ForDefaultUser) {
        $defaultUserModifications = @()
        foreach ($mod in $Modifications) {
            if ($mod[1] -match "^HKCU:") {
                $defaultUserMod = $mod.Clone()
                $defaultUserMod[1] = getDefaultUserRegPath $mod[1]
                $defaultUserModifications += ,$defaultUserMod
            }
        }
        if ($defaultUserModifications.Count -gt 0) {
            applyRegEdits "$Title for default user" $defaultUserModifications -ForDefaultUser
        }
    }
}


#Code from https://github.com/DanysysTeam/PS-SFTA/blob/master/SFTA.ps1
#Defeats the UserChoice hash and allows setting file type associations
function Get-UserExperience {
    [OutputType([string])]
    $hardcodedExperience = "User Choice set via Windows User Experience {D18B6DD5-6124-4341-9318-804003BAFA0B}"
    $userExperienceSearch = "User Choice set via Windows User Experience"
    $userExperienceString = ""
    $user32Path = [Environment]::GetFolderPath([Environment+SpecialFolder]::SystemX86) + "\Shell32.dll"
    $fileStream = [System.IO.File]::Open($user32Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $binaryReader = New-Object System.IO.BinaryReader($fileStream)
    [Byte[]] $bytesData = $binaryReader.ReadBytes(5mb)
    $fileStream.Close()
    $dataString = [Text.Encoding]::Unicode.GetString($bytesData)
    $position1 = $dataString.IndexOf($userExperienceSearch)
    $position2 = $dataString.IndexOf("}", $position1)
    try {
        $userExperienceString = $dataString.Substring($position1, $position2 - $position1 + 1)
    } catch {
        $userExperienceString = $hardcodedExperience
    }
    Write-Output $userExperienceString
}

$userExperience = Get-UserExperience
$code = '
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace Registry {
    public class Utils {
        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern int RegOpenKeyEx(UIntPtr hKey, string subKey, int ulOptions, int samDesired, out UIntPtr hkResult);

        [DllImport("advapi32.dll", SetLastError=true, CharSet = CharSet.Unicode)]
        private static extern uint RegDeleteKey(UIntPtr hKey, string subKey);

        public static void DeleteKey(string key) {
            UIntPtr hKey = UIntPtr.Zero;
            RegOpenKeyEx((UIntPtr)0x80000001u, key, 0, 0x20019, out hKey);
            RegDeleteKey((UIntPtr)0x80000001u, key);
        }
    }
}
'

try {
    Add-Type -TypeDefinition $code
} catch {}

$userSid = ((New-Object System.Security.Principal.NTAccount([Environment]::UserName)).Translate([System.Security.Principal.SecurityIdentifier]).value).ToLower()
#or if joined to a domain:
#https://github.com/DanysysTeam/PS-SFTA/pull/7
#if (-not ("System.DirectoryServices.AccountManagement" -as [type])) {
#    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
#}
#$userSid = ([System.DirectoryServices.AccountManagement.UserPrincipal]::Current).SID.Value.#ToLower()

function Set-FTA {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ProgId,

        [Parameter(Mandatory = $true)]
        [Alias("Protocol")]
        [String]
        $Extension,

        [String]
        $Icon
    )

    if (Test-Path -LiteralPath $ProgId) {
        $ProgId = "SFTA." + [System.IO.Path]::GetFileNameWithoutExtension($ProgId).replace(" ", "") + $Extension
    }
    if ([Microsoft.Win32.Registry]::GetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice", "ProgId", $null) -eq $ProgId) {
        #Write-Host "Already set $ProgId for $Extension" -ForegroundColor DarkGray
        return
    }
    echo "Setting $ProgId as default program for extension $Extension"
    #Write required Application Ids to ApplicationAssociationToasts
    #When more than one application associated with an Extension/Protocol is installed ApplicationAssociationToasts need to be updated
    function local:Write-RequiredApplicationAssociationToasts {
        param (
            [Parameter( Position = 0, Mandatory = $True )]
            [String]
            $ProgId,

            [Parameter( Position = 1, Mandatory = $True )]
            [String]
            $Extension
        )

        $keyPath = "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts"
        [Microsoft.Win32.Registry]::SetValue($keyPath, $ProgId + "_" + $Extension, 0x0)
    }

    function local:Write-ExtensionKeys {
        param (
            [Parameter( Position = 0, Mandatory = $True )]
            [String]
            $ProgId,

            [Parameter( Position = 1, Mandatory = $True )]
            [String]
            $Extension,

            [Parameter( Position = 2, Mandatory = $True )]
            [String]
            $ProgHash
        )
        function local:Remove-UserChoiceKey {
            param (
                [Parameter( Position = 0, Mandatory = $True )]
                [String]
                $Key
            )
            try {
                [Registry.Utils]::DeleteKey($Key)
            } catch {}
        }
        try {
            $keyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
            Remove-UserChoiceKey $keyPath
        } catch {}
        try {
            $keyPath = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
            [Microsoft.Win32.Registry]::SetValue($keyPath, "Hash", $ProgHash)
            [Microsoft.Win32.Registry]::SetValue($keyPath, "ProgId", $ProgId)
        } catch {
            throw "Write Reg Extension UserChoice FAILED"
        }
    }

    function local:Get-HexDateTime {
        [OutputType([string])]

        $now = [DateTime]::Now
        $dateTime = [DateTime]::New($now.Year, $now.Month, $now.Day, $now.Hour, $now.Minute, 0)
        $fileTime = $dateTime.ToFileTime()
        $hi = ($fileTime -shr 32)
        $low = ($fileTime -band 0xFFFFFFFFL)
        $dateTimeHex = ($hi.ToString("X8") + $low.ToString("X8")).ToLower()
        Write-Output $dateTimeHex
    }

    function Get-Hash {
        [CmdletBinding()]
        param (
            [Parameter( Position = 0, Mandatory = $True )]
            [string]
            $BaseInfo
        )
        function local:Get-ShiftRight {
            [CmdletBinding()]
            param (
                [Parameter( Position = 0, Mandatory = $true)]
                [long] $iValue,

                [Parameter( Position = 1, Mandatory = $true)]
                [int] $iCount
            )
            if ($iValue -band 0x80000000) {
                Write-Output (( $iValue -shr $iCount) -bxor 0xFFFF0000)
            } else {
                Write-Output  ($iValue -shr $iCount)
            }
        }
        function local:Get-Long {
            [CmdletBinding()]
            param (
                [Parameter( Position = 0, Mandatory = $true)]
                [byte[]] $Bytes,

                [Parameter( Position = 1)]
                [int] $Index = 0
            )
            Write-Output ([BitConverter]::ToInt32($Bytes, $Index))
        }
        function local:Convert-Int32 {
            param (
                [Parameter( Position = 0, Mandatory = $true)]
                [long] $Value
            )
            [byte[]] $bytes = [BitConverter]::GetBytes($Value)
            return [BitConverter]::ToInt32( $bytes, 0)
        }
        [Byte[]] $bytesBaseInfo = [System.Text.Encoding]::Unicode.GetBytes($baseInfo)
        $bytesBaseInfo += 0x00, 0x00

        $MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
        [Byte[]] $bytesMD5 = $MD5.ComputeHash($bytesBaseInfo)

        $lengthBase = ($baseInfo.Length * 2) + 2
        $length = (($lengthBase -band 4) -le 1) + (Get-ShiftRight $lengthBase  2) - 1
        $base64Hash = ""

        if ($length -gt 1) {
            $map = @{PDATA = 0; CACHE = 0; COUNTER = 0 ; INDEX = 0; MD51 = 0; MD52 = 0; OUTHASH1 = 0; OUTHASH2 = 0; R0 = 0; R1 = @(0, 0); R2 = @(0, 0); R3 = 0; R4 = @(0, 0); R5 = @(0, 0); R6 = @(0, 0); R7 = @(0, 0)}

            $map.MD51 = (((Get-Long $bytesMD5) -bor 1) + 0x69FB0000L)
            $map.MD52 = ((Get-Long $bytesMD5 4) -bor 1) + 0x13DB0000L
            $map.INDEX = Get-ShiftRight ($length - 2) 1
            $map.COUNTER = $map.INDEX + 1

            while ($map.COUNTER) {
                $map.R0 = Convert-Int32 ((Get-Long $bytesBaseInfo $map.PDATA) + [long]$map.OUTHASH1)
                $map.R1[0] = Convert-Int32 (Get-Long $bytesBaseInfo ($map.PDATA + 4))
                $map.PDATA = $map.PDATA + 8
                $map.R2[0] = Convert-Int32 (($map.R0 * ([long]$map.MD51)) - (0x10FA9605L * ((Get-ShiftRight $map.R0 16))))
                $map.R2[1] = Convert-Int32 ((0x79F8A395L * ([long]$map.R2[0])) + (0x689B6B9FL * (Get-ShiftRight $map.R2[0] 16)))
                $map.R3 = Convert-Int32 ((0xEA970001L * $map.R2[1]) - (0x3C101569L * (Get-ShiftRight $map.R2[1] 16) ))
                $map.R4[0] = Convert-Int32 ($map.R3 + $map.R1[0])
                $map.R5[0] = Convert-Int32 ($map.CACHE + $map.R3)
                $map.R6[0] = Convert-Int32 (($map.R4[0] * [long]$map.MD52) - (0x3CE8EC25L * (Get-ShiftRight $map.R4[0] 16)))
                $map.R6[1] = Convert-Int32 ((0x59C3AF2DL * $map.R6[0]) - (0x2232E0F1L * (Get-ShiftRight $map.R6[0] 16)))
                $map.OUTHASH1 = Convert-Int32 ((0x1EC90001L * $map.R6[1]) + (0x35BD1EC9L * (Get-ShiftRight $map.R6[1] 16)))
                $map.OUTHASH2 = Convert-Int32 ([long]$map.R5[0] + [long]$map.OUTHASH1)
                $map.CACHE = ([long]$map.OUTHASH2)
                $map.COUNTER = $map.COUNTER - 1
            }

            [Byte[]] $outHash = @(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
            [byte[]] $buffer = [BitConverter]::GetBytes($map.OUTHASH1)
            $buffer.CopyTo($outHash, 0)
            $buffer = [BitConverter]::GetBytes($map.OUTHASH2)
            $buffer.CopyTo($outHash, 4)

            $map = @{PDATA = 0; CACHE = 0; COUNTER = 0 ; INDEX = 0; MD51 = 0; MD52 = 0; OUTHASH1 = 0; OUTHASH2 = 0; R0 = 0; R1 = @(0, 0); R2 = @(0, 0); R3 = 0; R4 = @(0, 0); R5 = @(0, 0); R6 = @(0, 0); R7 = @(0, 0)}

            $map.MD51 = ((Get-Long $bytesMD5) -bor 1)
            $map.MD52 = ((Get-Long $bytesMD5 4) -bor 1)
            $map.INDEX = Get-ShiftRight ($length - 2) 1
            $map.COUNTER = $map.INDEX + 1

            while ($map.COUNTER) {
                $map.R0 = Convert-Int32 ((Get-Long $bytesBaseInfo $map.PDATA) + ([long]$map.OUTHASH1))
                $map.PDATA = $map.PDATA + 8
                $map.R1[0] = Convert-Int32 ($map.R0 * [long]$map.MD51)
                $map.R1[1] = Convert-Int32 ((0xB1110000L * $map.R1[0]) - (0x30674EEFL * (Get-ShiftRight $map.R1[0] 16)))
                $map.R2[0] = Convert-Int32 ((0x5B9F0000L * $map.R1[1]) - (0x78F7A461L * (Get-ShiftRight $map.R1[1] 16)))
                $map.R2[1] = Convert-Int32 ((0x12CEB96DL * (Get-ShiftRight $map.R2[0] 16)) - (0x46930000L * $map.R2[0]))
                $map.R3 = Convert-Int32 ((0x1D830000L * $map.R2[1]) + (0x257E1D83L * (Get-ShiftRight $map.R2[1] 16)))
                $map.R4[0] = Convert-Int32 ([long]$map.MD52 * ([long]$map.R3 + (Get-Long $bytesBaseInfo ($map.PDATA - 4))))
                $map.R4[1] = Convert-Int32 ((0x16F50000L * $map.R4[0]) - (0x5D8BE90BL * (Get-ShiftRight $map.R4[0] 16)))
                $map.R5[0] = Convert-Int32 ((0x96FF0000L * $map.R4[1]) - (0x2C7C6901L * (Get-ShiftRight $map.R4[1] 16)))
                $map.R5[1] = Convert-Int32 ((0x2B890000L * $map.R5[0]) + (0x7C932B89L * (Get-ShiftRight $map.R5[0] 16)))
                $map.OUTHASH1 = Convert-Int32 ((0x9F690000L * $map.R5[1]) - (0x405B6097L * (Get-ShiftRight ($map.R5[1]) 16)))
                $map.OUTHASH2 = Convert-Int32 ([long]$map.OUTHASH1 + $map.CACHE + $map.R3)
                $map.CACHE = ([long]$map.OUTHASH2)
                $map.COUNTER = $map.COUNTER - 1
            }

            $buffer = [BitConverter]::GetBytes($map.OUTHASH1)
            $buffer.CopyTo($outHash, 8)
            $buffer = [BitConverter]::GetBytes($map.OUTHASH2)
            $buffer.CopyTo($outHash, 12)

            [Byte[]] $outHashBase = @(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
            $hashValue1 = ((Get-Long $outHash 8) -bxor (Get-Long $outHash))
            $hashValue2 = ((Get-Long $outHash 12) -bxor (Get-Long $outHash 4))

            $buffer = [BitConverter]::GetBytes($hashValue1)
            $buffer.CopyTo($outHashBase, 0)
            $buffer = [BitConverter]::GetBytes($hashValue2)
            $buffer.CopyTo($outHashBase, 4)
            $base64Hash = [Convert]::ToBase64String($outHashBase)
        }
        Write-Output $base64Hash
    }
    $userDateTime = Get-HexDateTime
    $baseInfo = "$Extension$userSid$ProgId$userDateTime$userExperience".ToLower()
    $progHash = Get-Hash $baseInfo

    Write-RequiredApplicationAssociationToasts $ProgId $Extension
    Write-ExtensionKeys $ProgId $Extension $progHash
}

$applyToDefaultUser = $false
if ($isAdmin) {
    $answer = Read-Host "Also apply the HKCU tweaks to the default user (template for new users)? [y/N]"
    $applyToDefaultUser = $answer -in @("y", "yes")
}
if ($applyToDefaultUser) {
    loadDefaultUserHives
}


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

function setExplorerQuickAccessRibbon {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon'
    $valueName = 'QatItems'

    $raw = $null
    if (Test-Path -LiteralPath $path) {
        $raw = (Get-Item -LiteralPath $path).GetValue($valueName)
    }
    if ($null -eq $raw) {
        #The value is only created once the toolbar is customized, so start from the default one (undo, redo, delete and rename hidden, properties and new folder shown)
        $raw = [Text.Encoding]::UTF8.GetBytes('<siq:customUI xmlns:siq="http://schemas.microsoft.com/windows/2009/ribbon/qat"><siq:ribbon minimized="true"><siq:qat position="0"><siq:sharedControls><siq:control idQ="siq:16128" visible="false" argument="0" /><siq:control idQ="siq:16129" visible="false" argument="0" /><siq:control idQ="siq:12352" visible="false" argument="0" /><siq:control idQ="siq:12384" visible="true" argument="0" /><siq:control idQ="siq:12336" visible="true" argument="0" /><siq:control idQ="siq:12357" visible="false" argument="0" /></siq:sharedControls></siq:qat></siq:ribbon></siq:customUI>')
    }
    $xmlText = [Text.Encoding]::UTF8.GetString($raw)
    [xml]$xml = $xmlText
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace('siq', 'http://schemas.microsoft.com/windows/2009/ribbon/qat')
    $shared = $xml.SelectSingleNode('//siq:sharedControls', $ns)

    $idsToEnsure = 'siq:12301','siq:12303'
    $areModificationsRequired = $false

    foreach ($id in $idsToEnsure) {
        $node = $xml.SelectSingleNode("//siq:control[@idQ='$id']", $ns)
        if (-not $node) {
            $new = $xml.CreateElement('siq','control',$ns.LookupNamespace('siq'))
            $new.SetAttribute('idQ', $id)
            $new.SetAttribute('visible','true')
            $new.SetAttribute('argument','0')
            $shared.AppendChild($new) | Out-Null
            $areModificationsRequired = $true
        }
    }
    if ($areModificationsRequired) {
        $raw = [Text.Encoding]::UTF8.GetBytes($xml.OuterXml)
    }
    #Use applyRegEdits even if no modifications are required, so that the value is also applied to the default user
    applyRegEdits "Add Powershell to Explorer Quick Access ribbon" @(
        @("SetProperty", $path, $valueName, $raw)
    )
}
setExplorerQuickAccessRibbon

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

    #Not applied to the default user, as AppData\Local\Packages is created when the apps are installed for a new user, and pre-creating it may break that
    $writeFileContent = '{
        "$help": "https://aka.ms/terminal-documentation",
        "$schema": "https://aka.ms/terminal-profiles-schema",
        "actions": [],
        "alwaysOnTop": false,
        "alwaysShowTabs": false,
        "copyFormatting": "none",
        "copyOnSelect": false,
        "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
        "initialRows": 34,
        "keybindings": [{
            "id": "Terminal.CopyToClipboard",
            "keys": "ctrl+c"
        },{
            "id": "Terminal.PasteFromClipboard",
            "keys": "ctrl+v"
        },{
            "id": "Terminal.DuplicatePaneAuto",
            "keys": "alt+shift+d"
        }],
        "newTabMenu": [{
            "type": "remainingProfiles"
        }],
        "newTabPosition": "afterCurrentTab",
        "profiles": {
            "defaults": {
                "antialiasingMode": "cleartype",
                "bellSound": ["C:\\Windows\\Media\\Windows Default.wav"],
                "colorScheme": "zez.dev",
                "font": {
                    "cellHeight": "1.1",
                    "face": "Consolas",
                    "size": 11,
                    "weight": "normal"
                },
                "opacity": 100,
                "padding": "2",
                "useAcrylic": false
            },
            "list": [{
                "commandline": "%SystemRoot%\\System32\\cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "hidden": false,
                "name": "Invite de commandes"
            },{
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": false,
                "name": "Windows PowerShell"
            },{
                "altGrAliasing": true,
                "closeOnExit": "automatic",
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "cursorShape": "bar",
                "elevate": true,
                "guid": "{819393ca-c8de-443c-95c0-f50b6ceb0fe4}",
                "hidden": false,
                "historySize": 9001,
                "icon": "ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png",
                "name": "Windows PowerShell (Admin)",
                "snapOnInput": true,
                "startingDirectory": "%USERPROFILE%"
            }]
        },
        "schemes": [{
            "name": "zez.dev",

            "background": "#181818",
            "cursorColor": "#D7D7D7",
            "foreground": "#D7D7D7",
            "selectionBackground": "#D7D7D7",

            "black": "#181818",
            "blue": "#4989E2",
            "green": "#40C73D",
            "cyan": "#11A8CD",
            "red": "#CD3131",
            "purple": "#CA5ACA",
            "yellow": "#E5E510",
            "white": "#D7D7D7",
            "brightBlack": "#969696",
            "brightBlue": "#4A98F5",
            "brightGreen": "#46CE46",
            "brightCyan": "#29B8DB",
            "brightRed": "#F14C4C",
            "brightPurple": "#D670D6",
            "brightYellow": "#F5F543",
            "brightWhite": "#F2F2F2"
        }],
        "showTabsInTitlebar": false,
        "tabWidthMode": "titleLength",
        "themes": [],
        "useAcrylicInTabRow": false,
        "warning.confirmCloseAllTabs": false
    }
'
    $writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
    $writeFileDest = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793187781).UtcDateTime) {
        Write-Host "Already applied Windows Terminal settings" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Applied Windows Terminal settings"
    }
}

#Remove the app execution aliases that shadow the programs in the PATH: python.exe and python3.exe open the Microsoft Store, bash.exe launches WSL
foreach ($appAlias in @("bash.exe", "python.exe", "python3.exe")) {
    $appAliasPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\$appAlias"
    #The aliases are reparse points, use .NET as PowerShell may try to follow them
    if ([IO.File]::Exists($appAliasPath)) {
        [IO.File]::Delete($appAliasPath)
        echo "Removed $appAlias app execution alias"
    } else {
        Write-Host "Already removed $appAlias app execution alias" -ForegroundColor DarkGray
    }
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

applyRegEdits "Fix console colors for Python" @(
    @("SetProperty", "HKCU:/Console", "VirtualTerminalLevel", 1)
)

function hexToRgb {
    param ([string]$hex)
    if ($hex -notmatch '^#[0-9A-Fa-f]{6}$') {throw "Invalid hex color '$hex'"}
    return [byte[]]@(
        [Convert]::ToByte($hex.Substring(1, 2), 16),
        [Convert]::ToByte($hex.Substring(3, 2), 16),
        [Convert]::ToByte($hex.Substring(5, 2), 16)
    )
}

# In the registry, those values are stored in little endian
function hexToAABBGGRR {
    param ([string]$hex)
    $rgb = hexToRgb $hex
    return '00{0:X2}{1:X2}{2:X2}' -f $rgb[2], $rgb[1], $rgb[0]
}

$consoleWidth = 120
$consoleHeight = 34

$colors = @(
    "#181818", "#4989E2", "#40C73D", "#11A8CD", "#CD3131", "#CA5ACA", "#E5E510", "#D7D7D7", 
    "#969696", "#4A98F5", "#46CE46", "#29B8DB", "#F14C4C", "#D670D6", "#F5F543", "#F2F2F2"
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
        $user = "SYSTEM "
    } else {
        $user = ""
    }
    $modifications = @()
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $colorValue = hexToAABBGGRR $colors[$i]
        $colorValue = + "0x$colorValue"
        $regKey = "ColorTable{0:d2}" -f $i
        $modifications += ,@("SetProperty", $regPath, $regKey, $colorValue)
    }
    applyRegEdits "Set $user$cmdType colors" $modifications

    applyRegEdits "Set $user$cmdType additional properties" @(
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
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $offset = $colorOffset + ($i * 4) + 1 # +1 for the first byte which is always 0
        hexToRgb $colors[$i] | ForEach-Object { $shortcutContent[$offset++] = $_ }
    }
    if ($sizeOffset) {
        $shortcutContent[$sizeOffset] = $consoleWidth
        $shortcutContent[$sizeOffset + 4] = $consoleWidth
        $shortcutContent[$sizeOffset + 6] = $consoleHeight
    }
    
    $targets = @(,@($shortcutPath, ""))
    if ($applyToDefaultUser) {
        $targets += ,@($shortcutPath.Replace($env:APPDATA, "$defaultUserProfile\AppData\Roaming"), " for default user")
    }
    foreach ($target in $targets) {
        $targetPath, $titleSuffix = $target
        if (-not (Test-Path -LiteralPath $targetPath)) {
            New-Item -Path $targetPath -ItemType File -Force | Out-Null
        }
        $existingContent = Get-Content -LiteralPath $targetPath -Encoding Byte
        if (@(Compare-Object $existingContent $shortcutContent -SyncWindow 0).Length -eq 0) {
            Write-Host "Already patched $shortcutDesc shortcut$titleSuffix" -ForegroundColor DarkGray
            continue
        }

        Set-Content -LiteralPath $targetPath -Value $shortcutContent -Encoding Byte
        echo "Patched $shortcutDesc shortcut$titleSuffix"
    }
}

patchShortcut "powershell" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" "TAAAAAEUAgAAAAAAwAAAAAAAAEbfAgAAIAAAAJuvlrfNas0Bm6+Wt81qzQGAHQKo3WrNAQDwBgAAAAAAAQAAAAAAAAAAAAAAAAAAAPEBFAAfUOBP0CDqOmkQotgIACswMJ0ZAC9DOlwAAAAAAAAAAAAAAAAAAAAAAAAAUgAxAAAAAADHQgKwMABXaW5kb3dzADwACAAEAO+++kDALMdCArAqAAAAHxAAAAAAAQAAAAAAAAAAAAAAAAAAAFcAaQBuAGQAbwB3AHMAAAAWAFYAMQAAAAAAx0JdBTAAU3lzdGVtMzIAAD4ACAAEAO+++kDBLMdCXQUqAAAAChgAAAAAAQAAAAAAAAAAAAAAAAAAAFMAeQBzAHQAZQBtADMAMgAAABgAaAAxAAAAAAD6QKBBEABXSU5ET1d+MQAAUAAIAAQA7776QKBB+kCgQSoAAACHHQAAAAABAAAAAAAAAAAAAAAAAAAAVwBpAG4AZABvAHcAcwBQAG8AdwBlAHIAUwBoAGUAbABsAAAAGABKADEAAAAAALhC660UAHYxLjAAADYACAAEAO+++kCgQbhC660qAAAAiB0AAAAAAQAAAAAAAAAAAAAAAAAAAHYAMQAuADAAAAAUAGgAMgAA8AYA+kCaGiAAcG93ZXJzaGVsbC5leGUAAEoACAAEAO+++kBXC/pAVwsqAAAA//kAAAAAAQAAAAAAAAAAAAAAAAAAAHAAbwB3AGUAcgBzAGgAZQBsAGwALgBlAHgAZQAAAB4AAABuAAAAHAAAAAEAAAAcAAAAMwAAAAAAAABtAAAAFwAAAAMAAABzLe50EAAAAE9TRGlzawBDOlxXaW5kb3dzXFN5c3RlbTMyXFdpbmRvd3NQb3dlclNoZWxsXHYxLjBccG93ZXJzaGVsbC5leGUAAC4AUABlAHIAZgBvAHIAbQBzACAAbwBiAGoAZQBjAHQALQBiAGEAcwBlAGQAIAAoAGMAbwBtAG0AYQBuAGQALQBsAGkAbgBlACkAIABmAHUAbgBjAHQAaQBvAG4AcwBRAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAC4ALgBcAFcAaQBuAGQAbwB3AHMAXABTAHkAcwB0AGUAbQAzADIAXABXAGkAbgBkAG8AdwBzAFAAbwB3AGUAcgBTAGgAZQBsAGwAXAB2ADEALgAwAFwAcABvAHcAZQByAHMAaABlAGwAbAAuAGUAeABlABUAJQBIAE8ATQBFAEQAUgBJAFYARQAlACUASABPAE0ARQBQAEEAVABIACUAOwAlAFMAeQBzAHQAZQBtAFIAbwBvAHQAJQBcAHMAeQBzAHQAZQBtADMAMgBcAFcAaQBuAGQAbwB3AHMAUABvAHcAZQByAFMAaABlAGwAbABcAHYAMQAuADAAXABwAG8AdwBlAHIAcwBoAGUAbABsAC4AZQB4AGUAFAMAAAEAAKAlU3lzdGVtUm9vdCVcc3lzdGVtMzJcV2luZG93c1Bvd2VyU2hlbGxcdjEuMFxwb3dlcnNoZWxsLmV4ZQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACUAUwB5AHMAdABlAG0AUgBvAG8AdAAlAFwAcwB5AHMAdABlAG0AMwAyAFwAVwBpAG4AZABvAHcAcwBQAG8AdwBlAHIAUwBoAGUAbABsAFwAdgAxAC4AMABcAHAAbwB3AGUAcgBzAGgAZQBsAGwALgBlAHgAZQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAABQAAoCUAAADVAAAAHAAAAAsAAKB3TsEa5wJdTrdELrGuUZi31QAAAGAAAAADAACgWAAAAAAAAABsZWVob2xtMTYAAAAAAAAAmpqyu7ZVLUqI6zLq13xnQNkHI1xpM+IRvnAAHMQt9AuamrK7tlUtSojrMurXfGdA2QcjXGkz4hG+cAAcxC30C8wAAAACAACgBwDzAHgAuAt4ADIAgAJ/AAAAAAAAAAAACAAQADYAAACQAQAAQwBvAG4AcwBvAGwAYQBzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkAAAAAAAAAAQAAAAEAAAABAAAA5wMAAAQAAAABAAAABAUGAAAAgAAAgAAAAICAAIAAAAABJFYA7u3wAMDAwACAgIAAAAD/AAD8AAAA//8AyQAAAAAAAAD//wAA//79ADABAAAJAACgkQAAADFTUFPiilhGvEw4Q7v8E5MmmG3OdQAAAAQAAAAAHwAAADIAAABTAC0AMQAtADUALQAyADEALQAyADcAMgA3ADUAMgAxADEAOAA0AC0AMQA2ADAANAAwADEAMgA3ADIAMAAtADEAOAA4ADcAOQAyADcANQAyADcALQAxADEAOAAwADYANAAzAAAAAAAAAJMAAAAxU1BTBwZXDJYD3kOdYeMh199QJhEAAAADAAAAAAsAAAD//wAAEQAAAAEAAAAACwAAAP//AAARAAAAAgAAAAALAAAA//8AABEAAAAEAAAAAAsAAAAAAAAAEQAAAAYAAAAAAgAAAP8AAAARAAAABQAAAAALAAAA//8AABEAAAAKAAAAAAsAAAAAAAAAAAAAAAAAAAAAAAAA" 0x87E 0x7FF

patchShortcut "powershell x86" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell (x86).lnk" "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" 0x87E 0x7FF

patchShortcut "cmd" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk" "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" 0x49F

#Shortcut to the startup folder in the home folder. A shortcut to the folder itself would contain its absolute path, whereas explorer.exe shell:startup opens the startup folder of the user, so the shortcut also works when copied from the default user profile
$startupShortcutTargets = @(,@("$env:USERPROFILE\Startup.lnk", ""))
if ($applyToDefaultUser) {
    $startupShortcutTargets += ,@("$defaultUserProfile\Startup.lnk", " for default user")
}
$wshShell = New-Object -ComObject WScript.Shell
foreach ($target in $startupShortcutTargets) {
    $shortcutPath, $msgSuffix = $target
    #Loads the shortcut if it exists
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    if ($shortcut.TargetPath -eq "$env:SystemRoot\explorer.exe" -and $shortcut.Arguments -eq "shell:startup") {
        Write-Host "Already added startup folder shortcut$msgSuffix" -ForegroundColor DarkGray
        continue
    }
    $shortcut.TargetPath = "$env:SystemRoot\explorer.exe"
    $shortcut.Arguments = "shell:startup"
    $shortcut.Save()
    echo "Added startup folder shortcut$msgSuffix"
}


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


$writeFileContent = '# irm zez.dev | iex

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
    #Unlike $env:hostname, the hostname command returns the dns name (which isn''t all uppercase)
    $currentHost = $(hostname)
    #Remove redundant domain name from user
    $currentUser = $currentUser -replace [regex]::Escape("$currentHost\".toUpper()), ''''
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    $isInSsh = Test-Path env:SSH_CONNECTION
    #Disable admin indicator in ssh sessions, as it seems windows puts admin by default
    $adminPrompt = if ($currentSid -eq "S-1-5-18") { "[SYSTEM] " } elseif ($isAdmin -and -not $isInSsh) { "[Admin] " } else { "" }
    $sshPrompt = "$currentUser@$currentHost"
    $currentPath = (Get-Location).Path

    #feels too weird
    #$currentPath = $currentPath -replace [regex]::Escape($env:USERPROFILE), ''~''

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
    $host.UI.RawUI.WindowTitle = "$adminPrompt$currentPath$(if ($gitBranch) { " ($gitBranch)" } else { '''' }) - Powershell"
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
'
$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
$writeFileDest = "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793112594).UtcDateTime) {
    Write-Host "Already set PowerShell profile" -ForegroundColor DarkGray
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Set PowerShell profile"
}
if ($applyToDefaultUser) {
    $writeFileDest = "$defaultUserProfile\Documents\WindowsPowerShell\profile.ps1"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793112594).UtcDateTime) {
        Write-Host "Already set PowerShell profile for default user" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set PowerShell profile for default user"
    }
}
$writeFileContent = '# irm zez.dev | iex

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
    #Unlike $env:hostname, the hostname command returns the dns name (which isn''t all uppercase)
    $currentHost = $(hostname)
    #Remove redundant domain name from user
    $currentUser = $currentUser -replace [regex]::Escape("$currentHost\".toUpper()), ''''
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    $isInSsh = Test-Path env:SSH_CONNECTION
    #Disable admin indicator in ssh sessions, as it seems windows puts admin by default
    $adminPrompt = if ($currentSid -eq "S-1-5-18") { "[SYSTEM] " } elseif ($isAdmin -and -not $isInSsh) { "[Admin] " } else { "" }
    $sshPrompt = "$currentUser@$currentHost"
    $currentPath = (Get-Location).Path

    #feels too weird
    #$currentPath = $currentPath -replace [regex]::Escape($env:USERPROFILE), ''~''

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
    $host.UI.RawUI.WindowTitle = "$adminPrompt$currentPath$(if ($gitBranch) { " ($gitBranch)" } else { '''' }) - Powershell"
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
'
$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
$writeFileDest = "C:\WINDOWS\system32\config\systemprofile\Documents\WindowsPowerShell\profile.ps1"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793112594).UtcDateTime) {
    Write-Host "Already set SYSTEM PowerShell profile" -ForegroundColor DarkGray
} elseif (-not $isAdmin) {
    Write-Host "Cannot set SYSTEM PowerShell profile, needs admin rights" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Set SYSTEM PowerShell profile"
}

#profile.ps1 is loaded by all hosts, Microsoft.PowerShell_profile.ps1 only by the console (after profile.ps1), so an old copy would override the prompt
$consoleProfilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path -LiteralPath $consoleProfilePath) {
    Remove-Item -LiteralPath $consoleProfilePath
    echo "Removed Microsoft.PowerShell_profile.ps1"
}
$consoleProfilePath = "C:\WINDOWS\system32\config\systemprofile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (-not $isAdmin) {
    Write-Host "Cannot remove SYSTEM Microsoft.PowerShell_profile.ps1, needs admin rights" -ForegroundColor Yellow
} elseif (Test-Path -LiteralPath $consoleProfilePath) {
    Remove-Item -LiteralPath $consoleProfilePath
    echo "Removed SYSTEM Microsoft.PowerShell_profile.ps1"
}


$writeFileContent = '#!/bin/bash
# .bashrc version 2026-10-29
# curl zez.dev -Lo .bashrc
# wget zez.dev -O .bashrc

# If not running interactively, don''t do anything
[[ $- == *i* ]] || return 0


HISTCONTROL=ignoreboth # don''t put duplicate lines or lines starting with space in the history
shopt -s histappend # append to the history file, don''t overwrite it
#[[ $PROMPT_COMMAND == *"history -a"* ]] || PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" # write each command to the history file once it finishes, instead of on exit, so that it is not lost if the terminal is killed - disabled for now for testing

HISTSIZE=1000
HISTFILESIZE=2000

shopt -s checkwinsize # check the window size after each command and, if necessary, update the values of LINES and COLUMNS.
shopt -s globstar #allow ** in glob
shopt -s extglob #allow extended glob matching such as ?(pattern), *(pattern), etc
shopt -s dotglob #allow globbing to match hidden files (files starting with a dot)
set +H #disable "!" expanding to history

#Avoid .* matching . and ..
GLOBIGNORE=".:.."

#disable as it causes problems with scp autocompletion
#shopt -s failglob #if doing ls *nomatch*, it will cause an error instead of passing "*nomatch*" to ls

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls=''ls --color=auto''
    alias dir=''dir --color=auto''
    alias vdir=''vdir --color=auto''

    alias grep=''grep --color=auto''
    alias fgrep=''fgrep --color=auto''
    alias egrep=''egrep --color=auto''
fi

# colored GCC warnings and errors
export GCC_COLORS=''error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01''

alias ll=''ls -laF''

#Same as gacp in profile.ps1
if command -v git >/dev/null; then
    gacp() { git add -A && git commit --allow-empty-message -m "$1" && git push; }
fi

[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases


# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

prompt_get_git_branch() {
    title=$1
    _PROMPT_CURRENT_GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ $_PROMPT_CURRENT_GIT_BRANCH == "HEAD" ]]; then
    #If checking out a specific commit, we need to use --short
        _PROMPT_CURRENT_GIT_BRANCH=$(git rev-parse --short HEAD 2>/dev/null)
    fi
    if [[ ! -z $_PROMPT_CURRENT_GIT_BRANCH && $_PROMPT_CURRENT_GIT_BRANCH != "main" && $_PROMPT_CURRENT_GIT_BRANCH != "master" ]]; then
        if [[ $title == "true" ]]; then
            _PROMPT_CURRENT_GIT_BRANCH="($_PROMPT_CURRENT_GIT_BRANCH)"
        fi
        _PROMPT_CURRENT_GIT_BRANCH=" $_PROMPT_CURRENT_GIT_BRANCH"
    else
        _PROMPT_CURRENT_GIT_BRANCH=""
    fi
    echo "$_PROMPT_CURRENT_GIT_BRANCH"
}

prompt_get_mingw64() {
    title=$1
    if [[ "$MSYSTEM" == "MINGW64" ]]; then
        if [[ $title == "true" ]]; then
            echo " - MINGW64"
        elif [[ -z "$SSH_CONNECTION" ]]; then
            echo "MINGW64"
        else
            echo " MINGW64"
        fi
    else
        echo ""
    fi
}

prompt_display_user_hostname() {
    # Display user@hostname, unless we are in mingw64 (git bash) and not in ssh
    if [[ "$MSYSTEM" == "MINGW64" && -z "$SSH_CONNECTION" ]]; then
        return 1
    else
        return 0
    fi
}

PROMPT_HOSTNAME=${PROMPT_HOSTNAME:-$HOSTNAME}

if [[ $MSYSTEM == "MINGW64" ]]; then
    PS1=''${debian_chroot:+($debian_chroot)}\[\033[01;35m\]$(prompt_display_user_hostname && echo "\u@$PROMPT_HOSTNAME " || echo '''')\[\033[0m\033[92m\]MINGW64\[\033[0m\] \[\033[01;34m\]\w\[\033[01;36m\]$(prompt_get_git_branch)\[\033[00m\]> ''
else

    PS1=''${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@$PROMPT_HOSTNAME\[\033[0m\]:\[\033[01;34m\]\w\[\033[01;35m\]$(prompt_get_git_branch)\[\033[00m\]\$ ''
fi

# If this is an xterm set the title to user@host: dir <branch>
[[ $TERM == xterm* || $TERM == rxvt* ]] && PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\$(prompt_display_user_hostname && echo ''\u@$PROMPT_HOSTNAME: '' || echo '''')\w\$(prompt_get_git_branch true)\$(prompt_get_mingw64 true)\a\]$PS1"


# enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

export PYTHONDONTWRITEBYTECODE=1

#Automatically display column names in sqlite cli and add color to prompt
#Unfortunately max sqlite prompt length is 18 chars (including escape chars) so we can only have 5 chars max displayed
if command -v ''sqlite3'' >/dev/null && [[ ! -f "$HOME/.sqliterc" || $(stat -c %Y "$HOME/.sqliterc") -lt 1793083095 ]]; then
    mkdir -p "$(dirname "$HOME/.sqliterc")"
    printf ''%s'' $''--Note: this is automatically generated and overwritten by .bashrc
.headers ON
.mode columns
.nullvalue <NULL>
.prompt "\x01\x1b[92m\x02sql\x01\x1b[0m\x02> " "\x01\x1b[36m\x02...\x01\x1b[0m\x02> "
'' > "$HOME/.sqliterc"
    echo ''[.bashrc] Added .sqliterc''
fi

#Add color to mysql prompt: "mysql user:database> "
#\001 and \002 delimit non-printing characters, so that readline/editline computes the prompt length correctly
export MYSQL_PS1=$''\001\e[01;35m\002mysql\001\e[0m\002 \001\e[01;32m\002\\u\001\e[0m\002:\001\e[01;34m\002\\d\001\e[0m\002> ''

#Add color to mongodb prompt. Disabled as I don''t use mongodb cli
#cat << EOF > ~/.mongorc.js
#//Note: this is automatically generated and overwritten by .bashrc
#prompt = () => "\u001b[92m"+db.getName()+"\u001b[0m>";
#EOF

if [[ ! -f "$HOME/.vimrc" || $(stat -c %Y "$HOME/.vimrc") -lt 1793084032 ]]; then
    mkdir -p "$(dirname "$HOME/.vimrc")"
    printf ''%s'' $''"Note: this is automatically generated and overwritten by .bashrc

" Reopen the last edited position in files
au BufReadPost * if line("\''\\"") > 1 && line("\''\\"") <= line("$") | exe "normal! g\''\\"" | endif
"Syntax coloration
syntax on
"Load plugins based on file type
filetype on
"Display line numbers. Todo: too distracting.
"set number
"Inserts spaces when pressing the tab key
set expandtab
"Set tab width to 4 spaces
set tabstop=4
set softtabstop=4
set shiftwidth=4

"Do not continue comment when pressing Enter
autocmd FileType * set formatoptions-=cro

"Disable autoindent, as it messes up pasting
filetype indent off
set noautoindent
set nocindent
set nosmartindent
set indentexpr&

"Highlight matching brackets
set showmatch

"Case insensitive matching in search
set ignorecase
set smartcase
"Highlight search matches
set hlsearch

"Allow selecting with the mouse
set mouse=a

"The following is normally in debian.vim but it does not get sourced if vimrc exists

set nocompatible	" Use Vim defaults instead of 100% vi compatibility
set backspace=indent,eol,start	" more powerful backspacing
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set nomodeline
" Suffixes that get lower priority when doing tab completion for filenames.
" These are files we are not likely to want to edit or read.
set suffixes=.bak,~,.swp,.o,.info,.aux,.log,.dvi,.bbl,.blg,.brf,.cb,.ind,.idx,.ilg,.inx,.out,.toc

" We know xterm-debian is a color terminal
if &term =~ "xterm-debian" || &term =~ "xterm-xfree86"
  set t_Co=16
  set t_Sf=\x1b[3%dm
  set t_Sb=\x1b[4%dm
endif

" Some Debian-specific things
if has(\''gui\'')
  " Must define this within the :if so it does not cause problems with
  " vim-tiny (which does not have +eval)
  function! <SID>MapExists(name, modes)
    for mode in split(a:modes, \''\\zs\'')
      if !empty(maparg(a:name, mode))
        return 1
      endif
    endfor
    return 0
  endfunction

  " Make shift-insert work like in Xterm
  autocmd GUIEnter * if !<SID>MapExists("<S-Insert>", "nvso") | execute "map <S-Insert> <MiddleMouse>" | endif
  autocmd GUIEnter * if !<SID>MapExists("<S-Insert>", "ic") | execute "map! <S-Insert> <MiddleMouse>" | endif
endif

" Set paper size from /etc/papersize if available (Debian-specific)
if filereadable("/etc/papersize")
  let s:papersize = matchstr(readfile(\''/etc/papersize\'', \''\'', 1), \''\\p*\'')
  if strlen(s:papersize)
    exe "set printoptions+=paper:" . s:papersize
  endif
endif
'' > "$HOME/.vimrc"
    echo ''[.bashrc] Added .vimrc''
fi

#Mitigate supply chain attacks: don''t install package versions released less than 52 days ago (most malicious versions are detected and removed by then), and don''t run install scripts
if [[ -z $MSYSTEM ]]; then
    #If the config file already exists, use the program to edit it, keeping the other settings (eg auth tokens)
    #The global npm config is usually only writable by root. For pnpm, --location=global is the config of the current user
    if command -v ''npm'' >/dev/null && [[ ! -f "$HOME/.npmrc" || $(stat -c %Y "$HOME/.npmrc") -lt 1793199795 ]]; then
        if [[ -f "$HOME/.npmrc" ]]; then
            { npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=user; } && { [[ $EUID -ne 0 ]] || npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=global; } && echo ''[.bashrc] Set npm security settings''
        else
            mkdir -p "$(dirname "$HOME/.npmrc")"
            printf ''%s'' ''# Don''\''''t install package versions released less than 52 days ago. Needs npm 11.10+, older versions display a warning
min-release-age=52
ignore-scripts=true
# Git dependencies bypass the registry, so min-release-age does not apply to them. Default in npm 12
allow-git=none
'' > "$HOME/.npmrc"
            echo ''[.bashrc] Set npm security settings''
        fi
    fi
    #pnpm 11+ reads its settings from config.yaml instead of rc. If config.yaml does not exist, pnpm 10 is presumably installed, so set the settings in rc with the commands
    #config.yaml is still written, so that the commands are not run again and pnpm is configured once upgraded
    if command -v pnpm >/dev/null; then
        if [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml" || $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml") -lt 1793199796 ]]; then
            if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml" ]]; then
                { pnpm config set minimumReleaseAge 74880 --location=global; } && { pnpm config set ignoreScripts true --location=global; } && { pnpm config set trustPolicy no-downgrade --location=global; } && echo ''[.bashrc] Set pnpm security settings''
            else
                if { pnpm config set minimum-release-age 74880 --location=global; } && { pnpm config set trust-policy no-downgrade --location=global; } && { pnpm config set block-exotic-subdeps true --location=global; }; then
                    mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml")"
                    printf ''%s'' ''# Don''\''''t install package versions released less than 52 days ago (in minutes)
minimumReleaseAge: 74880
ignoreScripts: true
# Fail if a package version is published with less trust evidence (eg without provenance) than the previous versions, which is typical of stolen tokens
trustPolicy: no-downgrade
'' > "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/config.yaml"
                    echo ''[.bashrc] Set pnpm security settings''
                fi
            fi
        fi
    fi
    if command -v ''uv'' >/dev/null && [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml" || $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml") -lt 1793199799 ]]; then
        mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml")"
        printf ''%s'' ''# Don''\''''t install package versions released less than 52 days ago. Needs uv 0.9.17+, older versions fail to parse the duration
exclude-newer = "52 days"
# Building source distributions runs arbitrary code. Use --no-config to install a package that has no wheels
no-build = true
'' > "${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml"
        echo ''[.bashrc] Set uv security settings''
    fi
    if command -v ''bun'' >/dev/null && [[ ! -f "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml" || $(stat -c %Y "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml") -lt 1793199804 ]]; then
        mkdir -p "$(dirname "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml")"
        printf ''%s'' ''[install]
# Don''\''''t install package versions released less than 52 days ago (in seconds)
minimumReleaseAge = 4492800
ignoreScripts = true
'' > "${XDG_CONFIG_HOME:-$HOME}/.bunfig.toml"
        echo ''[.bashrc] Set bun security settings''
    fi
fi
'
$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
$writeFileDest = "$env:USERPROFILE\.bashrc"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793291033).UtcDateTime) {
    Write-Host "Already set .bashrc" -ForegroundColor DarkGray
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Set .bashrc"
}
if ($applyToDefaultUser) {
    $writeFileDest = "$defaultUserProfile\.bashrc"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793291033).UtcDateTime) {
        Write-Host "Already set .bashrc for default user" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set .bashrc for default user"
    }
}

$bashProfileContent = @'
test -f ~/.profile && . ~/.profile
test -f ~/.bashrc && . ~/.bashrc
'@
if (-not (Test-Path "$env:USERPROFILE\.bash_profile")) {
    echo "Creating .bash_profile to source .bashrc and .profile"
    [IO.File]::WriteAllText("$env:USERPROFILE\.bash_profile", $bashProfileContent)
}
if ($applyToDefaultUser -and -not (Test-Path "$defaultUserProfile\.bash_profile")) {
    echo "Creating .bash_profile to source .bashrc and .profile for default user"
    [IO.File]::WriteAllText("$defaultUserProfile\.bash_profile", $bashProfileContent)
}

#Make "#!/usr/bin/env python3" shebangs work in git bash. A bash alias would not apply to shebangs, so it has to be a script in /usr/bin
if (Test-Path -LiteralPath "$env:ProgramFiles\Git\usr\bin") {
    $writeFileContent = '#!/bin/sh
# python3 alias for git bash, as Python on Windows only provides python.exe
exec python "$@"
'
    $writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
    $writeFileDest = "$env:ProgramFiles\Git\usr\bin\python3"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793103179).UtcDateTime) {
        Write-Host "Already added python3 alias to git bash" -ForegroundColor DarkGray
    } elseif (-not $isAdmin) {
        Write-Host "Cannot add python3 alias to git bash, needs admin rights" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Added python3 alias to git bash"
    }
}

#Mitigate supply chain attacks: don't install package versions released less than 52 days ago (most malicious versions are detected and removed by then), and don't run install scripts
#If the config file already exists, npm or pnpm is presumably installed, so use it to edit the config, keeping the other settings (eg auth tokens)
#For pnpm, --location=global is the config of the current user
$writeFileContent = '# Don''t install package versions released less than 52 days ago. Needs npm 11.10+, older versions display a warning
min-release-age=52
ignore-scripts=true
# Git dependencies bypass the registry, so min-release-age does not apply to them. Default in npm 12
allow-git=none
'
$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
$writeFileDest = "$env:USERPROFILE\.npmrc"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199795).UtcDateTime) {
    Write-Host "Already set npm security settings" -ForegroundColor DarkGray
} elseif ([IO.File]::Exists($writeFileDest)) {
    npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=user
    if ($LASTEXITCODE -ne 0) {throw 'Failed to run: npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=user'}
    npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=global
    if ($LASTEXITCODE -ne 0) {throw 'Failed to run: npm config set min-release-age=52 ignore-scripts=true allow-git=none --location=global'}
    echo "Set npm security settings"
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Set npm security settings"
}
if ($applyToDefaultUser) {
    $writeFileDest = "$defaultUserProfile\.npmrc"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199795).UtcDateTime) {
        Write-Host "Already set npm security settings for default user" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set npm security settings for default user"
    }
}
#pnpm 11+ reads its settings from config.yaml instead of rc. If config.yaml does not exist, pnpm 10 is presumably installed, so set the settings in rc with the commands
#config.yaml is still written, so that the commands are not run again and pnpm is configured once upgraded
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    $writeFileContent = '# Don''t install package versions released less than 52 days ago (in minutes)
minimumReleaseAge: 74880
ignoreScripts: true
# Fail if a package version is published with less trust evidence (eg without provenance) than the previous versions, which is typical of stolen tokens
trustPolicy: no-downgrade
'
    $writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
    $writeFileDest = "$env:LOCALAPPDATA\pnpm\config\config.yaml"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199796).UtcDateTime) {
        Write-Host "Already set pnpm security settings" -ForegroundColor DarkGray
    } elseif ([IO.File]::Exists($writeFileDest)) {
        pnpm config set minimumReleaseAge 74880 --location=global
        if ($LASTEXITCODE -ne 0) {throw 'Failed to run: pnpm config set minimumReleaseAge 74880 --location=global'}
        pnpm config set ignoreScripts true --location=global
        if ($LASTEXITCODE -ne 0) {throw 'Failed to run: pnpm config set ignoreScripts true --location=global'}
        pnpm config set trustPolicy no-downgrade --location=global
        if ($LASTEXITCODE -ne 0) {throw 'Failed to run: pnpm config set trustPolicy no-downgrade --location=global'}
        echo "Set pnpm security settings"
    } else {
        pnpm config set minimum-release-age 74880 --location=global
        if ($LASTEXITCODE -ne 0) {throw 'Failed to run: pnpm config set minimum-release-age 74880 --location=global'}
        pnpm config set trust-policy no-downgrade --location=global
        if ($LASTEXITCODE -ne 0) {throw 'Failed to run: pnpm config set trust-policy no-downgrade --location=global'}
        pnpm config set block-exotic-subdeps true --location=global
        if ($LASTEXITCODE -ne 0) {throw 'Failed to run: pnpm config set block-exotic-subdeps true --location=global'}
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set pnpm security settings"
    }
    if ($applyToDefaultUser) {
        $writeFileDest = "$defaultUserProfile\AppData\Local\pnpm\config\config.yaml"
        if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199796).UtcDateTime) {
            Write-Host "Already set pnpm security settings for default user" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
            [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
            echo "Set pnpm security settings for default user"
        }
    }
}
$writeFileContent = '# Don''t install package versions released less than 52 days ago. Needs uv 0.9.17+, older versions fail to parse the duration
exclude-newer = "52 days"
# Building source distributions runs arbitrary code. Use --no-config to install a package that has no wheels
no-build = true
'
$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
$writeFileDest = "$env:APPDATA\uv\uv.toml"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199799).UtcDateTime) {
    Write-Host "Already set uv security settings" -ForegroundColor DarkGray
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Set uv security settings"
}
if ($applyToDefaultUser) {
    $writeFileDest = "$defaultUserProfile\AppData\Roaming\uv\uv.toml"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199799).UtcDateTime) {
        Write-Host "Already set uv security settings for default user" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set uv security settings for default user"
    }
}
$writeFileContent = '[install]
# Don''t install package versions released less than 52 days ago (in seconds)
minimumReleaseAge = 4492800
ignoreScripts = true
'
$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
$writeFileDest = "$env:USERPROFILE\.bunfig.toml"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199804).UtcDateTime) {
    Write-Host "Already set bun security settings" -ForegroundColor DarkGray
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Set bun security settings"
}
if ($applyToDefaultUser) {
    $writeFileDest = "$defaultUserProfile\.bunfig.toml"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793199804).UtcDateTime) {
        Write-Host "Already set bun security settings for default user" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set bun security settings for default user"
    }
}

# Custom French keyboard

$writeFileContent = [Convert]::FromBase64String('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')
$writeFileDest = "$env:SystemRoot\System32\keyboard_fr_improved_zez.dev.dll"
if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1764028165).UtcDateTime) {
    Write-Host "Already installed enhanced French keyboard dll" -ForegroundColor DarkGray
} elseif (-not $isAdmin) {
    Write-Host "Cannot install enhanced French keyboard dll, needs admin rights" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
    echo "Installed enhanced French keyboard dll"
}

$frenchKeyboardId = "0000040c"
applyRegEdits "Set enhanced French keyboard as substitute for standard French keyboard" @(
    @("SetProperty", "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$frenchKeyboardId", "Layout Text", "Fran$([char]0xE7)ais (am$([char]0xE9)lior$([char]0xE9)) - zez.dev", @{signout=$true}),
    @("SetProperty", "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$frenchKeyboardId", "Layout File", "keyboard_fr_improved_zez.dev.dll", @{signout=$true})
)


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
        $writeFileContent = '/* prevent audio playing tabs from modifying tab width */
.tabbrowser-tab {
	&:is([muted], [soundplaying], [activemedia-blocked]) {
		#tabbrowser-tabs[orient="horizontal"] &:not([pinned]) {
			--tab-min-width: unset !important;
			min-width: var(--tab-min-width-pref, var(--tab-min-width)) !important;
		}
	}
}
/* put audio button back above favicon */
#tabbrowser-tabs:is([orient="vertical"][expanded], [orient="horizontal"]) .tabbrowser-tab:not([pinned]):not([crashed]):is([soundplaying], [muted], [activemedia-blocked]) {

	.tab-audio-button {
		--button-size-icon-small: 12px !important;
		--button-min-height-small: 10px !important;
		margin: 0 !important;
		transform: translateY(-9px) translateX(-24px);
		z-index: 9999;
		--icon-size-default: 9px !important;
		width: 3.5px !important;
	}
	
	.tab-audio-button::after {
		width: 11px;
		display: inline-block;
		background-color: rgba(0,0,0,0.6);
		height: 11px;
		content: "";
		position: absolute;
		top: 0;
		left: 0;
		margin-top: 1px;
		z-index: -1;
		border-radius: 4px;
		margin-left: 1px;
	}
}

/* Set constant tab width. Disabled as I like the current behavior */
/*.tabbrowser-tab[fadein]:not([pinned]) { 
	max-width: 140px !important;
	min-width: 140px !important;
}*/

/* Display full tab title in preview */

#tab-preview-panel .tab-preview-title {
	-webkit-line-clamp: none !important;
}

/* Remove useless "Firefox is on guard" when clicking on shield icon*/
#trustpanel-graphic-section { display: none !important; }
'
        $writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
        $writeFileDest = "$firefoxProfilePath\chrome\userChrome.css"
        if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793098667).UtcDateTime) {
            Write-Host "Already set Firefox userChrome.css for profile $firefoxProfileName" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
            [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
            echo "Set Firefox userChrome.css for profile $firefoxProfileName"
        }
        #user.js is read at each startup, so Firefox does not need to be closed
        $writeFileContent = '// Firefox preferences, written to the user.js of each profile (applied at each startup)
// Also written to defaults\pref in the Firefox install folder for new users, with user_pref replaced by pref, which only sets the default value
user_pref("accessibility.browsewithcaret_shortcut.enabled", false); // Disable the F7 caret browsing shortcut
user_pref("accessibility.typeaheadfind.flashBar", 0); // Firefox flashes the find bar the first time it is opened, then sets this to 0
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.compactmode.show", true); // Show the "Compact" density in "Customize toolbar"
user_pref("browser.ipProtection.hasSeenFeature", true);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.pinned", "[]");
user_pref("browser.nova.enabled", false);
user_pref("browser.tabs.insertAfterCurrentExceptPinned", true);
user_pref("browser.tabs.splitview.hasUsed", true);
user_pref("browser.translations.neverTranslateLanguages", "en");
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.trimURLs", false); // Always display http/https in the url
user_pref("devtools.cache.disabled", true);
user_pref("devtools.everOpened", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // Load userChrome.css
user_pref("view_source.wrap_long_lines", true);
user_pref("widget.non-native-theme.scrollbar.style", 4);
user_pref("widget.non-native-theme.win.scrollbar.use-system-size", true);
'
        $writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
        $writeFileDest = "$firefoxProfilePath\user.js"
        if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793248924).UtcDateTime) {
            Write-Host "Already set Firefox preferences for profile $firefoxProfileName" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
            [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
            echo "Set Firefox preferences for profile $firefoxProfileName"
        }
    }
}
#Firefox loads all the files of defaults\pref as default preferences, for all users
if ($applyToDefaultUser -and (Test-Path -LiteralPath $firefoxPath)) {
    $writeFileContent = '// Firefox preferences, written to the user.js of each profile (applied at each startup)
// Also written to defaults\pref in the Firefox install folder for new users, with user_pref replaced by pref, which only sets the default value
pref("accessibility.browsewithcaret_shortcut.enabled", false); // Disable the F7 caret browsing shortcut
pref("accessibility.typeaheadfind.flashBar", 0); // Firefox flashes the find bar the first time it is opened, then sets this to 0
pref("browser.aboutConfig.showWarning", false);
pref("browser.compactmode.show", true); // Show the "Compact" density in "Customize toolbar"
pref("browser.ipProtection.hasSeenFeature", true);
pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
pref("browser.newtabpage.activity-stream.feeds.topsites", false);
pref("browser.newtabpage.activity-stream.showSearch", false);
pref("browser.newtabpage.activity-stream.showSponsored", false);
pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.pinned", "[]");
pref("browser.nova.enabled", false);
pref("browser.tabs.insertAfterCurrentExceptPinned", true);
pref("browser.tabs.splitview.hasUsed", true);
pref("browser.translations.neverTranslateLanguages", "en");
pref("browser.urlbar.suggest.trending", false);
pref("browser.urlbar.trimURLs", false); // Always display http/https in the url
pref("devtools.cache.disabled", true);
pref("devtools.everOpened", true);
pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // Load userChrome.css
pref("view_source.wrap_long_lines", true);
pref("widget.non-native-theme.scrollbar.style", 4);
pref("widget.non-native-theme.win.scrollbar.use-system-size", true);
'
    $writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))
    $writeFileDest = "$env:ProgramFiles\Mozilla Firefox\defaults\pref\zez.dev.js"
    if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds(1793248924).UtcDateTime) {
        Write-Host "Already set Firefox default preferences" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null
        [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)
        echo "Set Firefox default preferences"
    }
}

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

if ($applyToDefaultUser) {unloadDefaultUserHives}

if ($needsSignOut) {
    echo "Done! Please restart your computer or sign out and sign back in to apply all changes."
} elseif ($needsExplorerRestart) {
    echo "Done! Please restart explorer.exe to apply all changes."
} else {
    echo "Done!"
}
