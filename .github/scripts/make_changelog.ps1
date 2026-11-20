# ============================================================
#  make_changelog.ps1 — Structured Changelog & CHANGES.json
# ============================================================
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = $PSScriptRoot
$TransRoot = 'src/BepInEx/Translation/en/'

# ---------- Safe Text Helpers (Surrogate-Safe) ----------
function Limit-SafeText {
    param([string]$Text, [int]$MaxLen)
    if ($null -eq $Text) { return '' }
    if ($MaxLen -lt 2) { return '' }
    if ($Text.Length -le $MaxLen) { return $Text }

    # Strip non-ASCII symbols/emojis before falling back to hard substring
    $clean = ($Text -replace '[^\x20-\x7E\u00A0-\u024F\u3000-\u9FFF\uFF00-\uFFEF]', '').Trim()
    if ($clean.Length -le $MaxLen) { return $clean }

    $cut = $MaxLen - 1
    if ($cut -gt 0 -and [char]::IsHighSurrogate($clean[$cut - 1])) {
        $cut--
    }
    return ($clean.Substring(0, $cut).TrimEnd() + '…')
}

function Redact-ConfigValue {
    param([string]$Key, [string]$Value)
    if ($null -eq $Value) { return '' }
    if ($Key -match '(?i)api_?key|token|secret|password' -or $Value -match '(?i)api_?key|token|secret|password') {
        return '(redacted)'
    }
    $redacted = $Value -replace '(?i)[A-Z]:\\Users\\[^\\\s]+', '%USERPROFILE%'
    if ($redacted.Length -gt 60) {
        return (Limit-SafeText -Text $redacted -MaxLen 60)
    }
    return $redacted
}

# ---------- Load External Data Files ----------
function Get-BlacklistPattern {
    $f = Join-Path $ScriptDir 'changelog_blacklist.txt'
    if (-not (Test-Path -LiteralPath $f)) { return $null }
    $p = @(Get-Content -LiteralPath $f -Encoding utf8 | ForEach-Object { $_.Trim() } |
           Where-Object { $_ -and -not $_.StartsWith('#') })
    if ($p.Count -eq 0) { return $null }
    return ($p -join '|')
}

$PluginMap = @()
$pmFile = Join-Path $ScriptDir 'plugin_map.psd1'
if (Test-Path -LiteralPath $pmFile) {
    $pmData = Import-PowerShellDataFile -LiteralPath $pmFile
    if ($pmData -and $pmData.Plugins) { $PluginMap = @($pmData.Plugins) }
}

$StoryPrefix = @{ '0' = 'Main Story'; '1' = 'Character Story'; '2' = 'Event Story' }
$spFile = Join-Path $ScriptDir 'story_prefix.psd1'
if (Test-Path -LiteralPath $spFile) {
    $spData = Import-PowerShellDataFile -LiteralPath $spFile
    if ($spData -and $spData.Prefixes) { $StoryPrefix = $spData.Prefixes }
}

$WatchList = @()
$wlFile = Join-Path $ScriptDir 'config_watchlist.txt'
if (Test-Path -LiteralPath $wlFile) {
    $lineNo = 0
    foreach ($line in @(Get-Content -LiteralPath $wlFile -Encoding utf8)) {
        $lineNo++
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        if ($t -match '^\[([^\[\]]+)\]$') {
            $WatchList += [pscustomobject]@{ Section = $Matches[1].Trim(); Key = $null }
        } elseif ($t -match '^\[([^\[\]]+)\]\s+(\S.*)$') {
            $WatchList += [pscustomobject]@{ Section = $Matches[1].Trim(); Key = $Matches[2].Trim() }
        } else {
            Write-Warning "Malformed line $lineNo in config_watchlist.txt ignored: '$t'"
        }
    }
}

