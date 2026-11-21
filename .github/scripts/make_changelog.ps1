# ============================================================================
# make_changelog.ps1 - Detailed Categorized Changelog & CHANGES.json Generator
# ============================================================================
param(
    [string] $PreviousTag  = $env:PREVIOUS_TAG,
    [string] $ReleaseTag   = $env:RELEASE_TAG,
    [string] $ReleaseTitle = $env:RELEASE_TITLE,
    [string] $DiffFile     = $env:CHANGELOG_DIFF_FILE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'initialize.ps1')

$BlacklistPath = Join-Path $ScriptDir 'changelog_blacklist.txt'
$WatchlistPath = Join-Path $ScriptDir 'config_watchlist.txt'
$PluginMapPath = Join-Path $ScriptDir 'plugin_map.psd1'
$StoryPfxPath  = Join-Path $ScriptDir 'story_prefix.psd1'

$PluginMapData = Get-SafePsd1Data -Path $PluginMapPath -Default @{ Mappings = @{} }
$StoryPfxData  = Get-SafePsd1Data -Path $StoryPfxPath  -Default @{ Prefixes = @{} }
$Watchlist     = @(Read-WatchlistRules -Path $WatchlistPath)

# Load blacklist regexes safely
$BlacklistPatterns = [System.Collections.ArrayList]::new()
if (Test-Path -LiteralPath $BlacklistPath) {
    foreach ($rawLine in @(Get-Content -LiteralPath $BlacklistPath -Encoding utf8)) {
        if ($null -eq $rawLine) { continue }
        $t = $rawLine.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        [void]$BlacklistPatterns.Add($t)
    }
}

function Test-IsBlacklisted {
    param([string] $RepoPath)
    if ($BlacklistPatterns.Count -eq 0) { return $false }
    foreach ($pat in $BlacklistPatterns) {
        if ($RepoPath -imatch $pat) { return $true }
    }
    return $false
}

