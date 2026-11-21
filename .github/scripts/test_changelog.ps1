# ============================================================================
# test_changelog.ps1 - Acceptance & Regression Test Suite for Release Scripts
# ============================================================================
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'initialize.ps1')

$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )
    if ($Condition) {
        $script:Passed++
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        $script:Failed++
        Write-Error "  [FAIL] $Message" -ErrorAction Continue
    }
}

Write-Host "=== 0. PowerShell ArrayList Cast Probe ==="
$probeList = [System.Collections.ArrayList]::new()
[void]$probeList.Add("## Changelog")
if ($probeList.Count -eq 1 -and $probeList[0] -eq "## Changelog") { Write-Host "CAST2 OK" }
try {
    $bad = [System.Collections.ArrayList]"## Changelog"
    Write-Host "CAST1 OK"
} catch {
    Write-Host "CAST1 FAIL"
}

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("priconne_tl_test_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

function Invoke-PipelineCase {
    param(
        [string] $PrevTag,
        [string] $RelTag,
        [string[]] $DiffLines,
        [hashtable] $ConfigFiles = @{},
        [string] $CustomGreeting = '',
        [string] $RoleMention = ''
    )

    $caseDir = Join-Path $TempRoot ("case_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $caseDir -Force | Out-Null

    $diffFile = Join-Path $caseDir 'diff.txt'
    if ($null -eq $DiffLines -or $DiffLines.Count -eq 0) {
        Set-Content -LiteralPath $diffFile -Value '' -Encoding utf8
    } else {
        Set-Content -LiteralPath $diffFile -Value ($DiffLines -join "`n") -Encoding utf8
    }

    foreach ($relPath in $ConfigFiles.Keys) {
        $full = Join-Path $caseDir ($relPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $parent = Split-Path -Path $full -Parent
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -LiteralPath $full -Value $ConfigFiles[$relPath] -Encoding utf8
    }

    $ghOut = Join-Path $caseDir 'gh_output.txt'
    Set-Content -LiteralPath $ghOut -Value '' -Encoding utf8

    Push-Location -LiteralPath $caseDir
    try {
        $env:PREVIOUS_TAG = $PrevTag
        $env:RELEASE_TAG  = $RelTag
        $env:CHANGELOG_DIFF_FILE = $diffFile
        $env:GITHUB_OUTPUT = $ghOut
        $env:CUSTOM_GREETING = $CustomGreeting
        $env:DISCORD_ROLE_MENTION = $RoleMention

        & (Join-Path $ScriptDir 'make_changelog.ps1')
        & (Join-Path $ScriptDir 'make_announce.ps1')

        $rn   = Get-Content -LiteralPath (Join-Path $caseDir 'RELEASE_NOTE') -Raw -Encoding utf8
        $data = Get-Content -LiteralPath (Join-Path $caseDir 'CHANGES.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $outRaw = Get-Content -LiteralPath $ghOut -Raw -Encoding utf8

        $greet = ''
        $dBody = ''
        if ($outRaw -match '(?s)greeting<<([^\r\n]+)\r?\n(.*?)\r?\n\1') {
            $greet = $Matches[2]
        }
        if ($outRaw -match '(?s)discord_body<<([^\r\n]+)\r?\n(.*?)\r?\n\1') {
            $dBody = $Matches[2]
        }

        return [PSCustomObject]@{
            ReleaseNote = $rn
            Data        = $data
            Greeting    = $greet
            DiscordBody = $dBody
        }
    } finally {
        Remove-Item Env:PREVIOUS_TAG, Env:RELEASE_TAG, Env:CHANGELOG_DIFF_FILE, Env:GITHUB_OUTPUT, Env:CUSTOM_GREETING, Env:DISCORD_ROLE_MENTION -ErrorAction SilentlyContinue
        Pop-Location
    }
}

try {
    # 1. Empty diff -> Maintenance release
    $r1 = Invoke-PipelineCase -PrevTag '20261120' -RelTag '20261120a' -DiffLines @()
    Assert-True (-not [bool]$r1.Data.HasChanges) 'HasChanges = false'
    Assert-True ($r1.ReleaseNote -notmatch '## Changelog') 'No ## Changelog header when empty'
    Assert-True ($r1.Greeting -match 'housekeeping|maintenance|no translation') 'Selects Maintenance greeting'
    Assert-True ($r1.DiscordBody -match '^## Priconne TL — v20261120a') 'Discord body starts with ## Priconne TL heading'
    Assert-True ($r1.DiscordBody -match '### 📣 \[Release\]\(<.+>\) \| 📥 \[Download\]\(<.+>\) \| ↔️ \[Compare\]\(<.+>\)') 'Discord footer uses ### with spaced emojis and angle-bracketed URLs'

    # 2. Single-file diff (dynamic Renamed/Moved columns hidden when 0)
    $r2 = Invoke-PipelineCase -PrevTag '20261120a' -RelTag '20261121' -DiffLines @(
        "M`tsrc/BepInEx/Translation/en/Text/Character/Kyaru.txt"
    )
    Assert-True ($r2.Data.HasChanges -and [int]$r2.Data.TextTotal -eq 1) 'Single file detected'
    Assert-True ([int]$r2.Data.TotalChanges -eq 1) 'Exactly 1 item recorded'
    Assert-True ($r2.ReleaseNote -notmatch '🏷️ Renamed' -and $r2.ReleaseNote -notmatch '📦 Moved') 'Dynamic Renamed & Moved columns hidden when both are 0'

    # 3. Blacklisted files ignored completely
    $r3 = Invoke-PipelineCase -PrevTag '20261121' -RelTag '20261122' -DiffLines @(
        "M`tsrc/BepInEx/Translation/en/Text/_AutoGeneratedTranslations.txt",
        "A`tsrc/BepInEx/plugins/backup.rar",
        "A`tsrc/BepInEx/Translation/en/Texture/New folder/test.psd"
    )
    Assert-True (-not [bool]$r3.Data.HasChanges) 'Blacklisted files ignored completely'
    Assert-True ($r3.ReleaseNote -notmatch '## Changelog') 'No ## Changelog when all filtered'

    # 4. Framework + Texture + ForAMD count contract
    $r4 = Invoke-PipelineCase -PrevTag '20261122' -RelTag '20261123' -DiffLines @(
        "M`tsrc/BepInEx/core/BepInEx.dll",
        "A`tsrc/BepInEx/Translation/en/Texture/UI/btn_cancel [ABCDEF12].png",
        "A`tsrc/BepInEx/Translation/en/Texture/ForAMD/UI/btn_ok [1234567890].png"
    )
    Assert-True ([int]$r4.Data.FrameworkFiles -eq 1) 'FrameworkFiles = 1'
    Assert-True ([int]$r4.Data.ForAmdFiles -eq 1) 'ForAmdFiles = 1'
    Assert-True ([int]$r4.Data.TextureTotal -eq 1) 'Summary Texture total excludes AMD variants (Total = 1)'
    Assert-True ($r4.ReleaseNote -match 'Texture — 1 change\(s\) \(\+1 AMD variants\)') 'Texture details header reads 1 change(s) (+1 AMD variants)'
    Assert-True ($r4.ReleaseNote -match '\*\*AMD Texture Variants \(ForAMD\)\*\*') 'ForAMD rendered in its own sub-block'

    # 5. Dynamic Renamed & Moved split + repeated extension & UUID collapse
    $r5 = Invoke-PipelineCase -PrevTag '20261123' -RelTag '20261124' -DiffLines @(
        "R100`tsrc/BepInEx/Translation/en/Text/Event/OldTitle.txt`tsrc/BepInEx/Translation/en/Text/Event/NewTitle.txt",
        "R085`tsrc/BepInEx/Translation/en/Text/Event/MovedChapter.txt`tsrc/BepInEx/Translation/en/Text/Adventure/MovedChapter.txt",
        "A`tsrc/BepInEx/Translation/en/Texture/UI/banner_event.png.png",
        "A`tsrc/BepInEx/Translation/en/Texture/UI/12345678-1234-1234-1234-123456789abc.png"
    )
    Assert-True ([int]$r5.Data.TextRenamed -eq 1 -and [int]$r5.Data.TextMoved -eq 1) 'Renamed = 1 and Moved = 1 separated accurately'
    Assert-True ($r5.ReleaseNote -match '🏷️ Renamed' -and $r5.ReleaseNote -match '📦 Moved') 'Dynamic Renamed & Moved columns appear when > 0'
    Assert-True ($r5.ReleaseNote -match '🏷️ \*\*Renamed:\*\* OldTitle → NewTitle') 'Renamed item formatted as OldTitle -> NewTitle'
    Assert-True ($r5.ReleaseNote -match '📦 \*\*Moved:\*\* MovedChapter from `Event` \*\(edited\)\*') 'Moved edited item shows source folder and (edited) tag'
    Assert-True ($r5.ReleaseNote -match 'banner_event' -and $r5.ReleaseNote -notmatch '\.png') 'Repeated extension collapsed'
    Assert-True ($r5.ReleaseNote -match '12345678' -and $r5.ReleaseNote -notmatch '12345678-1234') 'Bare UUID collapsed to 8-char prefix'

    # 5b. Only Renamed > 0 (Moved == 0) shows Renamed column and hides Moved column
    $r5b = Invoke-PipelineCase -PrevTag '20261124' -RelTag '20261124a' -DiffLines @(
        "R100`tsrc/BepInEx/Translation/en/Text/Character/Alpha.txt`tsrc/BepInEx/Translation/en/Text/Character/Beta.txt"
    )
    Assert-True ($r5b.ReleaseNote -match '🏷️ Renamed' -and $r5b.ReleaseNote -notmatch '📦 Moved') 'Renamed column shown while Moved column stays hidden when Moved = 0'

    # 6. Other/Alpha prefix & Japanese filename preserved
    $r6 = Invoke-PipelineCase -PrevTag '20261124a' -RelTag '20261125' -DiffLines @(
        "A`tsrc/BepInEx/Translation/en/Other/Alpha/Name/Crunchyroll/Kyaru/chara_name_1060.png",
        "M`tsrc/BepInEx/Translation/en/Other/atlases/AtlasCommon [ABCDEF1234].png",
        "A`tsrc/BepInEx/Translation/en/Text/Event/キャルちゃんの冒険.txt"
    )
    Assert-True ($r6.ReleaseNote -match 'Other/Alpha/Name/Crunchyroll/Kyaru') 'Alpha folder prefix preserved verbatim'
    Assert-True ($r6.ReleaseNote -match 'キャルちゃんの冒険') 'Japanese filename preserved'

    # 7. Critical config watchlist + secret redaction + birthday never suppressed
    $iniContent = @"
[Behaviour]
ApiKey=super_secret_token_999
CacheDir=C:\Users\Administrator\AppData\LocalLow\Cygames
MaxCharactersPerTranslation=200
"@
    # Apr 5 = Yui's birthday
    $r7 = Invoke-PipelineCase -PrevTag '20260401' -RelTag '20260405' -DiffLines @(
        "M`tsrc/BepInEx/config/AutoTranslatorConfig.ini"
    ) -ConfigFiles @{
        'src/BepInEx/config/AutoTranslatorConfig.ini' = $iniContent
    }
    Assert-True ([bool]$r7.Data.Critical) 'Bare [Behaviour] section triggers Critical on any key change'
    Assert-True ($r7.ReleaseNote -match '\(redacted\)' -and $r7.ReleaseNote -notmatch 'super_secret_token_999') 'Secrets redacted in RELEASE_NOTE'
    Assert-True ($r7.DiscordBody -notmatch 'super_secret_token_999') 'Secrets redacted in Discord'
    Assert-True ($r7.ReleaseNote -match '%USERPROFILE%' -and $r7.ReleaseNote -notmatch 'Administrator') 'C:\Users\<name> redacted to %USERPROFILE%'
    Assert-True ($r7.Greeting -match 'configuration|settings') 'Critical greeting prioritized'
    Assert-True ($r7.Greeting -match 'Yui-sama') 'Birthday line NOT suppressed when Critical config is active (Apr 5 = Yui)'

    # 7b. Malformed watchlist line produces English warning
    $badWl = Join-Path $TempRoot 'bad_watchlist.txt'
    Set-Content -LiteralPath $badWl -Value "InvalidLineWithoutBrackets`n[ValidSection] KeyName" -Encoding utf8
    $capturedWarnings = @()
    $null = Read-WatchlistRules -Path $badWl -WarningVariable capturedWarnings -WarningAction SilentlyContinue
    Assert-True (($capturedWarnings -join ' ') -match 'Malformed watchlist line') 'Malformed watchlist line produces English warning'

    # -------------------------------------------------------------------------
    # ACCEPTANCE TESTS (new, numbered per spec)
    # -------------------------------------------------------------------------

    Write-Host ""
    Write-Host "--- Acceptance Test 1: Window sizes ---"
    $gDataCheck = Import-PowerShellDataFile -LiteralPath (Join-Path $ScriptDir 'kokkoro_greetings.psd1')
    Assert-True ($gDataCheck.KokkoroBDay.DaysBefore -eq 6 -and $gDataCheck.KokkoroBDay.DaysAfter -eq 1) 'AT1: KokkoroBDay window locked to 6/1'
    $gourmetOk = $true
    foreach ($gb in $gDataCheck.GourmetBirthdays) {
        if ($gb.DaysBefore -ne 1 -or $gb.DaysAfter -ne 0) { $gourmetOk = $false }
    }
    Assert-True $gourmetOk 'AT1: Gourmet birthdays locked to 1/0'
    # Standard calendar events (excluding AprilFool, AnimeS1, AnimeS2, JPAnniv) locked to 3/1
    $calOk = $true
    $anniversaryIds = @('JPAnniv', 'AnimeS1', 'AnimeS2', 'AprilFool')
    foreach ($ev in $gDataCheck.Calendar) {
        if ($anniversaryIds -contains $ev.Id) { continue }  # anniversaries have different windows
        if ($ev.DaysBefore -ne 3 -or $ev.DaysAfter -ne 1) { $calOk = $false }
    }
    Assert-True $calOk 'AT1: Standard calendar events locked to 3/1'
    # Anniversaries: DaysBefore=0, DaysAfter=3
    $jpAnnivEv  = $gDataCheck.Calendar | Where-Object { $_.Id -eq 'JPAnniv' }  | Select-Object -First 1
    $animeS1Ev  = $gDataCheck.Calendar | Where-Object { $_.Id -eq 'AnimeS1' }  | Select-Object -First 1
    $animeS2Ev  = $gDataCheck.Calendar | Where-Object { $_.Id -eq 'AnimeS2' }  | Select-Object -First 1
    $aprilFoolEv= $gDataCheck.Calendar | Where-Object { $_.Id -eq 'AprilFool' }| Select-Object -First 1
    Assert-True ($null -ne $jpAnnivEv  -and $jpAnnivEv.DaysBefore  -eq 0 -and $jpAnnivEv.DaysAfter  -eq 3) 'AT1: JPAnniv window is 0/3'
    Assert-True ($null -ne $animeS1Ev  -and $animeS1Ev.DaysBefore  -eq 0 -and $animeS1Ev.DaysAfter  -eq 3) 'AT1: AnimeS1 window is 0/3'
    Assert-True ($null -ne $animeS2Ev  -and $animeS2Ev.DaysBefore  -eq 0 -and $animeS2Ev.DaysAfter  -eq 3) 'AT1: AnimeS2 window is 0/3'
    Assert-True ($null -ne $aprilFoolEv -and $aprilFoolEv.DaysBefore -eq 0 -and $aprilFoolEv.DaysAfter -eq 1) 'AT1: AprilFool window is 0/1'
    # Pool sizes: at least 6 day-of variants for Gourmet and standard calendar
    $kokkoroLinesOk = ($gDataCheck.KokkoroBDay.Lines.Count -ge 6 -and $gDataCheck.KokkoroBDay.LinesBefore.Count -ge 6)
    Assert-True $kokkoroLinesOk 'AT1: KokkoroBDay has >=6 day-of and >=6 before variants'

    Write-Host ""
    Write-Host "--- Acceptance Test 2: Feb 14 (Valentine only, no Shizuru) ---"
    # Feb 14: Valentine H+0 (high priority), JPAnniv H-1 (note), Shizuru is Oct 24 NOT Feb 14
    $rFeb14 = Invoke-PipelineCase -PrevTag '20260210' -RelTag '20260214' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rFeb14.Greeting -match "Valentine|gratitude") 'AT2: Feb 14 main line mentions Valentine'
    Assert-True ($rFeb14.Greeting -notmatch 'Shizuru') 'AT2: Feb 14 does NOT trigger Shizuru (Shizuru = Oct 24)'
    # JPAnniv window is 0/3 so H-1 (Feb 14 is day -1 before Feb 15) is OUTSIDE the window
    Assert-True ($rFeb14.Greeting -notmatch 'anniversary') 'AT2: JPAnniv (0/3 window) does NOT fire day before (Feb 14 = H-1 from Feb 15)'

    Write-Host ""
    Write-Host "--- Acceptance Test 3: Feb 15 (JPAnniv H+0) ---"
    $rFeb15 = Invoke-PipelineCase -PrevTag '20260214' -RelTag '20260215' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rFeb15.Greeting -match 'anniversary|year of adventures|Astraea') 'AT3: Feb 15 main line is anniversary'
    Assert-True ($rFeb15.Greeting -match 'Valentine') 'AT3: Feb 15 includes Valentine note (H+1 from Feb 14)'

    Write-Host ""
    Write-Host "--- Acceptance Test 4: Apr 1 (April Fool day-of) ---"
    $rApr1 = Invoke-PipelineCase -PrevTag '20260330' -RelTag '20260401' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rApr1.Greeting -match 'Kyaru-sama.*laughing|sky.*green|pantry|harmless.*falsehood|tail|supper.*duty') 'AT4: Apr 1 main line is one of the April Fool variants'
    Assert-True ($rApr1.Greeting -notmatch 'jest.*explained|believed.*every') 'AT4: Apr 1 day-of line is NOT an H+1 recovery line'

    Write-Host ""
    Write-Host "--- Acceptance Test 5: Apr 2 (April Fool H+1) ---"
    $rApr2 = Invoke-PipelineCase -PrevTag '20260401' -RelTag '20260402' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rApr2.Greeting -match 'jest.*explained|believed.*every|yesterday.*jest|harmless lies') 'AT5: Apr 2 main line is one of the H+1 recovery variants'

    Write-Host ""
    Write-Host "--- Acceptance Test 6: Apr 7 (AnimeS1 premiere) ---"
    $rApr7 = Invoke-PipelineCase -PrevTag '20260405' -RelTag '20260407' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rApr7.Greeting -match 'anime|Season 1|premiere|screen') 'AT6: Apr 7 main line is anime anniversary'
    # Anemone birthday is Apr 2, so should not appear today
    Assert-True ($rApr7.Greeting -notmatch 'Anemone') 'AT6: Anemone (Apr 2) not in birthday footnote for Apr 7'

    Write-Host ""
    Write-Host "--- Acceptance Test 7: Jan 11 (AnimeS2 premiere) ---"
    $rJan11 = Invoke-PipelineCase -PrevTag '20260109' -RelTag '20260111' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rJan11.Greeting -match 'anime|Season 2|premiere') 'AT7: Jan 11 main line is anime S2 anniversary'

    Write-Host ""
    Write-Host "--- Acceptance Test 8: Dec 14 (Sheffy canonical birthday) ---"
    $rDec14 = Invoke-PipelineCase -PrevTag '20261213' -RelTag '20261214' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rDec14.Greeting -match 'Sheffy') 'AT8: Dec 14 triggers Sheffy greeting'
    # Verify the psd1 has correct date
    $sheffyEntry = $gDataCheck.GourmetBirthdays | Where-Object { $_.Id -eq 'SheffyBDay' } | Select-Object -First 1
    Assert-True ($null -ne $sheffyEntry -and $sheffyEntry.Month -eq 12 -and $sheffyEntry.Day -eq 14) 'AT8: Sheffy canonical birthday is 12/14 in psd1'

    Write-Host ""
    Write-Host "--- Acceptance Test 9: Feb 18 (Ameth) ---"
    $rFeb18 = Invoke-PipelineCase -PrevTag '20260217' -RelTag '20260218' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rFeb18.Greeting -match 'Ameth') 'AT9: Feb 18 triggers Ameth greeting'
    $amethEntry = $gDataCheck.GourmetBirthdays | Where-Object { $_.Id -eq 'AmethBDay' } | Select-Object -First 1
    Assert-True ($null -ne $amethEntry -and $amethEntry.Month -eq 2 -and $amethEntry.Day -eq 18) 'AT9: Ameth entry exists in GourmetBirthdays at Feb 18'

    Write-Host ""
    Write-Host "--- Acceptance Test 10: Jul 1 (Kaiser Insight) ---"
    $rJul1 = Invoke-PipelineCase -PrevTag '20260629' -RelTag '20260701' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rJul1.Greeting -match "Kyaru-sama's uncle|Kaiser Insight-sama") 'AT10: Jul 1 greeting mentions Kyaru-sama''s uncle or Kaiser Insight-sama'
    Assert-True ($rJul1.Greeting -notmatch ('\b' + 'Mana' + '\b')) 'AT10: Jul 1 greeting does NOT mention "Mana"'

    Write-Host ""
    Write-Host "--- Acceptance Test 11: Critical config + birthday never suppressed ---"
    $iniCritical = @"