# ---------- Previous Tag Resolution & Git Diff ----------
function Get-PreviousTag {
    param([string]$ExcludeTag)
    if ($env:PREVIOUS_TAG) { return $env:PREVIOUS_TAG.Trim() }
    $desc = @(git describe --tags --abbrev=0 --match "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*" --exclude="$ExcludeTag" HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $desc.Count -gt 0 -and $desc[0]) {
        $baseTag = $desc[0].Trim()
        $commit  = (git rev-list -n 1 $baseTag 2>$null | Select-Object -First 1)
        if ($commit) {
            $same = @(git tag --points-at $commit | Where-Object { $_ -match '^\d{8}[a-z]?$' -and $_ -ne $ExcludeTag })
            if ($same.Count -gt 0) { return ($same | Sort-Object -Descending | Select-Object -First 1) }
        }
        return $baseTag
    }
    $tags = @(git for-each-ref --sort=-refname --sort=-creatordate --format='%(refname:short)' refs/tags)
    return ($tags | Where-Object { $_ -match '^\d{8}[a-z]?$' -and $_ -ne $ExcludeTag } | Select-Object -First 1)
}

function Parse-DiffLines {
    param(
        [string[]]$RawLines,
        [string]$BlacklistPattern
    )
    $out = @()
    foreach ($line in @($RawLines)) {
        if (-not $line -or -not $line.Trim()) { continue }
        $parts = $line -split "`t"
        $st = $parts[0].Trim()
        if (-not $st) { continue }
        $code = $st.Substring(0, 1)

        if ($code -eq 'R' -or $code -eq 'C') {
            $score = 0
            if ($st.Length -gt 1) { [void][int]::TryParse($st.Substring(1), [ref]$score) }
            if ($code -eq 'R' -and $score -ge 100) { continue }   # R100 = pure move without edits -> omit
            $path = if ($parts.Count -ge 3) { $parts[2] } else { $parts[1] }
            $action = if ($code -eq 'C') { 'Added' } else { 'Updated' }
            $moved  = ($code -eq 'R')
        } else {
            $path  = if ($parts.Count -ge 2) { $parts[1] } else { '' }
            $moved = $false
            $action = switch ($code) {
                'A'     { 'Added' }
                'D'     { 'Deleted' }
                default { 'Updated' }
            }
        }

        if (-not $path) { continue }
        if ($BlacklistPattern -and $path -match $BlacklistPattern) { continue }
        if (-not $path.StartsWith('src/')) { continue }
        $out += [pscustomobject]@{ Action = $action; Path = $path; Moved = $moved }
    }
    return @($out)
}

function Get-DiffChanges {
    param([string]$PreviousTag)
    if ($env:MOCK_DIFF_FILE -and (Test-Path -LiteralPath $env:MOCK_DIFF_FILE)) {
        $raw = @(Get-Content -LiteralPath $env:MOCK_DIFF_FILE -Encoding utf8)
        return @(Parse-DiffLines -RawLines $raw -BlacklistPattern (Get-BlacklistPattern))
    }
    if (-not $PreviousTag) {
        Write-Warning 'No PREVIOUS_TAG found — treating diff as empty.'
        return @()
    }
    $raw = @(git -c core.quotepath=off diff --name-status -M $PreviousTag HEAD)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git diff failed (exit code $LASTEXITCODE)"
        return @()
    }
    return @(Parse-DiffLines -RawLines $raw -BlacklistPattern (Get-BlacklistPattern))
}

# ---------- Filename Normalization & Categorization ----------
function Format-CleanItemName([string]$leaf) {
    $n = $leaf.Trim().TrimEnd('.', ' ')
    # Collapse repeated file extensions (e.g. sprite.png.png -> sprite.png)
    while ($n -match '^(.+?)(\.[A-Za-z0-9]{1,5})\2$') {
        $n = $Matches[1] + $Matches[2]
    }
    # Strip texture hex hashes like [ABCDEF12] or [12345678-ABCDEF12]
    $n = $n -replace '\s*\[[0-9A-Fa-f]{6,12}(?:-[0-9A-Fa-f]{6,12})?\]', ''
    $n = [System.IO.Path]::GetFileNameWithoutExtension($n)
    $n = ($n -replace '\s*-\s*Copy$', '').Trim().TrimEnd('.', ' ')
    # Collapse bare UUID filenames to short prefix
    if ($n -match '^([0-9a-fA-F]{8})-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        $n = $Matches[1].ToLowerInvariant()
    }
    return $n
}

function Split-Rel([string]$rel) {
    $i = $rel.LastIndexOf('/')
    if ($i -lt 0) { return @('', $rel) }
    return @($rel.Substring(0, $i), $rel.Substring($i + 1))
}

