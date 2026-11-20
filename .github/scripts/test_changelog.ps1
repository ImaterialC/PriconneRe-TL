# ============================================================
#  test_changelog.ps1 — Acceptance & Regression Test Suite
#  Tests all changelog, config watchlist, greeting merge, and budget rules
# ============================================================
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$MakeChangelog = Join-Path $ScriptDir 'make_changelog.ps1'
$MakeAnnounce  = Join-Path $ScriptDir 'make_announce.ps1'

Write-Output '=== 0. PowerShell ArrayList Cast Probe ==='
try { [void][System.Collections.ArrayList]@('a', 'b'); Write-Output 'CAST2 OK' } catch { Write-Output 'CAST2 FAIL' }
try { [void][System.Collections.ArrayList]('a');       Write-Output 'CAST1 OK' } catch { Write-Output 'CAST1 FAIL' }

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("priconne_test_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$passed = 0
$failed = 0

function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) {
        $script:passed++
        Write-Output "  [PASS] $Msg"
    } else {
        $script:failed++
        Write-Error "  [FAIL] $Msg" -ErrorAction Continue
    }
}

function Test-NoLoneSurrogates([string]$Text) {
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ([char]::IsHighSurrogate($c)) {
            if (($i + 1) -ge $Text.Length -or -not [char]::IsLowSurrogate($Text[$i + 1])) {
                return $false
            }
            $i++
        } elseif ([char]::IsLowSurrogate($c)) {
            return $false
        }
    }
    return $true
}

function Invoke-Scenario {
    param(
        [string]$Name,
        [string]$Tag,
        [string]$PrevTag,
        [string[]]$DiffLines,
        [string]$KokkoroInput = 'auto',
        [string]$OldConfigIni = '',
        [string]$NewConfigIni = '',
        [switch]$Quiet
    )
    if (-not $Quiet) { Write-Output "`n--- Scenario: $Name ---" }
    $work = Join-Path $tmpRoot ($Name -replace '[^a-zA-Z0-9_-]', '_')
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    New-Item -ItemType Directory -Path $work | Out-Null
    Push-Location -LiteralPath $work

    $origInfoPref = $InformationPreference
    if ($Quiet) { $InformationPreference = 'SilentlyContinue' }

    try {
        Set-Content -LiteralPath './RELEASE_NOTE' -Value "|[Download](https://example.com)|`r`n|-|" -Encoding utf8
        $diffPath = Join-Path $work 'mock_diff.txt'
        [System.IO.File]::WriteAllLines($diffPath, [string[]]$DiffLines, [System.Text.UTF8Encoding]::new($false))

        $oldCfgDir = Join-Path $work 'old_cfg'
        New-Item -ItemType Directory -Path $oldCfgDir | Out-Null
        if ($OldConfigIni) {
            [System.IO.File]::WriteAllText((Join-Path $oldCfgDir 'AutoTranslatorConfig.ini'), $OldConfigIni, [System.Text.UTF8Encoding]::new($false))
        }
        if ($NewConfigIni) {
            $newCfgDir = Join-Path $work 'src/BepInEx/config'
            New-Item -ItemType Directory -Path $newCfgDir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $newCfgDir 'AutoTranslatorConfig.ini'), $NewConfigIni, [System.Text.UTF8Encoding]::new($false))
        }

        $outFile = Join-Path $work 'gh_out.txt'
        New-Item -ItemType File -Path $outFile | Out-Null

        $env:RELEASE_TAG         = $Tag
        $env:PREVIOUS_TAG        = $PrevTag
        $env:MOCK_DIFF_FILE      = $diffPath
        $env:MOCK_CONFIG_OLD_DIR = $oldCfgDir
        $env:KOKKORO_MESSAGE     = $KokkoroInput
        $env:GITHUB_OUTPUT       = $outFile

        & $MakeChangelog
        & $MakeAnnounce

        $rn   = Get-Content -LiteralPath './RELEASE_NOTE' -Raw -Encoding utf8
        $json = Get-Content -LiteralPath './CHANGES.json' -Raw -Encoding utf8 | ConvertFrom-Json
        $gh   = Get-Content -LiteralPath $outFile -Raw -Encoding utf8

        $greet = ''
        $dBody = ''
        if ($gh -match '(?s)kokkoro_greeting<<(EOF_[a-f0-9]+)\r?\n(.*?)\r?\n\1') { $greet = $Matches[2] }
        if ($gh -match '(?s)discord_changes<<(EOF_[a-f0-9]+)\r?\n(.*?)\r?\n\1')  { $dBody = $Matches[2] }

        $fullDiscord = "<@&1349491054214385816> $greet `n$dBody`n"
        if (-not $Quiet) {
            Assert-True ($fullDiscord.Length -le 2000) "Total Discord message <= 2000 UTF-16 ($($fullDiscord.Length) chars)"
            Assert-True ($greet.Length -gt 0 -and $greet.Length -le 380) "Kokkoro greeting within soft cap ($($greet.Length) / 380 chars)"
            Assert-True ($dBody.Length -gt 0) "Discord body non-empty ($($dBody.Length) chars)"
            Assert-True ((Test-NoLoneSurrogates $greet) -and (Test-NoLoneSurrogates $dBody)) "No lone UTF-16 surrogates"
        }

        return [pscustomobject]@{
            ReleaseNote = $rn
            Data        = $json
            Greeting    = $greet
            DiscordBody = $dBody
            FullDiscord = $fullDiscord
        }
    } finally {
        $InformationPreference = $origInfoPref
        Pop-Location
        Remove-Item Env:RELEASE_TAG, Env:PREVIOUS_TAG, Env:MOCK_DIFF_FILE, Env:MOCK_CONFIG_OLD_DIR, Env:KOKKORO_MESSAGE, Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
    }
}

