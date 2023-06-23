$Changelog = Get-Content -Raw ./RELEASE_NOTE

if ($Changelog -match "## Changelog") {
    $Changelog = $Changelog.Remove(0, $Changelog.IndexOf("## Changelog"))

    $Replacement = @{
        "<summary>"  = "";
        "</summary>`n" = "";
        "`n<details>"  = "";
        "`n</details>`n" = "";
        "Text"       = "";
        "Texture"    = "";
        "Other"      = "";
    }
    ($Replacement.PSOBject.Properties | Where-Object Name -eq "Keys").Value | ForEach-Object {
        $Changelog = $Changelog.Replace($_, $Replacement.$_)
        Write-Output "Replace $_ => $($Replacement.$_)"
    }

    if ($Changelog.Length -ge 300) {
        $Changelog = $Changelog.Substring(0, 300) #.Substring(0, $Changelog.LastIndexOf("`n"))
        $Changelog += "..."
        $Changelog += "`n*Check detailed changelog at the link below!*"
    }
}
else {
    $Changelog = ""
}

$Changelog >> "./DISCORD_NOTE"