function Get-ChangeMeta {
    param($Change)
    $p = $Change.Path
    $cat = 'Framework'; $group = ''; $item = [System.IO.Path]::GetFileName($p); $isForAmd = $false

    if ($p.StartsWith("${TransRoot}Text/")) {
        $cat = 'Text'
        $dir, $leaf = Split-Rel $p.Substring("${TransRoot}Text/".Length)
        $group = if ($dir) { $dir } else { 'General' }
        $item  = Format-CleanItemName $leaf
    }
    elseif ($p.StartsWith("${TransRoot}Texture/")) {
        $cat = 'Texture'
        $rel = $p.Substring("${TransRoot}Texture/".Length)
        $dir, $leaf = Split-Rel $rel
        if ($rel -match '^ForAMD(/|$)') {
            $isForAmd = $true
            $group = if ($dir) { $dir } else { 'ForAMD' }
        } else {
            $group = if ($dir) { $dir } else { 'General' }
        }
        $item = Format-CleanItemName $leaf
    }
    elseif ($p.StartsWith("${TransRoot}RedirectedResources/")) {
        $cat = 'Story'
        $rel = $p.Substring("${TransRoot}RedirectedResources/".Length)
        $dir, $leaf = Split-Rel $rel
        $base = Format-CleanItemName $leaf
        $item = $base
        if ($base -match '^storydata_movie_') {
            $group = 'Movie'
        } elseif ($base -match '^storydata_(\d)') {
            $d = $Matches[1]
            $g = $StoryPrefix[$d]
            $group = if ($g) { $g } else { "Story (${d}xxxxxx)" }
        } else {
            $group = if ($dir) { $dir } else { 'Misc' }
        }
    }
    elseif ($p.StartsWith("${TransRoot}Other/")) {
        $rel = $p.Substring("${TransRoot}Other/".Length)
        $dir, $leaf = Split-Rel $rel
        if ($rel -match '^(Alpha|atlases)(/|$)') {
            $cat   = 'Texture'
            $group = if ($dir) { "Other/$dir" } else { 'Other' }
            $item  = Format-CleanItemName $leaf
        } else {
            $cat   = 'Assets'
            $group = if ($dir) { "Other/$dir" } else { 'Plugin Data' }
            $item  = Format-CleanItemName $leaf
        }
    }
    elseif ($p.StartsWith("${TransRoot}Font/")) {
        $cat = 'Font'; $group = 'Font'; $item = Format-CleanItemName ([System.IO.Path]::GetFileName($p))
    }
    elseif ($p.StartsWith("${TransRoot}Proxy/")) {
        $cat = 'Plugins'; $group = 'GTranslate Proxy (MTL)'; $item = [System.IO.Path]::GetFileName($p)
    }
    elseif ($p.StartsWith('src/BepInEx/plugins/')) {
        $cat = 'Plugins'
        $rel = $p.Substring('src/BepInEx/plugins/'.Length)
        $group = $null
        foreach ($m in $PluginMap) {
            if ($p -match $m.Pattern) { $group = $m.Name; break }
        }
        if (-not $group) { $group = 'Other plugins' }
        $item = [System.IO.Path]::GetFileName($rel)
    }
    elseif ($p.StartsWith('src/BepInEx/config/')) {
        $cat = 'Config'; $group = [System.IO.Path]::GetFileName($p); $item = $group
    }

    return [pscustomobject]@{
        Category = $cat
        Group    = $group
        Item     = $item
        IsForAmd = $isForAmd
    }
}

# ---------- Config: Section/Key-Level INI Diff + Redaction ----------
function Get-IniMap {
    param([string[]]$Lines)
    $map = @{}; $section = ''
    foreach ($l in @($Lines)) {
        if ($null -eq $l) { continue }
        $t = $l.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';')) { continue }
        if ($t -match '^\[(.+)\]$') { $section = $Matches[1].Trim(); continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        $kName = $t.Substring(0, $i).Trim()
        $kVal  = $t.Substring($i + 1).Trim()
        $map["$section`0$kName"] = $kVal
    }
    return $map
}

