
$InformationPreference = 'Continue'
function Get-AnnouncementChangelog {
    $ReleaseBody = [System.Collections.ArrayList](Get-Content ./RELEASE_NOTE)

    Write-Information "::group::Raw Body`n$ReleaseBody`n::endgroup::`n"

    if (!$ReleaseBody.Contains("## Changelog")) {
        return ""
    }

    $ReleaseBody.RemoveRange(0, $ReleaseBody.IndexOf("## Changelog"))

    # Turn any lines which contains html tags into null
    for ($i = 0; $i -lt $ReleaseBody.Count; $i++) {
        if ($ReleaseBody[$i] -match "<(\w|\/)+>") {
            $ReleaseBody[$i] = $null
        }
    }

    # Remove any space/null lines
    $ReleaseBody = [System.Collections.ArrayList]($ReleaseBody | Where-Object { $_ -and $_.Trim() })

    # Limitation up to 15 lines
    if ($ReleaseBody.Count -ge 15) {
        $ReleaseBody.RemoveRange(15, $ReleaseBody.Count - 15)
        $null = $ReleaseBody.Add("...`r`n*Check detailed changelog at the link below!*`r`n")
    }

    return ($ReleaseBody -join "`r`n")
}

function Get-Footer {
    $LatestTag = $ENV:RELEASE_TAG
    $PreviousTag = $ENV:PREVIOUS_TAG

    $Footer = 
    "`r`n### [Github release](<https://github.com/ImaterialC/PriconneRe-TL/releases/tag/$LatestTag>) " +
    "| [Download](<https://github.com/ImaterialC/PriconneRe-TL/releases/download/$LatestTag/PriconneTL_$LatestTag.zip>) " +
    "| [What's changed?](<https://github.com/ImaterialC/PriconneRe-TL/compare/$PreviousTag...$LatestTag>)"

    return $Footer
}

$Changelog = Get-AnnouncementChangelog
$FooterLink = Get-Footer

$Message = $Changelog + $FooterLink
Write-Information "::group::Final Discord Message`n$Message`n::endgroup::`n"

"discord_changes<<EOF" >> "$env:GITHUB_OUTPUT"
$Message >> "$env:GITHUB_OUTPUT"
"EOF" >> "$env:GITHUB_OUTPUT"