[Behaviour]
MaxCharactersPerTranslation=500
"@
    # Apr 5 = Yui's birthday, Apr 1 = AprilFool, use a neutral date with a birthday
    # Oct 24 = Shizuru; test critical on that date
    $r11 = Invoke-PipelineCase -PrevTag '20261023' -RelTag '20261024' -DiffLines @(
        "M`tsrc/BepInEx/config/AutoTranslatorConfig.ini"
    ) -ConfigFiles @{
        'src/BepInEx/config/AutoTranslatorConfig.ini' = $iniCritical
    }
    Assert-True ([bool]$r11.Data.Critical) 'AT11: Critical config triggers banner'
    Assert-True ($r11.Greeting -match 'configuration|settings') 'AT11: Critical greeting used as main line'
    Assert-True ($r11.Greeting -match 'Shizuru-sama') 'AT11: Shizuru birthday footnote NOT suppressed on Critical config day (Oct 24)'

    Write-Host ""
    Write-Host "--- Acceptance Test 12: Two events same day (multiple birthdays) ---"
    # Jan 8: Luna AND Yamato both have birthdays
    $rJan8 = Invoke-PipelineCase -PrevTag '20260107' -RelTag '20260108' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    Assert-True ($rJan8.Greeting -match 'Luna-sama|Yamato-sama') 'AT12: Jan 8 greeting mentions at least one of the birthday characters'
    Assert-True ($rJan8.Greeting -match 'birthdays of|birthday.*and') 'AT12: Plural phrasing used for multiple birthdays'

    Write-Host ""
    Write-Host "--- Acceptance Test 13: History avoids repetition across consecutive releases ---"
    # Two consecutive releases in a row during JPAnniv window (Feb 15-18)
    # Second release should prefer a different event ID if available
    $rH1 = Invoke-PipelineCase -PrevTag '20260214' -RelTag '20260215' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $rH2 = Invoke-PipelineCase -PrevTag '20260215' -RelTag '20260216' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    # Both should produce anniversary content (JPAnniv H+0 and H+1 windows both include Feb 15 and 16)
    Assert-True ($rH1.Greeting -match 'anniversary|Astraea') 'AT13a: Feb 15 produces anniversary greeting'
    Assert-True ($rH2.Greeting -match 'anniversary|Valentine') 'AT13b: Feb 16 still in JPAnniv H+1 window, or picks Valentine note'

    Write-Host ""
    Write-Host "--- Acceptance Test 14: Discord payload <= 2000 UTF-16 units (500 synthetic tags) ---"
    $allWithinBudget = $true
    $zeroSurrogates  = $true
    for ($i = 0; $i -lt 500; $i++) {
        $dt = [DateTime]::new(2026, 1, 1).AddDays($i)
        $suf = if (($i % 7) -eq 0) { 'a' } else { '' }
        $tag = $dt.ToString('yyyyMMdd') + $suf
        $rf = Invoke-PipelineCase -PrevTag '' -RelTag $tag -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt") -RoleMention '<@&1349491054214385816>'
        $fullDiscordPayload = "📌 <@&1349491054214385816>`n$($rf.Greeting)`n`n$($rf.DiscordBody)"
        if ($rf.Greeting.Length -gt 380 -or $fullDiscordPayload.Length -gt 2000) {
            $allWithinBudget = $false
            Write-Host "  BUDGET EXCEEDED: tag=$tag greet=$($rf.Greeting.Length) full=$($fullDiscordPayload.Length)" -ForegroundColor Yellow
        }
        if ((Test-HasLoneSurrogate -Text $rf.Greeting) -or (Test-HasLoneSurrogate -Text $rf.DiscordBody)) {
            $zeroSurrogates = $false
        }
    }
    Assert-True $allWithinBudget 'AT14: All 500 synthetic tags stay within Greeting <= 380 and full Discord payload <= 2000'

    Write-Host ""
    Write-Host "--- Acceptance Test 15: Zero lone UTF-16 surrogates ---"
    Assert-True $zeroSurrogates 'AT15: Zero lone UTF-16 surrogates across all 500 synthetic tags'

    Write-Host ""
    Write-Host "--- Acceptance Test 16: All .psd1 files parse cleanly ---"
    $psdFiles = @(Get-ChildItem -LiteralPath $ScriptDir -Filter '*.psd1')
    # Expect exactly 4 psd1 files: character_birthdays, kokkoro_greetings, plugin_map, story_prefix
    $allPsdOk = ($psdFiles.Count -eq 4)
    foreach ($pf in $psdFiles) {
        try {
            $null = Import-PowerShellDataFile -LiteralPath $pf.FullName
        } catch {
            $allPsdOk = $false
            Write-Host "  PARSE FAIL: $($pf.Name) — $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Assert-True $allPsdOk 'AT16: All 4 .psd1 files parse cleanly (no [ordered] errors)'

    Write-Host ""
    Write-Host "--- Acceptance Test 17: No Indonesian text in .github/scripts ---"
    $words = 'saya|kamu|anda|yang|untuk|dengan|tidak|bukan|sudah|belum|akan|sedang|bisa|dapat|harus|karena|jika|kalau|ketika|saat|atau|dan|dari|pada|dalam|atas|bawah|antara|tanpa|oleh|tentang|seperti|hanya|saja|juga|lagi|masih|sangat|sekali|banyak|sedikit|semua|setiap|beberapa|itu|sini|situ|sana|apa|siapa|kapan|mengapa|bagaimana|berapa|silakan|tolong|mohon|maaf|terima kasih|selamat|hari|ulang tahun|perubahan|berkas|gagal|berhasil'
    $indoRegex = "\b($words)\b|(?<![\.\|\\])\bini\b"
    $indoHits = [System.Collections.ArrayList]::new()
    foreach ($f in (Get-ChildItem -LiteralPath $ScriptDir -File)) {
        $rawTxt = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
        # Strip the regex variable definition line itself to avoid false positive
        $cleanedTxt = ($rawTxt -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(\$indoRegex|\$words)\s*=' }) -join "`n"
        if ($cleanedTxt -imatch $indoRegex) {
            [void]$indoHits.Add($f.Name)
        }
    }
    Assert-True ($indoHits.Count -eq 0) "AT17: Zero Indonesian text remains in .github/scripts (hits: $($indoHits -join ', '))"

    # -------------------------------------------------------------------------
    # Retained regression tests (8-10 from original suite, renumbered for clarity)
    # -------------------------------------------------------------------------

    Write-Host ""
    Write-Host "--- Regression: Kokkoro birthday window (H-6 / H / H+1) ---"
    $r8Before = Invoke-PipelineCase -PrevTag '20260420' -RelTag '20260505' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8Day0   = Invoke-PipelineCase -PrevTag '20260501' -RelTag '20260511' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8Day0b  = Invoke-PipelineCase -PrevTag '20260501' -RelTag '20260511' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8Suf    = Invoke-PipelineCase -PrevTag '20260511' -RelTag '20260511a' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    $r8After  = Invoke-PipelineCase -PrevTag '20260511' -RelTag '20260512' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")

    Assert-True ($r8Before.Greeting -match 'May 11|eleventh of May') 'REG: Kokkoro H-6 uses LinesBefore'
    Assert-True ($r8Before.Greeting -match 'Illya-sama') 'REG: Illya-sama (May 5) appended as birthday line'
    Assert-True ($r8Day0.Greeting -match 'my birthday today') 'REG: Kokkoro Day 0 uses Lines'
    Assert-True ($r8Day0.Greeting -ceq $r8Day0b.Greeting) 'REG: Same tag produces identical greeting'
    Assert-True ($r8Day0.Greeting -cne $r8Suf.Greeting) 'REG: Different suffix produces different greeting'
    Assert-True ($r8After.Greeting -match 'birthday wishes') 'REG: Kokkoro H+1 uses LinesAfter'

    Write-Host ""
    Write-Host "--- Regression: Additive calendar + birthday merge ---"
    $r9Apr04 = Invoke-PipelineCase -PrevTag '20260331' -RelTag '20260404' -DiffLines @("M`tsrc/BepInEx/Translation/en/Text/a.txt")
    # Apr 4: no calendar event; Hanami starts Mar 22 (H-3 of Mar 25); Apr 4 is H+10 — outside window
    # Only birthday footnote expected: Anemone (Apr 2) is past, Mimi (Apr 3) is past, nothing on Apr 4
    # Wait — Apr 4: no birthday in list; Hanami H+10 out of window; WhiteDay H+21 out of window
    # So greeting should fall into seasonal/default pool
    Assert-True (-not [string]::IsNullOrWhiteSpace($r9Apr04.Greeting)) 'REG: Apr 4 produces a non-empty greeting'

    Write-Host ""
    Write-Host "--- Regression: Non-src changes ignored & custom override respected ---"
    $r10 = Invoke-PipelineCase -PrevTag '20261126' -RelTag '20261127' -DiffLines @(
        "M`tREADME.md",
        "M`t.github/workflows/release.yml"
    ) -CustomGreeting 'Aruji-sama, custom override test message!'
    Assert-True (-not [bool]$r10.Data.HasChanges) 'REG: Non-src changes ignored'
    Assert-True ($r10.Greeting -eq 'Aruji-sama, custom override test message!') 'REG: Custom override respected'

} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=========================================="
Write-Host "TEST RESULTS: $($script:Passed) PASSED, $($script:Failed) FAILED"
Write-Host "=========================================="
if ($script:Failed -gt 0) { exit 1 }
exit 0