function Get-ConfigKeyChanges {
    param([string]$Path, [string]$PreviousTag)
    $old = @()
    if ($env:MOCK_CONFIG_OLD_DIR) {
        $mockOld = Join-Path $env:MOCK_CONFIG_OLD_DIR ([IO.Path]::GetFileName($Path))
        if (Test-Path -LiteralPath $mockOld) { $old = @(Get-Content -LiteralPath $mockOld -Encoding utf8) }
    } elseif ($PreviousTag) {
        $old = @(git show "${PreviousTag}:$Path" 2>$null)
        if ($LASTEXITCODE -ne 0) { $old = @() }
    }
    $newFile = Join-Path (Get-Location).Path $Path
    $new = if (Test-Path -LiteralPath $newFile) { @(Get-Content -LiteralPath $newFile -Encoding utf8) } else { @() }

    $om = Get-IniMap $old
    $nm = Get-IniMap $new
    $allKeys = @(@($om.Keys) + @($nm.Keys) | Sort-Object -Unique)
    $hits = @()
    $seenCompound = @{}

    foreach ($w in @($WatchList)) {
        foreach ($compound in $allKeys) {
            if ($seenCompound.ContainsKey($compound)) { continue }
            $sec, $key = $compound -split "`0", 2
            if ($sec -ine $w.Section) { continue }
            if ($null -ne $w.Key -and $key -ine $w.Key) { continue }

            $hasOld = $om.ContainsKey($compound)
            $hasNew = $nm.ContainsKey($compound)
            $ov = if ($hasOld) { $om[$compound] } else { $null }
            $nv = if ($hasNew) { $nm[$compound] } else { $null }
            if ($hasOld -and $hasNew -and ($ov -ceq $nv)) { continue }

            $seenCompound[$compound] = $true
            $status = if (-not $hasOld) { 'added' } elseif (-not $hasNew) { 'removed' } else { 'changed' }
            $hits += [pscustomobject]@{
                Key    = "[$sec] $key"
                Status = $status
                Old    = if ($hasOld) { Redact-ConfigValue -Key $key -Value ([string]$ov) } else { '(none)' }
                New    = if ($hasNew) { Redact-ConfigValue -Key $key -Value ([string]$nv) } else { '(removed)' }
            }
        }
    }
    return @($hits)
}

# ---------- Main Execution ----------
$Tag = if ($env:RELEASE_TAG) { $env:RELEASE_TAG.Trim() } else { 'local-test' }
$PreviousTag = Get-PreviousTag -ExcludeTag $Tag
Write-Information "Comparing: $PreviousTag -> $Tag"

$Changes = @(Get-DiffChanges -PreviousTag $PreviousTag)
Write-Information "::group::Raw diff ($($Changes.Count) entries)`n$(($Changes | ForEach-Object { "$($_.Action)`t$($_.Path)" }) -join "`n")`n::endgroup::"

$Items = @(); $seen = @{}; $FrameworkCount = 0; $ForAmdCount = 0
foreach ($c in $Changes) {
    $meta = Get-ChangeMeta $c
    if ($meta.Category -eq 'Framework') { $FrameworkCount++; continue }
    $dedupeKey = "$($meta.Category)|$($meta.Group)|$($meta.Item)|$($c.Action)"
    if ($seen.ContainsKey($dedupeKey)) { continue }
    $seen[$dedupeKey] = $true
    if ($meta.IsForAmd) { $ForAmdCount++ }
    $Items += [pscustomobject]@{
        Category = $meta.Category
        Group    = $meta.Group
        Item     = $meta.Item
        Action   = $c.Action
        Moved    = $c.Moved
        IsForAmd = $meta.IsForAmd
    }
}

$ConfigChanges = @()
foreach ($c in @($Changes | Where-Object { $_.Path.StartsWith('src/BepInEx/config/') })) {
    $hits = @(Get-ConfigKeyChanges -Path $c.Path -PreviousTag $PreviousTag)
    $ConfigChanges += [pscustomobject]@{
        File   = [IO.Path]::GetFileName($c.Path)
        Action = $c.Action
        Keys   = @($hits)
    }
}
$Critical = @($ConfigChanges | Where-Object { @($_.Keys).Count -gt 0 })

