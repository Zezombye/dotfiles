
function setExplorerQuickAccessRibbon {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon'
    $valueName = 'QatItems'

    $raw = (Get-ItemProperty -Path $path -Name $valueName).$valueName
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
    if (-not $areModificationsRequired) {
        Write-Host "Already added Powershell to Explorer Quick Access ribbon" -ForegroundColor DarkGray
        return
    }

    $updated = $xml.OuterXml
    $bytes = [Text.Encoding]::UTF8.GetBytes($updated)
    Set-ItemProperty -Path $path -Name $valueName -Value $bytes -Type Binary
    echo "Added Powershell to Explorer Quick Access ribbon"
}
setExplorerQuickAccessRibbon
