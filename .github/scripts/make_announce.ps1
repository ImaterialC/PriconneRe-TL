$Changelog = [System.Collections.ArrayList](Get-Content ./RELEASE_NOTE)
if ($Changelog.Contains("## Changelog")) {
    $Changelog.RemoveRange(0, $Changelog.IndexOf("## Changelog"))
    for ($i = 0; $i -lt $Changelog.Count; $i++) {
        if ($Changelog[$i] -match "<(\w|\/)+>") {
            $Changelog[$i] = $null
        }
    }
    $Changelog = [System.Collections.ArrayList]($Changelog | Where-Object { $_ -and $_.Trim() })

    if ($Changelog.Count -ge 15) {
        $Changelog.RemoveRange(15, $Changelog.Count - 15)
        $null = $Changelog.Add("...`n*Check detailed changelog at the link below!*")
    }
}
else {
    $Changelog = ""
}
Write-Output "::group::Final Discord Message`n$Changelog`n::endgroup::`n"
Set-Content -Path ./DISCORD_NOTE -Value $Changelog