$PluginGroups = @($Items | Where-Object { $_.Category -eq 'Plugins' } | Group-Object Group | ForEach-Object {
    $note = ''
    foreach ($m in $PluginMap) {
        if ($m.Name -eq $_.Name) { $note = $m.Note; break }
    }
    [pscustomobject]@{
        Name    = $_.Name
        Note    = $note
        Added   = @($_.Group | Where-Object { $_.Action -eq 'Added' }).Count
        Updated = @($_.Group | Where-Object { $_.Action -eq 'Updated' }).Count
        Deleted = @($_.Group | Where-Object { $_.Action -eq 'Deleted' }).Count
    }
})

$CatOrder = @(
    @{ Id = 'Text';    Icon = '📝'; Label = 'Text' }
    @{ Id = 'Texture'; Icon = '🖼️'; Label = 'Texture' }
    @{ Id = 'Story';   Icon = '📖'; Label = 'Story (RedirectedResources)' }
    @{ Id = 'Assets';  Icon = '🧩'; Label = 'Plugin Assets (Other)' }
    @{ Id = 'Font';    Icon = '🔤'; Label = 'Font' }
    @{ Id = 'Plugins'; Icon = '🔧'; Label = 'Plugins' }
    @{ Id = 'Config';  Icon = '⚙️'; Label = 'Config' }
)

function Get-CatCounts([string]$id) {
    $g = if ($id -eq 'Texture') {
        @($Items | Where-Object { $_.Category -eq 'Texture' -and -not $_.IsForAmd })
    } else {
        @($Items | Where-Object { $_.Category -eq $id })
    }
    return [pscustomobject]@{
        Added   = @($g | Where-Object { $_.Action -eq 'Added' }).Count
        Updated = @($g | Where-Object { $_.Action -eq 'Updated' }).Count
        Deleted = @($g | Where-Object { $_.Action -eq 'Deleted' }).Count
        Total   = $g.Count
    }
}

