# ============================================================
#  initialize.ps1 — Deterministic Tag & PreviousTag Resolver
#  Uses WIB (UTC+7) date with optional a..z same-day suffixes
# ============================================================
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

# 1. Resolve current date in WIB (SE Asia Standard Time, UTC+7)
try   { $Now = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, 'SE Asia Standard Time') }
catch { $Now = Get-Date }
$Date = $Now.ToString('yyyyMMdd')

# 2. Candidate tags: yyyyMMdd, yyyyMMdda..z (pick first unused tag)
$candidates = @($Date) + @([char[]](97..122) | ForEach-Object { "$Date$_" })
$ReleaseTag = $candidates | Where-Object { -not (git tag -l $_) } | Select-Object -First 1
if (-not $ReleaseTag) {
    throw "More than 27 releases on a single date ($Date) — clean up old tags first."
}

# 3. Deterministic PreviousTag (reachability-first + same-commit tie-break)
$PreviousTag = ''
$desc = @(git describe --tags --abbrev=0 --match "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*" --exclude="$ReleaseTag" HEAD 2>$null)
if ($LASTEXITCODE -eq 0 -and $desc.Count -gt 0 -and $desc[0]) {
    $baseTag = $desc[0].Trim()
    $commit  = (git rev-list -n 1 $baseTag 2>$null | Select-Object -First 1)
    if ($commit) {
        $same = @(git tag --points-at $commit | Where-Object { $_ -match '^\d{8}[a-z]?$' -and $_ -ne $ReleaseTag })
        if ($same.Count -gt 0) {
            $PreviousTag = ($same | Sort-Object -Descending | Select-Object -First 1)
        } else {
            $PreviousTag = $baseTag
        }
    } else {
        $PreviousTag = $baseTag
    }
}

# Fallback when git describe finds nothing (e.g. shallow/unannotated edge case)
if (-not $PreviousTag) {
    $tags = @(git for-each-ref --sort=-refname --sort=-creatordate --format='%(refname:short)' refs/tags)
    $PreviousTag = ($tags | Where-Object { $_ -match '^\d{8}[a-z]?$' -and $_ -ne $ReleaseTag } | Select-Object -First 1)
}

$ReleaseTitle = "Priconne UI EN DMM v$ReleaseTag"

if ($env:GITHUB_ENV) {
    $envPayload = "RELEASE_TAG=$ReleaseTag`nRELEASE_TITLE=$ReleaseTitle`nPREVIOUS_TAG=$PreviousTag`n"
    [System.IO.File]::AppendAllText($env:GITHUB_ENV, $envPayload, [System.Text.UTF8Encoding]::new($false))
}

Write-Output @"
::group::Logs
Tag: $ReleaseTag
Title: $ReleaseTitle
Previous: $PreviousTag
::endgroup::
