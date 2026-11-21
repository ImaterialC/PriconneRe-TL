# ============================================================================
# make_announce.ps1 - Deterministic Kokkoro Greeting & Discord Body Builder
# ============================================================================
param(
    [string] $PreviousTag    = $env:PREVIOUS_TAG,
    [string] $ReleaseTag     = $env:RELEASE_TAG,
    [string] $ReleaseTitle   = $env:RELEASE_TITLE,
    [string] $CustomGreeting = $env:CUSTOM_GREETING,
    [string] $RoleMention    = $env:DISCORD_ROLE_MENTION,
    [string] $RepoSlug       = $env:GITHUB_REPOSITORY
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'initialize.ps1')

if ([string]::IsNullOrWhiteSpace($RepoSlug)) {
    $RepoSlug = 'ImaterialC/PriconneRe-TL'
}

$GreetingsData = Get-SafePsd1Data -Path (Join-Path $ScriptDir 'kokkoro_greetings.psd1') -Default @{}
$BirthdaysData = Get-SafePsd1Data -Path (Join-Path $ScriptDir 'character_birthdays.psd1') -Default @{ Birthdays = @() }

$ChangesPath = Join-Path (Get-Location).ProviderPath 'CHANGES.json'
if (-not (Test-Path -LiteralPath $ChangesPath)) {
    throw "CHANGES.json not found at '$ChangesPath'. Run make_changelog.ps1 first."
}
$Data = Get-Content -LiteralPath $ChangesPath -Raw -Encoding utf8 | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($ReleaseTag))  { $ReleaseTag  = [string]$Data.ReleaseTag }
if ([string]::IsNullOrWhiteSpace($PreviousTag)) { $PreviousTag = [string]$Data.PreviousTag }

function Get-DeterministicSeed {
    param([string] $TagText)
    # 32-bit FNV-1a hash using unsigned 64-bit literals (prevents Int32 sign-extension overflow)
    [uint32]$h = 2166136261
    foreach ($ch in $TagText.ToCharArray()) {
        $h = $h -bxor ([uint32][int]$ch)
        $h = [uint32](([uint64]$h * 16777619UL) -band 0xFFFFFFFFUL)
    }
    $signed = [System.BitConverter]::ToInt32([System.BitConverter]::GetBytes($h), 0)
    return $signed
}