# ---------- Build RELEASE_NOTE Markdown ----------
function Build-ReleaseNote {
    param([int]$MaxItemsPerList = 60)
    $sb = [System.Text.StringBuilder]::new()
    function Add-Ln([string]$s = '') { [void]$sb.AppendLine($s) }
    $hasContent = ($Items.Count -gt 0) -or ($FrameworkCount -gt 0)

    if ($Critical.Count -gt 0) {
        Add-Ln ''
        Add-Ln '> ⚠️ **CRITICAL CONFIG CHANGE — updater users must apply manually!**'
        foreach ($cc in $Critical) {
            foreach ($k in @($cc.Keys)) {
                Add-Ln "> - ``$($k.Key)`` ($($k.Status)): ``$($k.Old)`` → ``$($k.New)``"
            }
        }
        Add-Ln ''
    }

    if ($hasContent) {
        Add-Ln ''
        Add-Ln '## 📊 Summary'
        Add-Ln ''
        Add-Ln '| Category | ➕ Added | ✏️ Updated | 🗑️ Deleted |'
        Add-Ln '|---|---:|---:|---:|'
        foreach ($cat in $CatOrder) {
            $n = Get-CatCounts $cat.Id
            if ($n.Total -eq 0) { continue }
            Add-Ln "| $($cat.Icon) $($cat.Label) | $($n.Added) | $($n.Updated) | $($n.Deleted) |"
        }
        if ($FrameworkCount -gt 0) {
            Add-Ln "| ⚙️ Framework | — | $FrameworkCount file(s) | — |"
        }
        if ($ForAmdCount -gt 0) {
            Add-Ln ''
            Add-Ln "_* AMD texture variants: **$ForAmdCount** file(s) in ``Texture/ForAMD`` (manual replacement, see README)._"
        }
        Add-Ln ''
    }

    if ($PluginGroups.Count -gt 0 -or $Critical.Count -gt 0) {
        Add-Ln '## 🔧 Highlights'
        Add-Ln ''
        foreach ($pg in $PluginGroups) {
            $acts = @()
            if ($pg.Added)   { $acts += "$($pg.Added) added" }
            if ($pg.Updated) { $acts += "$($pg.Updated) updated" }
            if ($pg.Deleted) { $acts += "$($pg.Deleted) deleted" }
            $note = if ($pg.Note) { " — $($pg.Note)" } else { '' }
            Add-Ln "- **$($pg.Name)** ($($acts -join ', '))$note"
        }
        foreach ($cc in $Critical) {
            Add-Ln "- ⚠️ **$($cc.File)** — watched keys changed (see notice above)"
        }
        Add-Ln ''
    }

    if ($Items.Count -gt 0) {
        Add-Ln '## Changelog'
        Add-Ln ''
        foreach ($cat in $CatOrder) {
            $catItems = @($Items | Where-Object { $_.Category -eq $cat.Id })
            if ($catItems.Count -eq 0) { continue }

            if ($cat.Id -eq 'Texture') {
                $stdItems = @($catItems | Where-Object { -not $_.IsForAmd })
                $amdItems = @($catItems | Where-Object { $_.IsForAmd })
                $amdSuffix = if ($amdItems.Count -gt 0) { " (+$($amdItems.Count) AMD variants)" } else { '' }
                Add-Ln "<details><summary>$($cat.Icon) $($cat.Label) — $($stdItems.Count) change(s)${amdSuffix}</summary>"
                Add-Ln ''
                foreach ($grp in @($stdItems | Group-Object Group | Sort-Object Name)) {
                    Add-Ln "**$($grp.Name)**"
                    foreach ($act in 'Added', 'Updated', 'Deleted') {
                        $rows = @($grp.Group | Where-Object { $_.Action -eq $act })
                        if ($rows.Count -eq 0) { continue }
                        $icon = switch ($act) { 'Added' { '➕' } 'Updated' { '✏️' } 'Deleted' { '🗑️' } }
                        $names = @($rows | ForEach-Object {
                            if ($_.Moved) { "$($_.Item) *(moved)*" } else { $_.Item }
                        } | Sort-Object -Unique)
                        if ($MaxItemsPerList -eq 0) {
                            Add-Ln "- ${icon} ${act}: $($names.Count) item(s)"
                        } elseif ($names.Count -gt $MaxItemsPerList) {
                            $shown = ($names | Select-Object -First $MaxItemsPerList) -join ', '
                            $rest  = $names.Count - $MaxItemsPerList
                            Add-Ln "- ${icon} ${act}: $shown ...and $rest more"
                        } else {
                            Add-Ln "- ${icon} ${act}: $($names -join ', ')"
                        }
                    }
                    Add-Ln ''
                }
                if ($amdItems.Count -gt 0) {
                    Add-Ln "**AMD Texture Variants (ForAMD)**"
                    foreach ($grp in @($amdItems | Group-Object Group | Sort-Object Name)) {
                        Add-Ln "_$($grp.Name)_"
                        foreach ($act in 'Added', 'Updated', 'Deleted') {
                            $rows = @($grp.Group | Where-Object { $_.Action -eq $act })
                            if ($rows.Count -eq 0) { continue }
                            $icon = switch ($act) { 'Added' { '➕' } 'Updated' { '✏️' } 'Deleted' { '🗑️' } }
                            $names = @($rows | ForEach-Object {
                                if ($_.Moved) { "$($_.Item) *(moved)*" } else { $_.Item }
                            } | Sort-Object -Unique)
                            if ($MaxItemsPerList -eq 0) {
                                Add-Ln "- ${icon} ${act}: $($names.Count) item(s)"
                            } elseif ($names.Count -gt $MaxItemsPerList) {
                                $shown = ($names | Select-Object -First $MaxItemsPerList) -join ', '
                                $rest  = $names.Count - $MaxItemsPerList
                                Add-Ln "- ${icon} ${act}: $shown ...and $rest more"
                            } else {
                                Add-Ln "- ${icon} ${act}: $($names -join ', ')"
                            }
                        }
                        Add-Ln ''
                    }
                }
                Add-Ln '</details>'
                Add-Ln ''
                continue
            }

            Add-Ln "<details><summary>$($cat.Icon) $($cat.Label) — $($catItems.Count) change(s)</summary>"
            Add-Ln ''
            foreach ($grp in @($catItems | Group-Object Group | Sort-Object Name)) {
                Add-Ln "**$($grp.Name)**"
                if ($cat.Id -eq 'Config') {
                    foreach ($cc in @($ConfigChanges | Where-Object { $_.File -eq $grp.Name })) {
                        if (@($cc.Keys).Count -gt 0) {
                            foreach ($k in @($cc.Keys)) {
                                Add-Ln "- ⚠️ ``$($k.Key)`` ($($k.Status)): ``$($k.Old)`` → ``$($k.New)``"
                            }
                        } else {
                            Add-Ln '- preference/non-watched changes only'
                        }
                    }
                } else {
                    foreach ($act in 'Added', 'Updated', 'Deleted') {
                        $rows = @($grp.Group | Where-Object { $_.Action -eq $act })
                        if ($rows.Count -eq 0) { continue }
                        $icon = switch ($act) { 'Added' { '➕' } 'Updated' { '✏️' } 'Deleted' { '🗑️' } }
                        $names = @($rows | ForEach-Object {
                            if ($_.Moved) { "$($_.Item) *(moved)*" } else { $_.Item }
                        } | Sort-Object -Unique)
                        if ($MaxItemsPerList -eq 0) {
                            Add-Ln "- ${icon} ${act}: $($names.Count) item(s)"
                        } elseif ($names.Count -gt $MaxItemsPerList) {
                            $shown = ($names | Select-Object -First $MaxItemsPerList) -join ', '
                            $rest  = $names.Count - $MaxItemsPerList
                            Add-Ln "- ${icon} ${act}: $shown ...and $rest more"
                        } else {
                            Add-Ln "- ${icon} ${act}: $($names -join ', ')"
                        }
                    }
                }
                Add-Ln ''
            }
            Add-Ln '</details>'
            Add-Ln ''
        }
    }

    if ($FrameworkCount -gt 0 -and $Items.Count -eq 0) {
        Add-Ln "_Framework/engine update only ($FrameworkCount file(s))._"
    }
    if (-not $hasContent) {
        Add-Ln ''
        $since = if ($PreviousTag) { " since $PreviousTag" } else { '' }
        Add-Ln "_Maintenance release — no translation changes${since}._"
    }
    return $sb.ToString()
}

