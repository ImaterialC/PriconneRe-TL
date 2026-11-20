# ============================================================
#  make_announce.ps1 — Additive Kokkoro Greeting + Discord Budget
#  Output: kokkoro_greeting & discord_changes (total <= 2000 UTF-16)
# ============================================================
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = $PSScriptRoot
$Tag  = if ($env:RELEASE_TAG)  { $env:RELEASE_TAG.Trim() }  else { 'local-test' }
$Prev = if ($env:PREVIOUS_TAG) { $env:PREVIOUS_TAG.Trim() } else { '' }

function Limit-SafeText {
    param([string]$Text, [int]$MaxLen)
    if ($null -eq $Text) { return '' }
    if ($MaxLen -lt 2) { return '' }
    if ($Text.Length -le $MaxLen) { return $Text }

    # Strip non-ASCII symbols/emojis before falling back to substring
    $clean = ($Text -replace '[^\x20-\x7E\u00A0-\u024F\u3000-\u9FFF\uFF00-\uFFEF]', '').Trim()
    if ($clean.Length -le $MaxLen) { return $clean }

    $cut = $MaxLen - 1
    if ($cut -gt 0 -and [char]::IsHighSurrogate($clean[$cut - 1])) {
        $cut--
    }
    return ($clean.Substring(0, $cut).TrimEnd() + '…')
}

$data = $null
$jsonPath = Join-Path (Get-Location).Path 'CHANGES.json'
if (Test-Path -LiteralPath $jsonPath) {
    $data = Get-Content -LiteralPath $jsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($Tag -eq 'local-test' -and $data.Tag) { $Tag = $data.Tag }
    if (-not $Prev -and $data.PreviousTag)     { $Prev = $data.PreviousTag }
}

$gCfg = @{
    Timezone        = 'SE Asia Standard Time'
    MaxMainLength   = 145
    MaxNoteLength   = 80
    MaxBdayLength   = 90
    SoftGreetingCap = 380
    MajorThreshold  = 15
    Calendar        = @()
    Seasons         = @()
    Context         = @{
        Critical    = @('Aruji-sama, please read the critical config notice below carefully before applying this update. ⚠️')
        Maintenance = @('Aruji-sama, only quiet housekeeping was performed this time — no translation changes were needed. 🍃')
        Default     = @('Aruji-sama, a new update has arrived. I have neatly arranged the details for you below. ✨')
    }
}
$gFile = Join-Path $ScriptDir 'kokkoro_greetings.psd1'
if (Test-Path -LiteralPath $gFile) {
    $loaded = Import-PowerShellDataFile -LiteralPath $gFile
    if ($loaded) { $gCfg = $loaded }
}

$BirthdayMap = @{}
$bFile = Join-Path $ScriptDir 'character_birthdays.psd1'
if (Test-Path -LiteralPath $bFile) {
    $bData = Import-PowerShellDataFile -LiteralPath $bFile
    if ($bData -and $bData.Birthdays) { $BirthdayMap = $bData.Birthdays }
}

function Get-TagDate {
    param([string]$tagStr, [string]$tzId)
    if ($tagStr -match '^(\d{4})(\d{2})(\d{2})') {
        $y = [int]$Matches[1]
        $m = [int]$Matches[2]
        $d = [int]$Matches[3]
        try {
            $parsed = [DateTime]::new($y, $m, $d)
            return ,$parsed
        } catch {}
    }
    try {
        $nowTz = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, $tzId).Date
        return ,$nowTz
    } catch {
        return ,(Get-Date).Date
    }
}

function Get-TagSeed {
    param([string]$tagStr)
    if ($tagStr -match '^(\d{8})([a-z])?$') {
        $base = [int]$Matches[1]
        $suf  = if ($Matches[2]) { ([int][char]$Matches[2] - 96) } else { 0 }
        return ($base + $suf)
    }
    $acc = 17
    foreach ($ch in $tagStr.ToCharArray()) { $acc = (($acc * 31) + [int]$ch) -band 0x7FFFFFFF }
    return $acc
}

