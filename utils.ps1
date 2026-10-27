
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