$hasContent = ($Items.Count -gt 0) -or ($FrameworkCount -gt 0)
$noteText = Build-ReleaseNote -MaxItemsPerList 60
if ($noteText.Length -gt 100000) {
    $noteText = Build-ReleaseNote -MaxItemsPerList 10
}
if ($noteText.Length -gt 100000) {
    $noteText = Build-ReleaseNote -MaxItemsPerList 0
}
if ($noteText.Length -gt 100000) {
    $cut = 99400
    if ([char]::IsHighSurrogate($noteText[$cut - 1])) { $cut-- }
    $noteText = $noteText.Substring(0, $cut)
    $openCount  = ([regex]::Matches($noteText, '<details>')).Count
    $closeCount = ([regex]::Matches($noteText, '</details>')).Count
    if ($openCount -gt $closeCount) {
        $noteText += "`n</details>"
    }
    $noteText += "`n`n_...Changelog truncated due to GitHub release body size limit. See Full Changelog link below._`n"
}

$rnTarget   = Join-Path (Get-Location).Path 'RELEASE_NOTE'
$jsonTarget = Join-Path (Get-Location).Path 'CHANGES.json'

[System.IO.File]::AppendAllText($rnTarget, $noteText, [System.Text.UTF8Encoding]::new($false))
Write-Information "::group::Final Changelog`n$noteText`n::endgroup::"

# ---------- Write CHANGES.json Data Contract ----------
$countsArr = @(foreach ($cat in $CatOrder) {
    $n = Get-CatCounts $cat.Id
    [pscustomobject]@{
        Id      = $cat.Id
        Icon    = $cat.Icon
        Label   = $cat.Label
        Added   = $n.Added
        Updated = $n.Updated
        Deleted = $n.Deleted
        Total   = $n.Total
    }
})

$jsonObj = [pscustomobject]@{
    Tag            = $Tag
    PreviousTag    = $PreviousTag
    HasChanges     = $hasContent
    FrameworkFiles = $FrameworkCount
    ForAmdFiles    = $ForAmdCount
    Items          = @($Items)
    Plugins        = @($PluginGroups)
    Config         = @($ConfigChanges)
    Critical       = ($Critical.Count -gt 0)
    Counts         = @($countsArr)
}
$jsonStr = $jsonObj | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($jsonTarget, $jsonStr, [System.Text.UTF8Encoding]::new($false))
