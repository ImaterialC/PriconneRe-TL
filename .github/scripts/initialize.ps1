# ============================================================================
# initialize.ps1 - Shared Encoding, Safe Data Loaders & UTF-16 Helpers
# ============================================================================
Set-StrictMode -Version Latest

try {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = $utf8NoBom
    [Console]::InputEncoding  = $utf8NoBom
    $OutputEncoding           = $utf8NoBom
} catch {
    # Ignore non-interactive host console handle errors
}

function Get-SafePsd1Data {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [hashtable] $Default = @{}
    )
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $Default
    }
    try {
        $data = Import-PowerShellDataFile -LiteralPath $Path
        if ($data -is [hashtable]) {
            return $data
        }
    } catch {
        Write-Warning "Failed to parse PowerShell data file '$Path': $($_.Exception.Message)"
    }
    return $Default
}

function Read-WatchlistRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )
    $rules = [System.Collections.ArrayList]::new()
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return ,$rules
    }
    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8)
    $lineNo = 0
    foreach ($raw in $lines) {
        $lineNo++
        if ($null -eq $raw) { continue }
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }

        if ($line -match '^\[([^\[\]]+)\]\s*(.*)$') {
            $sec = $Matches[1].Trim()
            $key = $Matches[2].Trim()
            if ([string]::IsNullOrWhiteSpace($sec)) {
                Write-Warning "Malformed watchlist line ${lineNo} in '$Path': empty section name."
                continue
            }
            [void]$rules.Add([PSCustomObject]@{
                Section = $sec
                Key     = $key
            })
        } else {
            Write-Warning "Malformed watchlist line ${lineNo} in '$Path': '$line' (expected '[Section]' or '[Section] Key')."
        }
    }
    return ,$rules
}

function Test-HasLoneSurrogate {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Text = ''
    )
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ([char]::IsHighSurrogate($c)) {
            if (($i + 1) -ge $Text.Length -or -not [char]::IsLowSurrogate($Text[$i + 1])) {
                return $true
            }
            $i++
        } elseif ([char]::IsLowSurrogate($c)) {
            return $true
        }
    }
    return $false
}

function Limit-SafeText {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Text = '',
        [Parameter(Mandatory = $true)]
        [int] $MaxLength,
        [string] $Suffix = ''
    )
    if ($MaxLength -le 0 -or [string]::IsNullOrEmpty($Text)) {
        return ''
    }
    if ($Text.Length -le $MaxLength) {
        return $Text
    }
    $cut = $MaxLength - $Suffix.Length
    if ($cut -le 0) {
        $cut = $MaxLength
        $Suffix = ''
    }
    if ($cut -gt $Text.Length) { $cut = $Text.Length }
    if ($cut -gt 0 -and [char]::IsHighSurrogate($Text[$cut - 1])) {
        $cut--
    }
    $sub = $Text.Substring(0, $cut).TrimEnd()
    if ($sub.Length -gt 0 -and [char]::IsHighSurrogate($sub[$sub.Length - 1])) {
        $sub = $sub.Substring(0, $sub.Length - 1)
    }
    return ($sub + $Suffix)
}