function Get-CleanItemName {
    param(
        [string] $FileName,
        [string] $Category
    )
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    # Collapse repeated extensions like banner_event.png.png -> banner_event
    while ($base -match '\.(txt|csv|json|po|tsv|png|jpg|jpeg|tga|webp|dds|dll|cfg|ini|ttf|otf|woff2?)$') {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($base)
    }
    # Strip technical bracketed hex hashes like " [ABCDEF12]"
    $base = ($base -replace '\s*\[[0-9A-Fa-f]{6,16}\]$', '').Trim()
    # Collapse bare UUID filenames to 8-char prefix
    if ($base -match '^([0-9A-Fa-f]{8})-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$') {
        $base = $Matches[1]
    }
    if ($Category -eq 'Plugins' -and $PluginMapData.Mappings -is [System.Collections.IDictionary]) {
        foreach ($pfx in $PluginMapData.Mappings.Keys) {
            if ($base -imatch ('^' + [regex]::Escape([string]$pfx))) {
                return [string]$PluginMapData.Mappings[$pfx]
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($base)) { return $FileName }
    return $base
}

function Resolve-PathClassification {
    param([string] $NormPath)

    # Only inspect user-facing mod assets under src/
    if ($NormPath -notmatch '^src/(.+)$') {
        return $null
    }
    $rel = $Matches[1]
    $fileName = [System.IO.Path]::GetFileName($rel)

    # 1. Plugins (BepInEx/plugins or GTranslateProxyServer)
    if ($rel -match '^BepInEx/plugins/(.*)$' -or $rel -match '(^|/)GTranslateProxyServer') {
        $sub = if ($Matches[1] -and $rel -match '^BepInEx/plugins/(.*)$') { $Matches[1] } else { $rel }
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'Plugins' } else { $dir }
        return [PSCustomObject]@{
            Category = 'Plugins'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'Plugins')
            IsForAmd = $false
        }
    }

    # 2. Config (BepInEx/config or *.cfg / *.ini)
    if ($rel -match '^BepInEx/config/(.*)$' -or $rel -match '\.(cfg|ini)$') {
        $sub = if ($rel -match '^BepInEx/config/(.*)$') { $Matches[1] } else { $rel }
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'Config' } else { $dir }
        return [PSCustomObject]@{
            Category = 'Config'
            Group    = $grp
            Name     = $fileName
            IsForAmd = $false
        }
    }

    # 3. Story (RedirectedResources)
    if ($rel -match '(^|/)RedirectedResources/(.*)$') {
        $sub = $Matches[2]
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'General' } else { $dir }
        if ($StoryPfxData.Prefixes -is [System.Collections.IDictionary]) {
            foreach ($k in $StoryPfxData.Prefixes.Keys) {
                if ($grp -imatch ('^' + [regex]::Escape([string]$k) + '(/|$)')) {
                    $grp = $grp -ireplace ('^' + [regex]::Escape([string]$k)), [string]$StoryPfxData.Prefixes[$k]
                    break
                }
            }
        }
        return [PSCustomObject]@{
            Category = 'Story'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'Story')
            IsForAmd = $false
        }
    }

    # 4. Other/Alpha & Other/atlases -> Texture (with provenance folder prefix)
    if ($rel -match '(^|/)(Other/(Alpha|atlases)(/.*)?)$') {
        $provFull = $Matches[2]
        $dir = [System.IO.Path]::GetDirectoryName($provFull) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'Other' } else { $dir }
        return [PSCustomObject]@{
            Category = 'Texture'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'Texture')
            IsForAmd = $false
        }
    }

    # 5. Other plugin extra assets (outside Other/Alpha & Other/atlases)
    if ($rel -match '(^|/)Other/(.*)$') {
        $sub = $Matches[2]
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'Other' } else { $dir }
        return [PSCustomObject]@{
            Category = 'PluginAssets'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'PluginAssets')
            IsForAmd = $false
        }
    }

    # 6. Texture (including Texture/ForAMD/** flagged separately)
    if ($rel -match '(^|/)Texture/(.*)$' -or $rel -match '\.(png|jpg|jpeg|tga|webp|dds)$') {
        $sub = if ($rel -match '(^|/)Texture/(.*)$') { $Matches[2] } else { $rel }
        $isAmd = $false
        if ($sub -imatch '^ForAMD(?:/(.*))?$') {
            $isAmd = $true
            $sub = if ($Matches[1]) { $Matches[1] } else { $fileName }
        }
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'General' } else { $dir }
        return [PSCustomObject]@{
            Category = 'Texture'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'Texture')
            IsForAmd = $isAmd
        }
    }

    # 7. Font assets
    if ($rel -match '(^|/)Font/(.*)$' -or $rel -match '\.(ttf|otf|woff2?)$') {
        $sub = if ($rel -match '(^|/)Font/(.*)$') { $Matches[2] } else { $rel }
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'Fonts' } else { $dir }
        return [PSCustomObject]@{
            Category = 'Font'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'Font')
            IsForAmd = $false
        }
    }

    # 8. Text / Script translations
    if ($rel -match '(^|/)Text/(.*)$' -or $rel -match '\.(txt|csv|json|po|tsv)$') {
        $sub = if ($rel -match '(^|/)Text/(.*)$') { $Matches[2] } else { $rel }
        $dir = [System.IO.Path]::GetDirectoryName($sub) -replace '\\', '/'
        $grp = if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq '.') { 'General' } else { $dir }
        return [PSCustomObject]@{
            Category = 'Text'
            Group    = $grp
            Name     = (Get-CleanItemName -FileName $fileName -Category 'Text')
            IsForAmd = $false
        }
    }

    # 9. Framework / Loader / Core files
    return [PSCustomObject]@{
        Category = 'Framework'
        Group    = 'Framework'
        Name     = $fileName
        IsForAmd = $false
    }
}

function ConvertFrom-IniLines {
    param([string[]] $Lines)
    $map = @{}
    $section = 'Default'
    foreach ($raw in $Lines) {
        if ($null -eq $raw) { continue }
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[([^\[\]]+)\]$') {
            $section = $Matches[1].Trim()
            continue
        }
        $eqIdx = $line.IndexOf('=')
        if ($eqIdx -gt 0) {
            $k = $line.Substring(0, $eqIdx).Trim()
            $v = $line.Substring($eqIdx + 1).Trim()
            $fullKey = "$section|$k"
            $map[$fullKey] = [PSCustomObject]@{
                Section = $section
                Key     = $k
                Value   = $v
            }
        }
    }
    return $map
}