function Get-CalendarMatches {
    param([DateTime]$Dt, $Cfg)
    [int]$baseYear = $Dt.Year
    $yearList = @(($baseYear - 1), $baseYear, ($baseYear + 1))

    $calMatches = @()
    foreach ($ev in @($Cfg.Calendar)) {
        $wBefore = if ($null -ne $ev.WindowBefore) { [int]$ev.WindowBefore } elseif ($null -ne $ev.Window) { [int]$ev.Window } else { 0 }
        $wAfter  = if ($null -ne $ev.WindowAfter)  { [int]$ev.WindowAfter }  elseif ($null -ne $ev.Window) { [int]$ev.Window } else { 0 }
        $prio    = if ($null -ne $ev.Priority)     { [int]$ev.Priority }     else { 50 }

        foreach ($yr in $yearList) {
            try { $evDate = [DateTime]::new([int]$yr, [int]$ev.Month, [int]$ev.Day) } catch { continue }
            $diff = ($Dt.Date - $evDate.Date).Days
            if ($diff -lt 0 -and [Math]::Abs($diff) -le $wBefore) {
                $lines = if ($ev.LinesBefore) { @($ev.LinesBefore) } else { @($ev.Lines) }
                if ($lines.Count -gt 0) {
                    $calMatches += [pscustomobject]@{
                        Name       = $ev.Name
                        IsExactDay = 0
                        Priority   = $prio
                        Dist       = [Math]::Abs($diff)
                        Lines      = $lines
                        ShortNote  = if ($ev.NoteBefore) { [string]$ev.NoteBefore } else { '' }
                    }
                }
            }
            elseif ($diff -eq 0) {
                $lines = @($ev.Lines)
                if ($lines.Count -gt 0) {
                    $calMatches += [pscustomobject]@{
                        Name       = $ev.Name
                        IsExactDay = 1
                        Priority   = $prio
                        Dist       = 0
                        Lines      = $lines
                        ShortNote  = if ($ev.Note) { [string]$ev.Note } else { '' }
                    }
                }
            }
            elseif ($diff -gt 0 -and $diff -le $wAfter) {
                $lines = if ($ev.LinesAfter) { @($ev.LinesAfter) } else { @($ev.Lines) }
                if ($lines.Count -gt 0) {
                    $calMatches += [pscustomobject]@{
                        Name       = $ev.Name
                        IsExactDay = 0
                        Priority   = $prio
                        Dist       = $diff
                        Lines      = $lines
                        ShortNote  = if ($ev.NoteAfter) { [string]$ev.NoteAfter } else { '' }
                    }
                }
            }
        }
    }

    if ($calMatches.Count -eq 0) { return @() }
    return @($calMatches | Sort-Object `
        @{ Expression = 'IsExactDay'; Descending = $true }, `
        @{ Expression = 'Priority';   Descending = $true }, `
        @{ Expression = 'Dist';       Ascending  = $true })
}

function Get-ContextPool {
    param([DateTime]$Dt, $ChangesData, $Cfg)
    $ctx = $Cfg.Context

    if ((-not $ChangesData -or -not $ChangesData.HasChanges) -and $ctx.Maintenance) {
        return @($ctx.Maintenance)
    }

    if ($ChangesData) {
        $storyRow   = @($ChangesData.Counts) | Where-Object { $_.Id -eq 'Story' }   | Select-Object -First 1
        $pluginRow  = @($ChangesData.Counts) | Where-Object { $_.Id -eq 'Plugins' } | Select-Object -First 1
        $textureRow = @($ChangesData.Counts) | Where-Object { $_.Id -eq 'Texture' } | Select-Object -First 1
        $totalItems = @($ChangesData.Items).Count
        $majorMin   = if ($Cfg.MajorThreshold) { [int]$Cfg.MajorThreshold } else { 15 }

        if ($storyRow -and $storyRow.Added -gt 0 -and $ctx.NewStory) {
            return @($ctx.NewStory)
        }
        if ($pluginRow -and $pluginRow.Total -gt 0 -and $ctx.Plugin) {
            return @($ctx.Plugin)
        }
        if ($totalItems -ge $majorMin -and $ctx.Major) {
            return @($ctx.Major)
        }
        if ($textureRow -and $textureRow.Total -gt 0 -and $textureRow.Total -eq $totalItems -and $ctx.Texture) {
            return @($ctx.Texture)
        }
    }

    [int]$curMonth = $Dt.Month
    $seasonLines = @()
    foreach ($s in @($Cfg.Seasons)) {
        if ($curMonth -in @($s.Months) -and $s.Lines) {
            $seasonLines = @($s.Lines)
            break
        }
    }
    return @($seasonLines + @($ctx.Default))
}

function Select-FromPool {
    param([string[]]$Pool, [string]$CurTag, [string]$PrevTag)
    if (-not $Pool -or $Pool.Count -eq 0) {
        return 'Aruji-sama, a new update has arrived. I have neatly arranged the details for you below. ✨'
    }
    $rng = [System.Random]::new((Get-TagSeed $CurTag))
    $idx = $rng.Next(0, $Pool.Count)
    if ($PrevTag -and $Pool.Count -gt 1) {
        $prevRng = [System.Random]::new((Get-TagSeed $PrevTag))
        $prevIdx = $prevRng.Next(0, $Pool.Count)
        if ($idx -eq $prevIdx) {
            $idx = ($idx + 1) % $Pool.Count
        }
    }
    return ($Pool[$idx] -replace '\r?\n', ' ').Trim()
}

function Format-CharacterHonorific {
    param($Entry)
    if ($Entry -is [System.Collections.IDictionary]) {
        $name = ([string]$Entry.Name).Trim()
        $suf  = if ($null -ne $Entry.Suffix) { [string]$Entry.Suffix } else { '-sama' }
        return "$name$suf"
    }
    $raw = ([string]$Entry).Trim()
    if (-not $raw) { return '' }
    if ($raw -match "'s\b" -or $raw -match '\b(Father|Mother|Friend|Sister|Brother)\b') {
        return $raw
    }
    return "$raw-sama"
}

function Get-CharacterBirthdayLine {
    param(
        [DateTime]$Dt,
        [hashtable]$Map,
        [int]$MaxLen = 90,
        [switch]$Compact
    )
    if (-not $Map -or $Map.Count -eq 0) { return '' }
    $key = $Dt.ToString('MM-dd')
    if (-not $Map.ContainsKey($key)) { return '' }

    $chars = @($Map[$key] | ForEach-Object { Format-CharacterHonorific $_ } | Where-Object { $_ })
    if ($chars.Count -eq 0) { return '' }

    $line = ''
    if ($Compact -and $chars.Count -ge 3) {
        $rest = $chars.Count - 2
        $line = "Incidentally, I heard today marks the birthdays of $($chars[0]), $($chars[1]), and $rest others. 🎂"
    } elseif ($chars.Count -eq 1) {
        $line = "Incidentally, I heard that today is $($chars[0])'s birthday. 🎂"
    } elseif ($chars.Count -eq 2) {
        $line = "Incidentally, I heard today marks the birthdays of $($chars[0]) and $($chars[1]). 🎂"
    } else {
        $head = ($chars[0..($chars.Count - 2)] -join ', ')
        $line = "Incidentally, I heard today marks the birthdays of $head, and $($chars[-1]). 🎂"
    }

    if ($line.Length -gt $MaxLen -and $chars.Count -ge 3 -and -not $Compact) {
        $rest = $chars.Count - 2
        $line = "Incidentally, I heard today marks the birthdays of $($chars[0]), $($chars[1]), and $rest others. 🎂"
    }
    if ($line.Length -gt $MaxLen -and $chars.Count -ge 2) {
        $rest = $chars.Count - 1
        $line = "Incidentally, today marks the birthdays of $($chars[0]) and $rest others. 🎂"
    }
    return (Limit-SafeText -Text $line -MaxLen $MaxLen)
}

function Resolve-KokkoroGreeting {
    param([string]$InputMsg, [string]$CurTag, [string]$PrevTag, $ChangesData, $Cfg, [hashtable]$BdayMap)
    $maxMain = if ($Cfg.MaxMainLength)   { [int]$Cfg.MaxMainLength }   else { 145 }
    $maxNote = if ($Cfg.MaxNoteLength)   { [int]$Cfg.MaxNoteLength }   else { 80 }
    $maxBday = if ($Cfg.MaxBdayLength)   { [int]$Cfg.MaxBdayLength }   else { 90 }
    $softCap = if ($Cfg.SoftGreetingCap) { [int]$Cfg.SoftGreetingCap } else { 380 }

    $trimmed = if ($null -ne $InputMsg) { $InputMsg.Trim() } else { '' }
    if ($trimmed -and $trimmed -ine 'auto') {
        $oneLine = ($trimmed -replace '\r?\n', ' ').Trim()
        return (Limit-SafeText -Text $oneLine -MaxLen 220)
    }

    $tz   = if ($Cfg.Timezone) { $Cfg.Timezone } else { 'SE Asia Standard Time' }
    [DateTime]$dt = (Get-TagDate -tagStr $CurTag -tzId $tz | Select-Object -First 1)

    $calMatches = @(Get-CalendarMatches -Dt $dt -Cfg $Cfg)
    $isCritical = ($ChangesData -and $ChangesData.Critical -and $Cfg.Context.Critical)

    $mainLine   = ''
    $eventNotes = @()

    if ($isCritical) {
        $rawMain  = Select-FromPool -Pool @($Cfg.Context.Critical) -CurTag $CurTag -PrevTag $PrevTag
        $mainLine = Limit-SafeText -Text $rawMain -MaxLen $maxMain
        foreach ($m in @($calMatches | Select-Object -First 2)) {
            if ($m.ShortNote) {
                $eventNotes += (Limit-SafeText -Text $m.ShortNote -MaxLen $maxNote)
            }
        }
    } elseif ($calMatches.Count -gt 0) {
        $winner   = $calMatches[0]
        $rawMain  = Select-FromPool -Pool @($winner.Lines) -CurTag $CurTag -PrevTag $PrevTag
        $mainLine = Limit-SafeText -Text $rawMain -MaxLen $maxMain
        if ($calMatches.Count -gt 1) {
            foreach ($m in @($calMatches[1..($calMatches.Count - 1)] | Select-Object -First 2)) {
                if ($m.ShortNote) {
                    $eventNotes += (Limit-SafeText -Text $m.ShortNote -MaxLen $maxNote)
                }
            }
        }
    } else {
        $pool     = @(Get-ContextPool -Dt $dt -ChangesData $ChangesData -Cfg $Cfg)
        $rawMain  = Select-FromPool -Pool $pool -CurTag $CurTag -PrevTag $PrevTag
        $mainLine = Limit-SafeText -Text $rawMain -MaxLen $maxMain
    }

    $bdayLine = Get-CharacterBirthdayLine -Dt $dt -Map $BdayMap -MaxLen $maxBday

    $segments = @($mainLine) + @($eventNotes)
    if ($bdayLine) { $segments += $bdayLine }
    $combined = $segments -join "`n"

    # Enforce soft greeting cap by shortening the birthday list first (never deleting it)
    if ($combined.Length -gt $softCap -and $bdayLine) {
        $bdayCompact = Get-CharacterBirthdayLine -Dt $dt -Map $BdayMap -MaxLen $maxBday -Compact
        $segments = @($mainLine) + @($eventNotes) + @($bdayCompact)
        $combined = $segments -join "`n"
    }
    if ($combined.Length -gt $softCap -and $eventNotes.Count -gt 1) {
        $segments = @($mainLine, $eventNotes[0])
        if ($bdayLine) { $segments += (Get-CharacterBirthdayLine -Dt $dt -Map $BdayMap -MaxLen $maxBday -Compact) }
        $combined = $segments -join "`n"
    }

    return $combined
}

$Greeting = Resolve-KokkoroGreeting -InputMsg $env:KOKKORO_MESSAGE -CurTag $Tag -PrevTag $Prev -ChangesData $data -Cfg $gCfg -BdayMap $BirthdayMap

# ---------- Assemble Discord Body Within Strict <= 2000 UTF-16 Budget ----------
$mentionLen = 23
$bodyBudget = 2000 - $mentionLen - $Greeting.Length - 37
if ($bodyBudget -lt 250) { $bodyBudget = 250 }

$headerLines = @("**Priconne TL — v$Tag**")
$summaryLine = ''
if ($data -and $data.HasChanges) {
    $sum = @(@($data.Counts) | Where-Object { $_.Total -gt 0 } |
             ForEach-Object { "$($_.Icon) $($_.Id): $($_.Total)" })
    if ($data.FrameworkFiles -gt 0) { $sum += "⚙️ Framework: $($data.FrameworkFiles)" }
    if ($sum.Count -gt 0) { $summaryLine = ($sum -join ' · ') }
} else {
    $summaryLine = '🛠️ Maintenance release — no translation changes.'
}

$mandatoryWarn = @()
if ($data -and $data.Critical) {
    $keys = @(@($data.Config) | ForEach-Object { $_.Keys } | ForEach-Object { $_.Key } | Select-Object -Unique)
    $show = @($keys | Select-Object -First 3)
    $more = if ($keys.Count -gt 3) { " (+$($keys.Count - 3) more)" } else { '' }
    $mandatoryWarn += "⚠️ **Config update needed!** Updater users re-apply: $($show -join ', ')$more"
}

$pluginLines = @()
foreach ($pg in @($data.Plugins)) {
    if (-not $pg) { continue }
    $note = if ($pg.Note) { " — $($pg.Note)" } else { '' }
    $pluginLines += "🔧 **$($pg.Name)**$note"
}

$highlightLines = @()
if ($data) {
    $top = @(@($data.Items) | Where-Object { $_.Category -in 'Text', 'Texture', 'Story', 'Assets' } |
        Group-Object { "$($_.Category)|$($_.Group)" } | Sort-Object Count -Descending | Select-Object -First 5)
    foreach ($t in $top) {
        $cat, $grp = $t.Name -split '\|', 2
        $highlightLines += "• $cat / $grp — $($t.Count) item(s)"
    }
}

$footer = "📥 [Release](<https://github.com/ImaterialC/PriconneRe-TL/releases/tag/$Tag>)" +
          " | [Download](<https://github.com/ImaterialC/PriconneRe-TL/releases/download/$Tag/PriconneTL_$Tag.zip>)"
if ($Prev) {
    $footer += " | [Compare](<https://github.com/ImaterialC/PriconneRe-TL/compare/$Prev...$Tag>)"
}

$coreLines = @($headerLines)
if ($summaryLine) { $coreLines += $summaryLine }
$coreLines += $mandatoryWarn

# Trim order: highlights -> plugin lines -> summary detail. Never trim config warning or footer.
$body = (@($coreLines) + @($pluginLines) + @($highlightLines) + @($footer)) -join "`n"
if ($body.Length -gt $bodyBudget) {
    $hKeep = @($highlightLines)
    while ($hKeep.Count -gt 0) {
        $hKeep = if ($hKeep.Count -gt 1) { @($hKeep[0..($hKeep.Count - 2)]) } else { @() }
        $cand  = (@($coreLines) + @($pluginLines) + $hKeep + @('…', $footer)) -join "`n"
        if ($cand.Length -le $bodyBudget) { $body = $cand; break }
    }
}
if ($body.Length -gt $bodyBudget) {
    $pKeep = @($pluginLines)
    while ($pKeep.Count -gt 0) {
        $pKeep = if ($pKeep.Count -gt 1) { @($pKeep[0..($pKeep.Count - 2)]) } else { @() }
        $cand  = (@($coreLines) + $pKeep + @('…', $footer)) -join "`n"
        if ($cand.Length -le $bodyBudget) { $body = $cand; break }
    }
}
if ($body.Length -gt $bodyBudget) {
    $body = (@($headerLines) + @($mandatoryWarn) + @($footer)) -join "`n"
}

Write-Information "::group::Kokkoro Greeting ($($Greeting.Length) chars)`n$Greeting`n::endgroup::"
Write-Information "::group::Final Discord Body ($($body.Length) / $bodyBudget chars)`n$body`n::endgroup::"

if ($env:GITHUB_OUTPUT) {
    $d1 = "EOF_$([guid]::NewGuid().ToString('N'))"
    $d2 = "EOF_$([guid]::NewGuid().ToString('N'))"
    $outPayload = "kokkoro_greeting<<$d1`n$Greeting`n$d1`ndiscord_changes<<$d2`n$body`n$d2`n"
    [System.IO.File]::AppendAllText($env:GITHUB_OUTPUT, $outPayload, [System.Text.UTF8Encoding]::new($false))
} else {
    Write-Output "=== KOKKORO GREETING ==="
    Write-Output $Greeting
    Write-Output "=== DISCORD BODY ==="
    Write-Output $body
}
