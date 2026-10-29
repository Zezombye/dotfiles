
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