function Format-SafeConfigValue {
    param(
        [string] $KeyName,
        [string] $Value
    )
    if ($KeyName -imatch '(?i)api_?key|token|secret|password') {
        return '(redacted)'
    }
    $sanitized = $Value -replace '(?i)[A-Za-z]:\\Users\\[^\\/:*?"<>|\r\n]+', '%USERPROFILE%'
    if ($sanitized.Length -gt 60) {
        $sanitized = Limit-SafeText -Text $sanitized -MaxLength 60 -Suffix '...'
    }
    return $sanitized
}

function Test-MatchesWatchlist {
    param(
        [string] $Section,
        [string] $Key
    )
    if ($Watchlist.Count -eq 0) { return $false }
    foreach ($rule in $Watchlist) {
        if ($rule.Section -ieq $Section) {
            if ([string]::IsNullOrWhiteSpace($rule.Key) -or $rule.Key -ieq $Key) {
                return $true
            }
        }
    }
    return $false
}

function Get-ConfigDiffDetails {
    param(
        [string] $PrevTag,
        [string] $RelPath
    )
    $oldLines = @()
    $newLines = @()
    if (-not [string]::IsNullOrWhiteSpace($PrevTag)) {
        try {
            $oldRaw = & git -c core.quotepath=off show "${PrevTag}:${RelPath}" 2>$null
            if ($LASTEXITCODE -eq 0 -and $null -ne $oldRaw) {
                $oldLines = @($oldRaw)
            }
        } catch { }
    }
    if (Test-Path -LiteralPath $RelPath) {
        $newLines = @(Get-Content -LiteralPath $RelPath -Encoding utf8)
    }

    $oldMap = ConvertFrom-IniLines -Lines $oldLines
    $newMap = ConvertFrom-IniLines -Lines $newLines

    $allKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($k in $oldMap.Keys) { [void]$allKeys.Add($k) }
    foreach ($k in $newMap.Keys) { [void]$allKeys.Add($k) }

    $criticalNotes = [System.Collections.ArrayList]::new()
    $criticalLabels = [System.Collections.ArrayList]::new()
    $hasNonCritical = $false

    foreach ($fk in ($allKeys | Sort-Object)) {
        $inOld = $oldMap.ContainsKey($fk)
        $inNew = $newMap.ContainsKey($fk)
        $entry = if ($inNew) { $newMap[$fk] } else { $oldMap[$fk] }
        $sec = $entry.Section
        $key = $entry.Key

        if ($inOld -and $inNew -and ($oldMap[$fk].Value -ceq $newMap[$fk].Value)) {
            continue
        }

        if (Test-MatchesWatchlist -Section $sec -Key $key) {
            $label = "[$sec] $key"
            [void]$criticalLabels.Add($label)
            if (-not $inOld -and $inNew) {
                $nv = Format-SafeConfigValue -KeyName $key -Value $newMap[$fk].Value
                [void]$criticalNotes.Add("``$label`` = ``$nv`` *(added)*")
            } elseif ($inOld -and -not $inNew) {
                [void]$criticalNotes.Add("``$label`` *(removed)*")
            } else {
                $ov = Format-SafeConfigValue -KeyName $key -Value $oldMap[$fk].Value
                $nv = Format-SafeConfigValue -KeyName $key -Value $newMap[$fk].Value
                [void]$criticalNotes.Add("``$label``: ``$ov`` → ``$nv``")
            }
        } else {
            $hasNonCritical = $true
        }
    }

    return [PSCustomObject]@{
        CriticalNotes  = $criticalNotes
        CriticalLabels = $criticalLabels
        HasNonCritical = $hasNonCritical
    }
}

