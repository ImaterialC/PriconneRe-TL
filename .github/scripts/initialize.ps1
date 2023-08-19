function New-ReleaseTag {
    $Date = Get-Date -Format 'yyyyMMdd'
    $charNumber = 64
    do {
        $char = [char]$charNumber
        if ($charNumber -eq 64) {
            $ReleaseTag = $Date
        }
        else {
            $ReleaseTag = $Date + $char.ToString().ToLower()
        }
        $charNumber++
    }
    while (git tag -l $ReleaseTag)

    return $ReleaseTag
}

$ReleaseTag = New-ReleaseTag
$ReleaseTitle = "Pricone UI EN DMM v$ReleaseTag"
"RELEASE_TAG=$ReleaseTag" >> $Env:GITHUB_ENV
"RELEASE_TITLE=$ReleaseTitle" >> $Env:GITHUB_ENV

Write-Output @"
::group::Logs
Tag: $ReleaseTag
Title: $ReleaseTitle
::endgroup::
"@