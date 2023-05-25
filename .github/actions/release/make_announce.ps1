$Changelog = Get-Content -Raw ./RELEASE_NOTE

if ($Changelog -match "Changelog") {
    $Changelog = $Changelog.Remove(0, $Changelog.IndexOf("Changelog"))

    $Replacement = @{
        "<summary>"  = "";
        "</summary>" = "";
        "<details>"  = "";
        "</details>" = "";
        "Changelog"  = "**Changelog:**";
        "Text"       = "Text:";
        "Texture"    = "Texture:";
        "-"          = "•"
    }
    ($Replacement | ConvertTo-Json | ConvertFrom-Json).PSObject.Properties.Name | ForEach-Object {
        $Changelog = $Changelog.Replace($_, $Replacement.$_)
        Write-Output "Replace $_ => $($Replacement.$_)"
    }

    if ($Changelog.Length -ge 500) {
        $Changelog = $Changelog.Substring(0, 500)
        $Changelog += "..."
        $Changelog += "*Check detailed changelog at the link above!*"
    }
}
else {
    $Changelog = ""
}

$Changelog >> "./DISCORD_NOTE"