# Obtain raw git diff lines
$rawDiffLines = @()
if (-not [string]::IsNullOrWhiteSpace($DiffFile) -and (Test-Path -LiteralPath $DiffFile)) {
    $rawDiffLines = @(Get-Content -LiteralPath $DiffFile -Encoding utf8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} else {
    $diffArgs = @('-c', 'core.quotepath=off', 'diff', '--name-status', '-M')
    if (-not [string]::IsNullOrWhiteSpace($PreviousTag)) {
        $diffArgs += "$PreviousTag..HEAD"
    } else {
        $diffArgs = @('-c', 'core.quotepath=off', 'log', '--name-status', '-M', '--pretty=format:')
    }
    $rawDiffLines = @(& git @diffArgs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

Write-Host "Comparing: $PreviousTag -> $ReleaseTag"
Write-Host "::group::Raw diff ($($rawDiffLines.Count) entries)"
foreach ($dl in $rawDiffLines) { Write-Host $dl }
Write-Host "::endgroup::"

# Data structures for categorized entries
$CategoryOrder = @('Text', 'Texture', 'Story', 'PluginAssets', 'Font', 'Plugins', 'Config')
$CategoryMeta = @{
    'Text'         = @{ Icon = '📝'; Label = 'Text' }
    'Texture'      = @{ Icon = '🖼️'; Label = 'Texture' }
    'Story'        = @{ Icon = '📖'; Label = 'Story' }
    'PluginAssets' = @{ Icon = '🧩'; Label = 'Plugin Assets' }
    'Font'         = @{ Icon = '🔤'; Label = 'Font' }
    'Plugins'      = @{ Icon = '🔧'; Label = 'Plugins' }
    'Config'       = @{ Icon = '⚙️'; Label = 'Config' }
}

$EntriesByCat = @{}
foreach ($cat in $CategoryOrder) {
    $EntriesByCat[$cat] = [System.Collections.ArrayList]::new()
}

$FrameworkCount = 0
$CriticalConfig = $false
$AllCriticalLabels = [System.Collections.ArrayList]::new()
$ConfigDetailsByFile = [ordered]@{}

foreach ($line in $rawDiffLines) {
    $parts = $line -split "`t"
    if ($parts.Count -lt 2) { continue }

    $status = $parts[0].Trim()
    $pathA  = ($parts[1].Trim() -replace '\\', '/')
    $pathB  = if ($parts.Count -ge 3) { ($parts[2].Trim() -replace '\\', '/') } else { $pathA }

    if ($status -match '^R') {
        $isEdited = ($status -ne 'R100')
        $oldBlack = Test-IsBlacklisted -RepoPath $pathA
        $newBlack = Test-IsBlacklisted -RepoPath $pathB
        if ($oldBlack -and $newBlack) { continue }

        $oldClass = if ($oldBlack) { $null } else { Resolve-PathClassification -NormPath $pathA }
        $newClass = if ($newBlack) { $null } else { Resolve-PathClassification -NormPath $pathB }

        if ($null -eq $oldClass -and $null -eq $newClass) { continue }

        # Moved into src/ from outside src/ -> Added
        if ($null -eq $oldClass -and $null -ne $newClass) {
            if ($newClass.Category -eq 'Framework') {
                $FrameworkCount++
            } else {
                [void]$EntriesByCat[$newClass.Category].Add([PSCustomObject]@{
                    Action   = 'Added'
                    Group    = $newClass.Group
                    Name     = $newClass.Name
                    OldName  = ''
                    OldGroup = ''
                    IsEdited = $false
                    IsForAmd = $newClass.IsForAmd
                    RawPath  = $pathB
                })
            }
            continue
        }

        # Moved out of src/ -> Deleted
        if ($null -ne $oldClass -and $null -eq $newClass) {
            if ($oldClass.Category -eq 'Framework') {
                $FrameworkCount++
            } else {
                [void]$EntriesByCat[$oldClass.Category].Add([PSCustomObject]@{
                    Action   = 'Deleted'
                    Group    = $oldClass.Group
                    Name     = $oldClass.Name
                    OldName  = ''
                    OldGroup = ''
                    IsEdited = $false
                    IsForAmd = $oldClass.IsForAmd
                    RawPath  = $pathA
                })
            }
            continue
        }

        if ($newClass.Category -eq 'Framework') {
            $FrameworkCount++
            continue
        }

        # Determine Renamed vs Moved:
        # Renamed: same category & same folder path, filename changed
        # Moved: folder path (or category) changed
        $sameFolder = ($oldClass.Category -ceq $newClass.Category) -and ($oldClass.Group -ieq $newClass.Group)
        $actionType = if ($sameFolder) { 'Renamed' } else { 'Moved' }

        [void]$EntriesByCat[$newClass.Category].Add([PSCustomObject]@{
            Action   = $actionType
            Group    = $newClass.Group
            Name     = $newClass.Name
            OldName  = $oldClass.Name
            OldGroup = $oldClass.Group
            IsEdited = $isEdited
            IsForAmd = $newClass.IsForAmd
            RawPath  = $pathB
        })

        if ($newClass.Category -eq 'Config') {
            $cfgInfo = Get-ConfigDiffDetails -PrevTag $PreviousTag -RelPath $pathB
            if ($cfgInfo.CriticalLabels.Count -gt 0) {
                $CriticalConfig = $true
                foreach ($lbl in $cfgInfo.CriticalLabels) {
                    if (-not $AllCriticalLabels.Contains($lbl)) {
                        [void]$AllCriticalLabels.Add($lbl)
                    }
                }
            }
            $ConfigDetailsByFile[$newClass.Name] = $cfgInfo
        }
        continue
    }

    # Standard A / M / D statuses
    if (Test-IsBlacklisted -RepoPath $pathB) { continue }
    $cls = Resolve-PathClassification -NormPath $pathB
    if ($null -eq $cls) { continue }

    if ($cls.Category -eq 'Framework') {
        $FrameworkCount++
        continue
    }

    $action = switch -Regex ($status) {
        '^A' { 'Added'; break }
        '^D' { 'Deleted'; break }
        default { 'Updated'; break }
    }

    [void]$EntriesByCat[$cls.Category].Add([PSCustomObject]@{
        Action   = $action
        Group    = $cls.Group
        Name     = $cls.Name
        OldName  = ''
        OldGroup = ''
        IsEdited = $false
        IsForAmd = $cls.IsForAmd
        RawPath  = $pathB
    })

    if ($cls.Category -eq 'Config' -and $action -ne 'Deleted') {
        $cfgInfo = Get-ConfigDiffDetails -PrevTag $PreviousTag -RelPath $pathB
        if ($cfgInfo.CriticalLabels.Count -gt 0) {
            $CriticalConfig = $true
            foreach ($lbl in $cfgInfo.CriticalLabels) {
                if (-not $AllCriticalLabels.Contains($lbl)) {
                    [void]$AllCriticalLabels.Add($lbl)
                }
            }
        }
        $ConfigDetailsByFile[$cls.Name] = $cfgInfo
    }
}

# Compute category counts (excluding IsForAmd from main Summary table counts)
$Stats = @{}
$TotalAdded   = 0
$TotalUpdated = 0
$TotalRenamed = 0
$TotalMoved   = 0
$TotalDeleted = 0
$ForAmdCount  = 0

foreach ($cat in $CategoryOrder) {
    $items = @($EntriesByCat[$cat])
    $mainItems = @($items | Where-Object { -not $_.IsForAmd })
    if ($cat -eq 'Texture') {
        $ForAmdCount = @($items | Where-Object { $_.IsForAmd }).Count
    }

    $cAdd = @($mainItems | Where-Object { $_.Action -eq 'Added' }).Count
    $cUpd = @($mainItems | Where-Object { $_.Action -eq 'Updated' }).Count
    $cRen = @($mainItems | Where-Object { $_.Action -eq 'Renamed' }).Count
    $cMov = @($mainItems | Where-Object { $_.Action -eq 'Moved' }).Count
    $cDel = @($mainItems | Where-Object { $_.Action -eq 'Deleted' }).Count
    $cTot = $cAdd + $cUpd + $cRen + $cMov + $cDel

    $Stats[$cat] = [PSCustomObject]@{
        Added   = $cAdd
        Updated = $cUpd
        Renamed = $cRen
        Moved   = $cMov
        Deleted = $cDel
        Total   = $cTot
    }

    $TotalAdded   += $cAdd
    $TotalUpdated += $cUpd
    $TotalRenamed += $cRen
    $TotalMoved   += $cMov
    $TotalDeleted += $cDel
}

$TotalChanges = $TotalAdded + $TotalUpdated + $TotalRenamed + $TotalMoved + $TotalDeleted + $ForAmdCount + $FrameworkCount
$HasChanges   = ($TotalChanges -gt 0)

# Build group breakdown for Discord summary
$DiscordGroups = [System.Collections.ArrayList]::new()
foreach ($cat in $CategoryOrder) {
    $mainItems = @($EntriesByCat[$cat] | Where-Object { -not $_.IsForAmd })
    if ($mainItems.Count -eq 0) { continue }
    $grpMap = [ordered]@{}
    foreach ($it in $mainItems) {
        if (-not $grpMap.Contains($it.Group)) { $grpMap[$it.Group] = 0 }
        $grpMap[$it.Group]++
    }
    foreach ($gName in $grpMap.Keys) {
        [void]$DiscordGroups.Add([PSCustomObject]@{
            Category = $CategoryMeta[$cat].Label
            Group    = $gName
            Count    = $grpMap[$gName]
        })
    }
}

# Build Markdown changelog body
$md = [System.Text.StringBuilder]::new()

if (-not $HasChanges) {
    if ([string]::IsNullOrWhiteSpace($PreviousTag)) {
        [void]$md.AppendLine('_Maintenance release — no translation changes._')
    } else {
        [void]$md.AppendLine("_Maintenance release — no translation changes since $PreviousTag._")
    }
} else {
    if ($CriticalConfig) {
        [void]$md.AppendLine('> [!CAUTION]')
        [void]$md.AppendLine('> **Critical Configuration Update!** Users who normally skip config files to preserve custom MTL settings must review the updated keys below:')
        foreach ($fKey in $ConfigDetailsByFile.Keys) {
            $ci = $ConfigDetailsByFile[$fKey]
            foreach ($note in $ci.CriticalNotes) {
                [void]$md.AppendLine("> - **$fKey**: $note")
            }
        }
        [void]$md.AppendLine('')
    }

    [void]$md.AppendLine('## 📊 Summary')
    [void]$md.AppendLine('')

    # Dynamic Summary columns: Renamed and Moved appear ONLY when > 0
    $showRenamedCol = ($TotalRenamed -gt 0)
    $showMovedCol   = ($TotalMoved -gt 0)

    $hdrCols = [System.Collections.ArrayList]::new()
    $sepCols = [System.Collections.ArrayList]::new()
    [void]$hdrCols.Add('Category')
    [void]$sepCols.Add('---')
    [void]$hdrCols.Add('➕ Added')
    [void]$sepCols.Add('---:')
    [void]$hdrCols.Add('✏️ Updated')
    [void]$sepCols.Add('---:')
    if ($showRenamedCol) {
        [void]$hdrCols.Add('🏷️ Renamed')
        [void]$sepCols.Add('---:')
    }
    if ($showMovedCol) {
        [void]$hdrCols.Add('📦 Moved')
        [void]$sepCols.Add('---:')
    }
    [void]$hdrCols.Add('🗑️ Deleted')
    [void]$sepCols.Add('---:')

    [void]$md.AppendLine('| ' + ($hdrCols -join ' | ') + ' |')
    [void]$md.AppendLine('|' + ($sepCols -join '|') + '|')

    foreach ($cat in $CategoryOrder) {
        $st = $Stats[$cat]
        if ($st.Total -eq 0) { continue }
        $meta = $CategoryMeta[$cat]
        $row = [System.Collections.ArrayList]::new()
        [void]$row.Add("$($meta.Icon) $($meta.Label)")
        [void]$row.Add([string]$st.Added)
        [void]$row.Add([string]$st.Updated)
        if ($showRenamedCol) { [void]$row.Add([string]$st.Renamed) }
        if ($showMovedCol)   { [void]$row.Add([string]$st.Moved) }
        [void]$row.Add([string]$st.Deleted)
        [void]$md.AppendLine('| ' + ($row -join ' | ') + ' |')
    }

    if ($FrameworkCount -gt 0) {
        $fwRow = [System.Collections.ArrayList]::new()
        [void]$fwRow.Add('⚙️ Framework')
        [void]$fwRow.Add('—')
        [void]$fwRow.Add("$FrameworkCount file(s)")
        if ($showRenamedCol) { [void]$fwRow.Add('—') }
        if ($showMovedCol)   { [void]$fwRow.Add('—') }
        [void]$fwRow.Add('—')
        [void]$md.AppendLine('| ' + ($fwRow -join ' | ') + ' |')
    }

    if ($ForAmdCount -gt 0) {
        [void]$md.AppendLine('')
        [void]$md.AppendLine("> *Note: $ForAmdCount AMD texture variant(s) under ``Texture/ForAMD/`` are excluded from the main Texture count above and listed separately below.*")
    }

    # Detailed collapsible sections per category
    $hasDetailSections = $false
    foreach ($cat in $CategoryOrder) {
        if ($EntriesByCat[$cat].Count -gt 0) {
            $hasDetailSections = $true
            break
        }
    }

    if ($hasDetailSections) {
        [void]$md.AppendLine('')
        [void]$md.AppendLine('## Changelog')

        foreach ($cat in $CategoryOrder) {
            $allCatItems = @($EntriesByCat[$cat])
            if ($allCatItems.Count -eq 0) { continue }

            $meta = $CategoryMeta[$cat]
            $st   = $Stats[$cat]

            $summaryHeader = "$($meta.Icon) $($meta.Label) — $($st.Total) change(s)"
            if ($cat -eq 'Texture' -and $ForAmdCount -gt 0) {
                if ($st.Total -eq 0) {
                    $summaryHeader = "$($meta.Icon) $($meta.Label) — (+$ForAmdCount AMD variants)"
                } else {
                    $summaryHeader = "$($meta.Icon) $($meta.Label) — $($st.Total) change(s) (+$ForAmdCount AMD variants)"
                }
            }

            [void]$md.AppendLine('')
            [void]$md.AppendLine("<details><summary>$summaryHeader</summary>")

            $regularItems = @($allCatItems | Where-Object { -not $_.IsForAmd })
            $amdItems     = @($allCatItems | Where-Object { $_.IsForAmd })

            $grpOrder = [System.Collections.ArrayList]::new()
            $byGroup  = @{}
            foreach ($it in $regularItems) {
                if (-not $byGroup.ContainsKey($it.Group)) {
                    $byGroup[$it.Group] = [System.Collections.ArrayList]::new()
                    [void]$grpOrder.Add($it.Group)
                }
                [void]$byGroup[$it.Group].Add($it)
            }

            foreach ($g in $grpOrder) {
                [void]$md.AppendLine('')
                [void]$md.AppendLine("**$g**")
                foreach ($it in $byGroup[$g]) {
                    $editedTag = if ($it.IsEdited) { ' *(edited)*' } else { '' }
                    switch ($it.Action) {
                        'Added'   { [void]$md.AppendLine("- ➕ **Added:** $($it.Name)") }
                        'Updated' { [void]$md.AppendLine("- ✏️ **Updated:** $($it.Name)") }
                        'Renamed' { [void]$md.AppendLine("- 🏷️ **Renamed:** $($it.OldName) → $($it.Name)$editedTag") }
                        'Moved'   {
                            if ($it.OldName -cne $it.Name -and -not [string]::IsNullOrWhiteSpace($it.OldName)) {
                                [void]$md.AppendLine("- 📦 **Moved:** $($it.OldName) → $($it.Name) from ``$($it.OldGroup)``$editedTag")
                            } else {
                                [void]$md.AppendLine("- 📦 **Moved:** $($it.Name) from ``$($it.OldGroup)``$editedTag")
                            }
                        }
                        'Deleted' { [void]$md.AppendLine("- 🗑️ **Deleted:** $($it.Name)") }
                    }

                    if ($cat -eq 'Config' -and $ConfigDetailsByFile.Contains($it.Name)) {
                        $ci = $ConfigDetailsByFile[$it.Name]
                        if ($ci.CriticalNotes.Count -gt 0) {
                            foreach ($cn in $ci.CriticalNotes) {
                                [void]$md.AppendLine("  - ⚠️ $cn")
                            }
                        } elseif ($ci.HasNonCritical) {
                            [void]$md.AppendLine("  - preference/non-critical changes only")
                        }
                    }
                }
            }

            if ($amdItems.Count -gt 0) {
                [void]$md.AppendLine('')
                [void]$md.AppendLine('**AMD Texture Variants (ForAMD)**')
                foreach ($it in $amdItems) {
                    $editedTag = if ($it.IsEdited) { ' *(edited)*' } else { '' }
                    $prefix = if ($it.Group -ne 'General') { "$($it.Group)/" } else { '' }
                    switch ($it.Action) {
                        'Added'   { [void]$md.AppendLine("- ➕ **Added:** $prefix$($it.Name)") }
                        'Updated' { [void]$md.AppendLine("- ✏️ **Updated:** $prefix$($it.Name)") }
                        'Renamed' { [void]$md.AppendLine("- 🏷️ **Renamed:** $prefix$($it.OldName) → $prefix$($it.Name)$editedTag") }
                        'Moved'   { [void]$md.AppendLine("- 📦 **Moved:** $prefix$($it.Name) from ``$($it.OldGroup)``$editedTag") }
                        'Deleted' { [void]$md.AppendLine("- 🗑️ **Deleted:** $prefix$($it.Name)") }
                    }
                }
            }

            [void]$md.AppendLine('')
            [void]$md.AppendLine('</details>')
        }
    }
}

$FinalChangelog = $md.ToString().TrimEnd()

Write-Host "::group::Final Changelog"
Write-Host $FinalChangelog
Write-Host "::endgroup::"

# Update RELEASE_NOTE in current directory
$ReleaseNotePath = Join-Path (Get-Location).ProviderPath 'RELEASE_NOTE'
$existingNote = ''
if (Test-Path -LiteralPath $ReleaseNotePath) {
    $existingNote = (Get-Content -LiteralPath $ReleaseNotePath -Raw -Encoding utf8).TrimEnd()
}
if ([string]::IsNullOrWhiteSpace($existingNote)) {
    Set-Content -LiteralPath $ReleaseNotePath -Value ($FinalChangelog + "`n") -Encoding utf8
} else {
    Set-Content -LiteralPath $ReleaseNotePath -Value ($existingNote + "`n`n" + $FinalChangelog + "`n") -Encoding utf8
}

# Write CHANGES.json contract for make_announce.ps1
$ChangesObj = [ordered]@{
    PreviousTag         = $PreviousTag
    ReleaseTag          = $ReleaseTag
    ReleaseTitle        = $ReleaseTitle
    HasChanges          = $HasChanges
    TotalChanges        = $TotalChanges
    TotalAdded          = $TotalAdded
    TotalUpdated        = $TotalUpdated
    TotalRenamed        = $TotalRenamed
    TotalMoved          = $TotalMoved
    TotalDeleted        = $TotalDeleted
    TextTotal           = $Stats['Text'].Total
    TextAdded           = $Stats['Text'].Added
    TextUpdated         = $Stats['Text'].Updated
    TextRenamed         = $Stats['Text'].Renamed
    TextMoved           = $Stats['Text'].Moved
    TextDeleted         = $Stats['Text'].Deleted
    TextureTotal        = $Stats['Texture'].Total
    TextureAdded        = $Stats['Texture'].Added
    TextureUpdated      = $Stats['Texture'].Updated
    TextureRenamed      = $Stats['Texture'].Renamed
    TextureMoved        = $Stats['Texture'].Moved
    TextureDeleted      = $Stats['Texture'].Deleted
    ForAmdFiles         = $ForAmdCount
    StoryTotal          = $Stats['Story'].Total
    PluginAssetsTotal   = $Stats['PluginAssets'].Total
    FontTotal           = $Stats['Font'].Total
    PluginsTotal        = $Stats['Plugins'].Total
    ConfigTotal         = $Stats['Config'].Total
    FrameworkFiles      = $FrameworkCount
    Critical            = $CriticalConfig
    CriticalKeys        = @($AllCriticalLabels)
    Groups              = @($DiscordGroups)
}

$ChangesJsonPath = Join-Path (Get-Location).ProviderPath 'CHANGES.json'
Set-Content -LiteralPath $ChangesJsonPath -Value ($ChangesObj | ConvertTo-Json -Depth 6) -Encoding utf8