function Select-PoolLine {
    param(
        [object[]] $Pool,
        [System.Random] $Rng
    )
    $arr = @($Pool | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($arr.Count -eq 0) { return '' }
    if ($arr.Count -eq 1) { return [string]$arr[0] }
    return [string]$arr[$Rng.Next(0, $arr.Count)]
}

function Resolve-ReleaseDate {
    param([string] $TagText)
    if ($TagText -match '^(\d{4})(\d{2})(\d{2})') {
        try {
            return [DateTime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
        } catch { }
    }
    try {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
        return [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz).Date
    } catch {
        return [DateTime]::UtcNow.AddHours(7).Date
    }
}

function Get-SignedDayDistance {
    param(
        [DateTime] $CurrentDate,
        [int] $TargetMonth,
        [int] $TargetDay
    )
    $bestSigned = $null
    $bestAbs = [int]::MaxValue
    $years = @(($CurrentDate.Year - 1), $CurrentDate.Year, ($CurrentDate.Year + 1))
    foreach ($yr in $years) {
        $daysInMonth = [DateTime]::DaysInMonth($yr, $TargetMonth)
        $safeDay = [Math]::Min($TargetDay, $daysInMonth)
        $target = [DateTime]::new($yr, $TargetMonth, $safeDay)
        # Signed offset: negative = before target (H-N), 0 = target day, positive = after target (H+N)
        $diff = [int]($CurrentDate.Date - $target.Date).TotalDays
        $absDiff = [Math]::Abs($diff)
        if ($absDiff -lt $bestAbs) {
            $bestAbs = $absDiff
            $bestSigned = $diff
        }
    }
    return $bestSigned
}

function Format-BirthdayNames {
    param([object[]] $Entries)
    $formatted = [System.Collections.ArrayList]::new()
    foreach ($e in $Entries) {
        if ($e -is [string]) {
            $n = $e.Trim()
            if ($n -match "'s\b") {
                [void]$formatted.Add($n)
            } else {
                [void]$formatted.Add("$n-sama")
            }
        } elseif ($e -is [System.Collections.IDictionary]) {
            $n = [string]$e['Name']
            if ($e.Contains('Suffix')) {
                $suf = [string]$e['Suffix']
                [void]$formatted.Add("$n$suf")
            } elseif ($n -match "'s\b") {
                [void]$formatted.Add($n)
            } else {
                [void]$formatted.Add("$n-sama")
            }
        }
    }
    $count = $formatted.Count
    if ($count -eq 0) { return '' }
    if ($count -eq 1) {
        return "Incidentally, I heard that today is $($formatted[0])'s birthday. 🎂"
    }
    if ($count -eq 2) {
        return "Incidentally, I heard today marks the birthdays of $($formatted[0]) and $($formatted[1]). 🎂"
    }
    $firstTwo = "$($formatted[0]), $($formatted[1]), and $($count - 2) others"
    return "Incidentally, I heard today marks the birthdays of $firstTwo. 🎂"
}

# ---------------------------------------------------------------------------
# Get-RecentEventHistory
# Reads the last N git tags (up to maxTags), capping at maxDays days before
# the release date, and returns the set of event IDs that were the "main"
# event for each prior tag. This lets us avoid repeating the same main event
# on two consecutive releases when alternatives are available.
# ---------------------------------------------------------------------------
function Get-RecentEventHistory {
    param(
        [string]   $CurrentTag,
        [DateTime] $CurrentDate,
        [string]   $PreviousTag = '',
        [int]      $MaxTags  = 3,
        [int]      $MaxDays  = 10
    )
    $usedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Collect recent tags (date-based yyyyMMdd pattern), excluding the current tag.
    # $PSNativeCommandUseErrorActionPreference is set here so non-zero git exit codes
    # do not become terminating errors under $ErrorActionPreference = 'Stop'.
    $recentTags = @()
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        $allTagRaw = git for-each-ref --sort=-creatordate --format='%(refname:short)' refs/tags 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $allTagRaw) {
            $allTags = @($allTagRaw | Where-Object { $_ -match '^\d{8}[a-z]?$' -and $_ -ne $CurrentTag })
            $recentTags = @($allTags | Select-Object -First $MaxTags)
        }
    } catch {
        # git not available or not in a git repo (test mode)
    }

    if ($recentTags.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($PreviousTag)) {
        if ($PreviousTag -match '^\d{8}[a-z]?$' -and $PreviousTag -ne $CurrentTag) {
            $recentTags = @($PreviousTag)
        }
    }

    if ($recentTags.Count -eq 0) {
        return $usedIds
    }

    foreach ($tag in $recentTags) {
        $tagDate = Resolve-ReleaseDate -TagText ([string]$tag)
        $daysDiff = [Math]::Abs(($CurrentDate.Date - $tagDate.Date).TotalDays)
        if ($daysDiff -gt $MaxDays) { continue }

        # Replay the event-selection algorithm for this tag (without birthday fallback)
        $tagSeed = Get-DeterministicSeed -TagText ([string]$tag)
        $tagRng  = [System.Random]::new($tagSeed)
        $tagCandidates = [System.Collections.ArrayList]::new()

        # Kokkoro BDay
        if ($GreetingsData.ContainsKey('KokkoroBDay') -and $GreetingsData['KokkoroBDay'] -is [System.Collections.IDictionary]) {
            $kb = $GreetingsData['KokkoroBDay']
            $dist = Get-SignedDayDistance -CurrentDate $tagDate -TargetMonth ([int]$kb['Month']) -TargetDay ([int]$kb['Day'])
            $bBefore = if ($kb.Contains('DaysBefore')) { [int]$kb['DaysBefore'] } else { 6 }
            $bAfter  = if ($kb.Contains('DaysAfter'))  { [int]$kb['DaysAfter'] }  else { 1 }
            if ($dist -ge (-$bBefore) -and $dist -le $bAfter) {
                [void]$tagCandidates.Add([PSCustomObject]@{ Id = 'KokkoroBDay'; Priority = 100; AbsDist = [Math]::Abs($dist); IsExactDay = ($dist -eq 0) })
            }
        }

        # Gourmet Birthdays
        if ($GreetingsData.ContainsKey('GourmetBirthdays')) {
            foreach ($gb in @($GreetingsData['GourmetBirthdays'])) {
                if ($gb -isnot [System.Collections.IDictionary]) { continue }
                $dist = Get-SignedDayDistance -CurrentDate $tagDate -TargetMonth ([int]$gb['Month']) -TargetDay ([int]$gb['Day'])
                $bBefore = if ($gb.Contains('DaysBefore')) { [int]$gb['DaysBefore'] } else { 1 }
                $bAfter  = if ($gb.Contains('DaysAfter'))  { [int]$gb['DaysAfter'] }  else { 0 }
                if ($dist -ge (-$bBefore) -and $dist -le $bAfter) {
                    [void]$tagCandidates.Add([PSCustomObject]@{ Id = [string]$gb['Id']; Priority = 96; AbsDist = [Math]::Abs($dist); IsExactDay = ($dist -eq 0) })
                }
            }
        }

        # Calendar events
        if ($GreetingsData.ContainsKey('Calendar')) {
            foreach ($ev in @($GreetingsData['Calendar'])) {
                if ($ev -isnot [System.Collections.IDictionary]) { continue }
                $dist = Get-SignedDayDistance -CurrentDate $tagDate -TargetMonth ([int]$ev['Month']) -TargetDay ([int]$ev['Day'])
                $bBefore = if ($ev.Contains('DaysBefore')) { [int]$ev['DaysBefore'] } else { 3 }
                $bAfter  = if ($ev.Contains('DaysAfter'))  { [int]$ev['DaysAfter'] }  else { 1 }
                if ($dist -ge (-$bBefore) -and $dist -le $bAfter) {
                    $prio = if ($ev.Contains('Priority')) { [int]$ev['Priority'] } else { 70 }
                    [void]$tagCandidates.Add([PSCustomObject]@{ Id = [string]$ev['Id']; Priority = $prio; AbsDist = [Math]::Abs($dist); IsExactDay = ($dist -eq 0) })
                }
            }
        }

        if ($tagCandidates.Count -gt 0) {
            $sortedTagCands = @($tagCandidates | Sort-Object -Property @{Expression='IsExactDay';Descending=$true},@{Expression='Priority';Descending=$true},@{Expression='AbsDist';Descending=$false})
            [void]$usedIds.Add($sortedTagCands[0].Id)
            for ($i = 1; $i -lt $sortedTagCands.Count -and $i -le 2; $i++) {
                [void]$usedIds.Add($sortedTagCands[$i].Id)
            }
        }
    }

    return $usedIds
}