try {
    # 1. Zero changes / Same-day re-release empty diff
    $r1 = Invoke-Scenario -Name '01_ZeroChanges' -Tag '20261120a' -PrevTag '20261120' -DiffLines @()
    Assert-True (-not $r1.Data.HasChanges) 'HasChanges = false'
    Assert-True ($r1.ReleaseNote -notmatch '## Changelog') 'No ## Changelog header when empty'
    Assert-True ($r1.Greeting -match 'housekeeping|maintenance') 'Selects Maintenance greeting'

    # 2. Single file changed
    $r2 = Invoke-Scenario -Name '02_SingleFile' -Tag '20261121' -PrevTag '20261120a' -DiffLines @(
        "M`tsrc/BepInEx/Translation/en/Text/Character/Kyaru.txt"
    )
    Assert-True ($r2.Data.HasChanges) 'Single file detected'
    Assert-True ((@($r2.Data.Items).Count) -eq 1) 'Exactly 1 item recorded'

    # 3. Blacklisted files ignored
    $r3 = Invoke-Scenario -Name '03_OnlyBlacklisted' -Tag '20261122' -PrevTag '20261121' -DiffLines @(
        "M`tsrc/BepInEx/Translation/en/Text/_AutoGeneratedTranslations.txt"
        "A`tsrc/BepInEx/plugins/backup.rar"
        "A`tsrc/BepInEx/Translation/en/Texture/New folder/test.psd"
    )
    Assert-True (-not $r3.Data.HasChanges) 'Blacklisted files ignored completely'
    Assert-True ($r3.ReleaseNote -notmatch '## Changelog') 'No ## Changelog when all filtered'

    # 4. Framework + ForAMD Texture count contract (summary + AMD == details header total)
    $r4 = Invoke-Scenario -Name '04_FrameworkAndForAMD' -Tag '20261123' -PrevTag '20261122' -DiffLines @(
        "M`tsrc/BepInEx/core/BepInEx.dll"
        "A`tsrc/BepInEx/Translation/en/Texture/UI/btn_cancel [ABCDEF12].png"
        "A`tsrc/BepInEx/Translation/en/Texture/ForAMD/UI/btn_ok [1234567890].png"
    )
    Assert-True ($r4.Data.FrameworkFiles -eq 1) 'FrameworkFiles = 1'
    Assert-True ($r4.Data.ForAmdFiles -eq 1) 'ForAmdFiles = 1'
    $texCountRow = @($r4.Data.Counts) | Where-Object { $_.Id -eq 'Texture' } | Select-Object -First 1
    Assert-True ($texCountRow.Total -eq 1) 'Summary Texture total excludes AMD variants (Total = 1)'
    Assert-True ($r4.ReleaseNote -match '🖼️ Texture — 1 change\(s\) \(\+1 AMD variants\)') 'Texture details header reads 1 change(s) (+1 AMD variants)'
    Assert-True ($r4.ReleaseNote -match '\*\*AMD Texture Variants \(ForAMD\)\*\*') 'ForAMD rendered in its own sub-block'

    # 5. Pure rename R100 vs Rename+Edit R085 + Filename cleanup (G6)
    $r5 = Invoke-Scenario -Name '05_RenamesAndFilenameCleanup' -Tag '20261124' -PrevTag '20261123' -DiffLines @(
        "R100`tsrc/BepInEx/Translation/en/Text/Old.txt`tsrc/BepInEx/Translation/en/Text/NewPure.txt"
        "R085`tsrc/BepInEx/Translation/en/Text/Old2.txt`tsrc/BepInEx/Translation/en/Text/NewEdited.txt"
        "A`tsrc/BepInEx/Translation/en/Texture/UI/banner_event.png.png"
        "A`tsrc/BepInEx/Translation/en/Texture/UI/12345678-1234-1234-1234-123456789abc.png"
    )
    Assert-True ($r5.ReleaseNote -notmatch 'NewPure') 'R100 hidden'
    Assert-True ($r5.ReleaseNote -match 'NewEdited \*\(moved\)\*') 'R085 shown as moved'
    Assert-True ($r5.ReleaseNote -match 'banner_event\b' -and $r5.ReleaseNote -notmatch 'banner_event\.png') 'Repeated extension collapsed'
    Assert-True ($r5.ReleaseNote -match '\b12345678\b' -and $r5.ReleaseNote -notmatch '12345678-1234') 'Bare UUID collapsed to 8-char prefix'

    # 6. Other/Alpha & atlases merged into Texture with verbatim prefix + Japanese filename
    $r6 = Invoke-Scenario -Name '06_AlphaAtlasesAndJapanese' -Tag '20261125' -PrevTag '20261124' -DiffLines @(
        "A`tsrc/BepInEx/Translation/en/Other/Alpha/Name/Crunchyroll/Kyaru/chara_name_1060.png"
        "M`tsrc/BepInEx/Translation/en/Other/atlases/AtlasCommon [ABCDEF1234].png"
        "A`tsrc/BepInEx/Translation/en/Text/Event/キャルちゃんの冒険.txt"
    )
    Assert-True ($r6.ReleaseNote -match 'Other/Alpha/Name/Crunchyroll/Kyaru') 'Alpha folder prefix preserved verbatim'
    Assert-True ($r6.ReleaseNote -match 'キャルちゃんの冒険') 'Japanese filename preserved'

    # 7. Section-level Watchlist ([Behaviour] / [Texture]), Secret + C:\Users redaction, Malformed warning, NO birthday suppression
    $wlPath = Join-Path $ScriptDir 'config_watchlist.txt'
    $origWl = Get-Content -LiteralPath $wlPath -Raw -Encoding utf8
    try {
        [System.IO.File]::WriteAllText($wlPath, "[Behaviour]`n[Texture]`nMALFORMED_LINE_WITHOUT_BRACKETS`n", [System.Text.UTF8Encoding]::new($false))
        $oldIni = "[Behaviour]`r`nMaxCharactersPerTranslation=200`r`nApiKey=SECRET_OLD_12345`r`nCacheDir=C:\Users\Alice\AppData\Local\Temp`r`n"
        $newIni = "[Behaviour]`r`nMaxCharactersPerTranslation=240`r`nApiKey=SECRET_NEW_67890`r`nCacheDir=C:\Users\Bob\AppData\Local\Temp`r`n"

        $warnOut = @()
        # Use 20260405 (Yui birthday) to verify Critical config does NOT suppress birthday line
        $r7 = Invoke-Scenario -Name '07_ConfigSectionWatchAndRedaction' -Tag '20260405' -PrevTag '20260401' `
            -DiffLines @("M`tsrc/BepInEx/config/AutoTranslatorConfig.ini") `
            -OldConfigIni $oldIni -NewConfigIni $newIni -WarningVariable warnOut 3>$null

        Assert-True ($r7.Data.Critical) 'Bare [Behaviour] section triggers Critical on any key change'
        Assert-True ($r7.ReleaseNote -notmatch 'SECRET_OLD_12345' -and $r7.ReleaseNote -notmatch 'SECRET_NEW_67890') 'Secrets redacted in RELEASE_NOTE'
        Assert-True ($r7.FullDiscord -notmatch 'SECRET_OLD_12345' -and $r7.FullDiscord -notmatch 'SECRET_NEW_67890') 'Secrets redacted in Discord'
        Assert-True ($r7.ReleaseNote -match '%USERPROFILE%\\AppData\\Local\\Temp' -and $r7.ReleaseNote -notmatch 'C:\\Users\\Alice') 'C:\Users\<name> redacted to %USERPROFILE%'
        Assert-True ($r7.Greeting -match 'critical config notice|configuration changes') 'Critical greeting prioritized'
        Assert-True ($r7.Greeting -match 'Yui-sama''s birthday') 'Birthday line NOT suppressed when Critical config is active'
    } finally {
        [System.IO.File]::WriteAllText($wlPath, $origWl, [System.Text.UTF8Encoding]::new($false))
    }

    # Check malformed watchlist line emits an English warning
    $malTestDir = Join-Path $tmpRoot 'malformed_wl_check'
    New-Item -ItemType Directory -Path $malTestDir | Out-Null
    Push-Location -LiteralPath $malTestDir
    try {
        [System.IO.File]::WriteAllText($wlPath, "[Behaviour]`nBAD_LINE_TEST`n", [System.Text.UTF8Encoding]::new($false))
        $env:RELEASE_TAG = '20261126'
        $env:MOCK_DIFF_FILE = Join-Path $malTestDir 'empty.txt'
        [System.IO.File]::WriteAllText($env:MOCK_DIFF_FILE, '', [System.Text.UTF8Encoding]::new($false))
        $capturedWarnings = @()
        & $MakeChangelog -WarningVariable capturedWarnings 3>$null
        Assert-True (($capturedWarnings -join ' ') -match 'Malformed line') 'Malformed watchlist line produces English warning'
    } finally {
        Pop-Location
        [System.IO.File]::WriteAllText($wlPath, $origWl, [System.Text.UTF8Encoding]::new($false))
        Remove-Item Env:RELEASE_TAG, Env:MOCK_DIFF_FILE -ErrorAction SilentlyContinue
    }

    # 8. Assert locked user-audited windows (Kokkoro 6/1, Gourmet 1/0, Other Calendar 3/1) + Phase-aware Kokkoro BDay
    $gData = Import-PowerShellDataFile -LiteralPath (Join-Path $ScriptDir 'kokkoro_greetings.psd1')
    $kokkoroEv = @($gData.Calendar) | Where-Object { $_.Name -eq 'KokkoroBDay' } | Select-Object -First 1
    $gourmetEvs = @($gData.Calendar) | Where-Object { $_.Name -in 'PecorineBDay', 'KyaruBDay', 'SheffyBDay' }
    $otherEvs = @($gData.Calendar) | Where-Object { $_.Name -notin 'KokkoroBDay', 'PecorineBDay', 'KyaruBDay', 'SheffyBDay' }
    Assert-True ($kokkoroEv.WindowBefore -eq 6 -and $kokkoroEv.WindowAfter -eq 1) 'KokkoroBDay window locked to 6/1'
    Assert-True ((@($gourmetEvs | Where-Object { $_.WindowBefore -ne 1 -or $_.WindowAfter -ne 0 }).Count) -eq 0) 'Gourmet birthdays locked to 1/0'
    Assert-True ((@($otherEvs | Where-Object { $_.WindowBefore -ne 3 -or $_.WindowAfter -ne 1 }).Count) -eq 0) 'Other calendar events locked to 3/1'

    $r8Before = Invoke-Scenario -Name '08a_BDayBefore' -Tag '20260505' -PrevTag '20260420' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8Day    = Invoke-Scenario -Name '08b_BDayDay'    -Tag '20260511' -PrevTag '20260501' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8Day2   = Invoke-Scenario -Name '08b_BDayDayRep' -Tag '20260511' -PrevTag '20260501' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8DaySuf = Invoke-Scenario -Name '08b_BDayDaySuf' -Tag '20260511a' -PrevTag '20260511' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8After  = Invoke-Scenario -Name '08c_BDayAfter'  -Tag '20260512' -PrevTag '20260511' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($r8Before.Greeting -match 'approaches|draws near') 'Kokkoro H-6 uses LinesBefore'
    Assert-True ($r8Before.Greeting -match 'Kyouka-sama''s birthday') 'Kyouka-sama (May 5) appended as birthday line'
    Assert-True ($r8Day.Greeting -match 'today') 'Kokkoro Day 0 uses Lines'
    Assert-True ($r8Day.Greeting -eq $r8Day2.Greeting) 'Same tag produces identical greeting'
    Assert-True ($r8Day.Greeting -ne $r8DaySuf.Greeting) 'Different suffix produces different greeting'
    Assert-True ($r8After.Greeting -match 'wishes|passed') 'Kokkoro H+1 uses LinesAfter'

    # 9. Feb 14 & Feb 15 Additive Merge (Valentine + JPAnniv + Shizuru) + Twin Plural + No '-sama' on Kokkoro's Father
    $r9Feb14 = Invoke-Scenario -Name '09a_Feb14Merge' -Tag '20260214' -PrevTag '20260210' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r9Feb15 = Invoke-Scenario -Name '09b_Feb15Merge' -Tag '20260215' -PrevTag '20260214' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r9Twins = Invoke-Scenario -Name '09c_TwinPlural' -Tag '20260404' -PrevTag '20260331' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r9Dad   = Invoke-Scenario -Name '09d_KokkorosFather' -Tag '20260310' -PrevTag '20260307' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")

    Assert-True ($r9Feb14.Greeting -match 'Valentine''s Day' -and $r9Feb14.Greeting -match 'anniversary of our journey' -and $r9Feb14.Greeting -match 'Shizuru-sama''s birthday') 'Feb 14 merges Valentine + JPAnniv note + Shizuru birthday'
    Assert-True ($r9Feb15.Greeting -match 'anniversary|Landosol' -and $r9Feb15.Greeting -match 'Valentine still lingers') 'Feb 15 merges JPAnniv + Valentine note'
    Assert-True ($r9Twins.Greeting -match 'birthdays of Hatsune-sama and Shiori-sama') 'Twin birthdays use plural phrasing'
    Assert-True ($r9Dad.Greeting -match 'Kokkoro''s Father and Misogi-sama' -and $r9Dad.Greeting -notmatch 'Father-sama') 'No -sama appended to Kokkoro''s Father'

    # 10. Custom override + Non-src ignored
    $r10 = Invoke-Scenario -Name '10_CustomOverrideAndNonSrc' -Tag '20261127' -PrevTag '20261126' `
        -DiffLines @("M`t.github/workflows/release.yml", "M`tREADME.md") `
        -KokkoroInput 'Aruji-sama, custom override test message!'
    Assert-True (-not $r10.Data.HasChanges) 'Non-src changes ignored'
    Assert-True ($r10.Greeting -eq 'Aruji-sama, custom override test message!') 'Custom override respected'

    # 11. 500-Tag Fuzz + Worst-Case Multi-Event & 3-Birthday Stress Test
    Write-Output "`n--- Scenario: 11_500TagFuzzAndWorstCase ---"
    $fuzzOk = $true
    $surrOk = $true
    $baseDt = [DateTime]::new(2026, 1, 1)
    for ($i = 0; $i -lt 500; $i++) {
        $d = $baseDt.AddDays($i)
        $tStr = $d.ToString('yyyyMMdd')
        if ($i % 17 -eq 0) { $tStr += 'a' }
        $res = Invoke-Scenario -Name '11_Fuzz' -Tag $tStr -PrevTag '' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt") -Quiet
        if ($res.Greeting.Length -gt 380 -or $res.FullDiscord.Length -gt 2000) {
            $fuzzOk = $false
            Write-Warning "Fuzz budget breach on $tStr (greet=$($res.Greeting.Length), total=$($res.FullDiscord.Length))"
            break
        }
        if (-not (Test-NoLoneSurrogates $res.FullDiscord)) {
            $surrOk = $false
            Write-Warning "Lone surrogate found on $tStr"
            break
        }
    }
    Assert-True $fuzzOk 'All 500 synthetic tags stay within Greeting <= 380 and Discord <= 2000'
    Assert-True $surrOk 'Zero lone UTF-16 surrogates across all 500 synthetic tags'

    # 12. Parse all .psd1 files & verify zero Indonesian strings remain in bundle
    $psdFiles = @(Get-ChildItem -LiteralPath $ScriptDir -Filter '*.psd1')
    $allPsdValid = $true
    foreach ($pf in $psdFiles) {
        try { [void](Import-PowerShellDataFile -LiteralPath $pf.FullName) } catch { $allPsdValid = $false }
    }
    Assert-True ($psdFiles.Count -ge 4 -and $allPsdValid) "All $($psdFiles.Count) .psd1 files parse cleanly"

    $indoRegex = '\b(pengguna|perubahan|ulang tahun|seluruh|daftar|ketentuan|cara mengisi|hasil uji|skenario|perayaan)\b'
    $indoHits = @()
    foreach ($sf in @(Get-ChildItem -LiteralPath $ScriptDir -File)) {
        $txt = Get-Content -LiteralPath $sf.FullName -Raw -Encoding utf8
        if ($txt -match $indoRegex) { $indoHits += $sf.Name }
    }
    Assert-True ($indoHits.Count -eq 0) "Zero Indonesian text remains in .github/scripts (hits: $($indoHits -join ', '))"

} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "`n=========================================="
Write-Output "TEST RESULTS: $passed PASSED, $failed FAILED"
Write-Output "=========================================="
if ($failed -gt 0) { exit 1 }