function Get-KokkoroGreeting {
    param(
        [string] $TagText,
        [psobject] $ChangeData,
        [string] $Override
    )
    if (-not [string]::IsNullOrWhiteSpace($Override) -and $Override.Trim() -ine 'auto') {
        return (Limit-SafeText -Text $Override.Trim() -MaxLength 380)
    }

    $seed = Get-DeterministicSeed -TagText $TagText
    $rng  = [System.Random]::new($seed)
    $relDate = Resolve-ReleaseDate -TagText $TagText

    # Collect matching calendar & birthday events
    $candidates = [System.Collections.ArrayList]::new()

    # 1. Kokkoro's own birthday (May 11, H-6..H+1)
    if ($GreetingsData.ContainsKey('KokkoroBDay') -and $GreetingsData['KokkoroBDay'] -is [System.Collections.IDictionary]) {
        $kb = $GreetingsData['KokkoroBDay']
        $dist = Get-SignedDayDistance -CurrentDate $relDate -TargetMonth ([int]$kb['Month']) -TargetDay ([int]$kb['Day'])
        $bBefore = if ($kb.Contains('DaysBefore')) { [int]$kb['DaysBefore'] } else { 6 }
        $bAfter  = if ($kb.Contains('DaysAfter'))  { [int]$kb['DaysAfter'] }  else { 1 }
        if ($dist -ge (-$bBefore) -and $dist -le $bAfter) {
            $pool = if ($dist -lt 0) { $kb['LinesBefore'] } elseif ($dist -gt 0) { $kb['LinesAfter'] } else { $kb['Lines'] }
            [void]$candidates.Add([PSCustomObject]@{
                Id         = 'KokkoroBDay'
                IsExactDay = ($dist -eq 0)
                Priority   = 100
                AbsDist    = [Math]::Abs($dist)
                MainLine   = (Select-PoolLine -Pool $pool -Rng $rng)
                NoteLine   = ''
            })
        }
    }

    # 2. Gourmet Guild member birthdays and special characters (H-1..H)
    if ($GreetingsData.ContainsKey('GourmetBirthdays')) {
        foreach ($gb in @($GreetingsData['GourmetBirthdays'])) {
            if ($gb -isnot [System.Collections.IDictionary]) { continue }
            $dist = Get-SignedDayDistance -CurrentDate $relDate -TargetMonth ([int]$gb['Month']) -TargetDay ([int]$gb['Day'])
            $bBefore = if ($gb.Contains('DaysBefore')) { [int]$gb['DaysBefore'] } else { 1 }
            $bAfter  = if ($gb.Contains('DaysAfter'))  { [int]$gb['DaysAfter'] }  else { 0 }
            if ($dist -ge (-$bBefore) -and $dist -le $bAfter) {
                $pool = if ($dist -lt 0) { $gb['LinesBefore'] } elseif ($dist -gt 0 -and $gb.Contains('LinesAfter')) { $gb['LinesAfter'] } else { $gb['Lines'] }
                [void]$candidates.Add([PSCustomObject]@{
                    Id         = [string]$gb['Id']
                    IsExactDay = ($dist -eq 0)
                    Priority   = 96
                    AbsDist    = [Math]::Abs($dist)
                    MainLine   = (Select-PoolLine -Pool $pool -Rng $rng)
                    NoteLine   = ''
                })
            }
        }
    }

    # 3. Calendar celebrations (windows set per-event: standard 3/1, anniversaries 0/3, AprilFool 0/1)
    if ($GreetingsData.ContainsKey('Calendar')) {
        foreach ($ev in @($GreetingsData['Calendar'])) {
            if ($ev -isnot [System.Collections.IDictionary]) { continue }
            $dist = Get-SignedDayDistance -CurrentDate $relDate -TargetMonth ([int]$ev['Month']) -TargetDay ([int]$ev['Day'])
            $bBefore = if ($ev.Contains('DaysBefore')) { [int]$ev['DaysBefore'] } else { 3 }
            $bAfter  = if ($ev.Contains('DaysAfter'))  { [int]$ev['DaysAfter'] }  else { 1 }
            if ($dist -ge (-$bBefore) -and $dist -le $bAfter) {
                $pool = if ($dist -lt 0) { $ev['LinesBefore'] } elseif ($dist -gt 0) { $ev['LinesAfter'] } else { $ev['Lines'] }
                $note = if ($dist -lt 0 -and $ev.Contains('NoteBefore')) {
                    [string]$ev['NoteBefore']
                } elseif ($dist -gt 0 -and $ev.Contains('NoteAfter')) {
                    [string]$ev['NoteAfter']
                } elseif ($ev.Contains('Note')) {
                    [string]$ev['Note']
                } else {
                    ''
                }
                [void]$candidates.Add([PSCustomObject]@{
                    Id         = [string]$ev['Id']
                    IsExactDay = ($dist -eq 0)
                    Priority   = if ($ev.Contains('Priority')) { [int]$ev['Priority'] } else { 70 }
                    AbsDist    = [Math]::Abs($dist)
                    MainLine   = (Select-PoolLine -Pool $pool -Rng $rng)
                    NoteLine   = $note
                })
            }
        }
    }

    $sortedEvents = @($candidates | Sort-Object -Property @{Expression = 'IsExactDay'; Descending = $true}, @{Expression = 'Priority'; Descending = $true}, @{Expression = 'AbsDist'; Descending = $false})

    # History-from-tags: build a set of event IDs that were main or note in recent prior releases.
    # If the top candidate was already used recently AND an alternative exists, prefer the alternative.
    $recentlyUsed = Get-RecentEventHistory -CurrentTag $TagText -CurrentDate $relDate -PreviousTag $PreviousTag
    if ($null -eq $recentlyUsed) {
        $recentlyUsed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    # Choose MainLine (Critical config > top calendar/birthday event > context/season)
    $mainLine = ''
    $usedEventId = ''
    $ctx = if ($GreetingsData.ContainsKey('Context')) { $GreetingsData['Context'] } else { @{} }

    if ([bool]$ChangeData.Critical -and $ctx.Contains('Critical')) {
        $mainLine = Select-PoolLine -Pool $ctx['Critical'] -Rng $rng
    } elseif ($sortedEvents.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($sortedEvents[0].MainLine)) {
        # Try to pick an event not used recently, to vary the output across consecutive releases
        $chosen = $null
        foreach ($ev in $sortedEvents) {
            if (-not [string]::IsNullOrWhiteSpace($ev.MainLine)) {
                if (-not $recentlyUsed.Contains($ev.Id)) {
                    $chosen = $ev
                    break
                }
            }
        }
        # If all candidates were recently used, fall back to the top priority one
        if ($null -eq $chosen) {
            $chosen = $sortedEvents[0]
        }
        $mainLine    = $chosen.MainLine
        $usedEventId = $chosen.Id
    } elseif (-not [bool]$ChangeData.HasChanges -and $ctx.Contains('Maintenance')) {
        $mainLine = Select-PoolLine -Pool $ctx['Maintenance'] -Rng $rng
    } elseif ([int]$ChangeData.TotalChanges -ge 15 -and $ctx.Contains('Major')) {
        $mainLine = Select-PoolLine -Pool $ctx['Major'] -Rng $rng
    } elseif ([int]$ChangeData.StoryTotal -gt 0 -and $ctx.Contains('NewStory')) {
        $mainLine = Select-PoolLine -Pool $ctx['NewStory'] -Rng $rng
    } elseif ([int]$ChangeData.TextureTotal -gt [int]$ChangeData.TextTotal -and $ctx.Contains('Texture')) {
        $mainLine = Select-PoolLine -Pool $ctx['Texture'] -Rng $rng
    } else {
        $seasonKey = switch ($relDate.Month) {
            { $_ -in 3, 4, 5 }   { 'Spring'; break }
            { $_ -in 6, 7, 8 }   { 'Summer'; break }
            { $_ -in 9, 10, 11 } { 'Autumn'; break }
            default              { 'Winter'; break }
        }
        $combinedPool = [System.Collections.ArrayList]::new()
        if ($ctx.Contains('Default')) {
            foreach ($l in @($ctx['Default'])) { [void]$combinedPool.Add($l) }
        }
        if ($GreetingsData.ContainsKey('Seasons') -and $GreetingsData['Seasons'].Contains($seasonKey)) {
            foreach ($l in @($GreetingsData['Seasons'][$seasonKey])) { [void]$combinedPool.Add($l) }
        }
        $mainLine = Select-PoolLine -Pool $combinedPool -Rng $rng
    }

    if ([string]::IsNullOrWhiteSpace($mainLine)) {
        $mainLine = 'Aruji-sama, a new update has arrived. Please check the details below. ✨'
    }
    $mainLine = Limit-SafeText -Text $mainLine -MaxLength 145

    $linesOut = [System.Collections.ArrayList]::new()
    [void]$linesOut.Add($mainLine)

    # Additive EventNote lines (up to 2 secondary overlapping events)
    $noteCount = 0
    foreach ($ev in $sortedEvents) {
        if ($ev.Id -eq $usedEventId) { continue }
        if (-not [string]::IsNullOrWhiteSpace($ev.NoteLine)) {
            [void]$linesOut.Add((Limit-SafeText -Text $ev.NoteLine -MaxLength 85))
            $noteCount++
            if ($noteCount -ge 2) { break }
        }
    }

    # Exact-day character birthday line (never suppressed, even on Critical config)
    $todaysBirthdays = [System.Collections.ArrayList]::new()
    if ($BirthdaysData.ContainsKey('Birthdays')) {
        foreach ($b in @($BirthdaysData['Birthdays'])) {
            if ($b -isnot [System.Collections.IDictionary]) { continue }
            if ([int]$b['Month'] -eq $relDate.Month -and [int]$b['Day'] -eq $relDate.Day) {
                [void]$todaysBirthdays.Add($b)
            }
        }
    }
    if ($todaysBirthdays.Count -gt 0) {
        $bLine = Format-BirthdayNames -Entries $todaysBirthdays
        if (-not [string]::IsNullOrWhiteSpace($bLine)) {
            [void]$linesOut.Add((Limit-SafeText -Text $bLine -MaxLength 95))
        }
    }

    $joined = ($linesOut -join "`n").Trim()
    return (Limit-SafeText -Text $joined -MaxLength 380)
}

$Greeting = Get-KokkoroGreeting -TagText $ReleaseTag -ChangeData $Data -Override $CustomGreeting

Write-Host "::group::Kokkoro Greeting ($($Greeting.Length) chars)"
Write-Host $Greeting
Write-Host "::endgroup::"

# Build Discord body with dynamic budget ensuring total message <= 2000 UTF-16 units
# Wrapper in release.yml: "📌 <RoleMention>\n<Greeting>\n\n<DiscordBody>"
$mentionOverhead = if ([string]::IsNullOrWhiteSpace($RoleMention)) { 6 } else { $RoleMention.Length + 6 }
$bodyBudget = 2000 - $mentionOverhead - $Greeting.Length
if ($bodyBudget -lt 400) { $bodyBudget = 400 }

$relUrl  = "https://github.com/$RepoSlug/releases/tag/$ReleaseTag"
$dlUrl   = "https://github.com/$RepoSlug/releases/download/$ReleaseTag/PriconneTL_$ReleaseTag.zip"
$cmpUrl  = if (-not [string]::IsNullOrWhiteSpace($PreviousTag)) {
    "https://github.com/$RepoSlug/compare/$PreviousTag...$ReleaseTag"
} else {
    $relUrl
}

$headerLine = "## Priconne TL — v$ReleaseTag"
$footerLine = "### 📣 [Release](<$relUrl>) | 📥 [Download](<$dlUrl>) | ↔️ [Compare](<$cmpUrl>)"

$bodyLines = [System.Collections.ArrayList]::new()
[void]$bodyLines.Add($headerLine)

if (-not [bool]$Data.HasChanges) {
    [void]$bodyLines.Add('🛠️ Maintenance release — no translation changes.')
} else {
    # Compact single-line category summary with labels
    $catChips = [System.Collections.ArrayList]::new()
    if ([int]$Data.TextTotal -gt 0)         { [void]$catChips.Add("📝 Text: $($Data.TextTotal)") }
    if ([int]$Data.TextureTotal -gt 0)      { [void]$catChips.Add("🖼️ Texture: $($Data.TextureTotal)") }
    if ([int]$Data.StoryTotal -gt 0)        { [void]$catChips.Add("📖 Story: $($Data.StoryTotal)") }
    if ([int]$Data.PluginAssetsTotal -gt 0) { [void]$catChips.Add("🧩 Plugin Assets: $($Data.PluginAssetsTotal)") }
    if ([int]$Data.FontTotal -gt 0)         { [void]$catChips.Add("🔤 Font: $($Data.FontTotal)") }
    if ([int]$Data.PluginsTotal -gt 0)      { [void]$catChips.Add("🔧 Plugins: $($Data.PluginsTotal)") }
    if ([int]$Data.ConfigTotal -gt 0)       { [void]$catChips.Add("⚙️ Config: $($Data.ConfigTotal)") }
    if ([int]$Data.FrameworkFiles -gt 0)    { [void]$catChips.Add("⚙️ Framework: $($Data.FrameworkFiles)") }

    if ($catChips.Count -gt 0) {
        [void]$bodyLines.Add(($catChips -join ' · '))
    }

    if ([bool]$Data.Critical) {
        $critKeys = @($Data.CriticalKeys)
        $critList = if ($critKeys.Count -gt 0) { $critKeys -join ', ' } else { 'see release notes' }
        [void]$bodyLines.Add("⚠️ **Config update needed!** Updater users re-apply: $critList")
    }

    # Add group breakdown bullets while staying well inside $bodyBudget
    $groups = @($Data.Groups)
    $staticCost = ($bodyLines -join "`n").Length + $footerLine.Length + 4
    $remainingForGroups = $bodyBudget - $staticCost
    $shownGroups = 0

    for ($i = 0; $i -lt $groups.Count; $i++) {
        $g = $groups[$i]
        $bullet = "- $($g.Category) / $($g.Group) — $($g.Count) item(s)"
        $moreNote = if (($i + 1) -lt $groups.Count) { "`n- *...and $($groups.Count - ($i + 1)) more group(s)*" } else { '' }
        if (($bullet.Length + $moreNote.Length + 1) -le $remainingForGroups) {
            [void]$bodyLines.Add($bullet)
            $remainingForGroups -= ($bullet.Length + 1)
            $shownGroups++
        } else {
            $leftover = $groups.Count - $shownGroups
            if ($leftover -gt 0 -and $remainingForGroups -ge 30) {
                [void]$bodyLines.Add("- *...and $leftover more group(s)*")
            }
            break
        }
    }
}

[void]$bodyLines.Add($footerLine)
$DiscordBody = Limit-SafeText -Text (($bodyLines -join "`n").Trim()) -MaxLength $bodyBudget

Write-Host "::group::Final Discord Body ($($DiscordBody.Length) / $bodyBudget chars)"
Write-Host $DiscordBody
Write-Host "::endgroup::"

# Write outputs to GITHUB_OUTPUT with unique GUID delimiters
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
    $gDelim = 'EOF_' + [Guid]::NewGuid().ToString('N')
    $bDelim = 'EOF_' + [Guid]::NewGuid().ToString('N')
    $outPayload = @(
        "greeting<<$gDelim"
        $Greeting
        $gDelim
        "discord_body<<$bDelim"
        $DiscordBody
        $bDelim
    ) -join "`n"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value $outPayload -Encoding utf8
}
