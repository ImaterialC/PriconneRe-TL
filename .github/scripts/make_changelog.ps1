$InformationPreference = 'Continue'

function Get-ChangedFiles {
    $LatestTag = git describe --tags --abbrev=0
    $ChangedFiles = git diff --find-renames --name-status $LatestTag
    $Blacklist = Get-Content .\.github\scripts\changelog_blacklist.txt | Where-Object { $_ -notmatch "^#|^(\s|$null)$" } | Join-String -Separator "|"
    
    Write-Information "Latest tag: $LatestTag`n"
    Write-Information "::group::Changed Files`n$($ChangedFiles | Join-String -Separator "`r`n")`n::endgroup::`n"

    return ($ChangedFiles -notmatch $Blacklist)
}

function ConvertTo-ChangelogStatus {
    param (
        [parameter(ValueFromPipeline)]
        [string]
        $Status
    )

    switch -Wildcard ($Status) {
        "A*" {
            return "- Added "

        }
        "M*" {
            return "- Updated "

        }
        "R*" {
            return "- Updated "

        }
        "D*" {
            return "- Deleted "
        }
    }
}

function ConvertTo-IndexedFiles {
    param (
        [parameter(ValueFromPipeline)]
        [string]
        $FilePath
    )

    begin {
        $OtherFilesIndexing = @{
            "src/BepInEx/config/.+"                         = "default config file"
            "src/BepInEx/core/.+"                           = "BepInEx core files"
            "src/BepInEx/plugins/FullScreenizer.dll"        = "FullScreenizer"
            "src/BepInEx/plugins/PriconneTLFixup.dll"       = "PriconneTLFixup"
            "src/BepInEx/plugins/XUnity.AutoTranslator"     = "XUAT"
            "src/BepInEx/plugins/XUnity.ResourceRedirector" = "XURR"
        }
        $OtherFilesRegex = ($LogIndexing.PSOBject.Properties | Where-Object Name -eq "Keys").Value
    }
    
    process {
        foreach ($regex in $OtherFilesRegex) {
            if ($FilePath -match $regex) {
                return $OtherFilesIndexing.$regex
            }
        }

        # Default option, assume it's in "dotnet" folder
        return "framework files"
    }
}

function Get-ChangelogFileName {
    param (
        [string]$FilePath
    )
    $FilePath = $FilePath.Replace("src/BepInEx/Translation/en/", "")

    if ($FilePath -match "^Texture/.+") {
        $FileName = $FilePath.Split("/")[2]

        # This regex pattern will match
        # ". New Year Onsen" in "Texture/Event/59. New Year Onsen"
        # "_0_C [A1B7FEC8C3-2AD988C7FC].png" in "Texture/Tx_uText/tx_uTex_fl_gacha_poster_0_C [A1B7FEC8C3-2AD988C7FC].png"
        # "_01_0_C [C4C620BFFE-CB6D584BC5].png" in "Texture/Tx_uText/tx_uTex_dear_level_up_01_0_C [C4C620BFFE-CB6D584BC5].png"
        # "_aNumber [aHash-anotherHash].png" in other texture files
        $FileName = $FileName -replace "((_|\.){1}\d*)*(_0_C)* .+", ""

        return $FileName
    }

    if ($FilePath -match "^Text/Event/.+") {
        $FileName = $FilePath.Split("/")[2] -replace "\..+", ""
        return $FileName
    }

    $FileBaseName = Split-Path $FilePath -LeafBase
    return $FileBaseName
}

function Get-ChangelogParentFolder {
    param (
        [string]$FilePath
    )
    $FilePath = $FilePath.Replace("src/BepInEx/Translation/en/", "")
    $ParentFolder = $FilePath.Split("/")[1]

    if ($ParentFolder -match ".txt$") {
        return ""
    }
    
    return "${ParentFolder}: "
}

function ConvertTo-ChangelogFile {
    param (
        [parameter(ValueFromPipeline)]
        [string]
        $FilePath
    )
    $IsTranslationFile = $FilePath -match "^src/BepInEx/Translation/.+"
    
    if (!$IsTranslationFile) {
        return ($FilePath | ConvertTo-IndexedFiles)
    }

    $FileName = Get-ChangelogFileName $FilePath
    $ParentFolder = Get-ChangelogParentFolder $FilePath

    return "$ParentFolder$FileName"
}

function Get-Changelog {
    param (
        [array]$Files
    )

    $Changelog = [System.Collections.ArrayList]@()

    foreach ($file in $Files) {
        $Status, $FilePath, $NewFilePath = $file.Split("`t")
    
        $ChangelogStatus = $Status | ConvertTo-ChangelogStatus
        $ChangelogFile = $FilePath | ConvertTo-ChangelogFile
        # $ChangelogNewName = $NewFilePath | ConvertTo-ChangelogNewName

        $ChangelogFull = $ChangelogStatus + $ChangelogFile + $ChangelogNewName
        if ($ChangelogFull -notin $Changelog) {
            $null = $Changelog.Add($ChangelogFull)
        }
    }

    return ($Changelog -join "`r`n")
}

function Get-ChangelogValue {
    param (
        [string]$VarName,
        [string]$Value
    )
    
$Message = @"
<details><summary>$VarName</summary>

$Value

</details>
"@

    Write-Information $Message

    return $Message
}

$ChangedFiles = Get-ChangedFiles

$Text = Get-Changelog ($ChangedFiles -match "src/BepInEx/Translation/en/Text/" )
$Texture = Get-Changelog ($ChangedFiles -match "src/BepInEx/Translation/en/Texture/" )
$Other = Get-Changelog $ChangedFiles.Where({ $_ -match "src/" -and $_ -notmatch "src/BepInEx/Translation/" })

Write-Output "::group::Final Changelog`n"
$ListVar = "Text", "Texture", "Other"
Add-Content -Path ./RELEASE_NOTE -Value "`r`n## Changelog`r`n"
foreach ($VarName in $ListVar) {
    $Value = Get-Variable -ValueOnly $VarName
    if ($Value) {
        $NoteContent = Get-ChangelogValue -VarName $VarName -Value $Value
        Add-Content -Path ./RELEASE_NOTE -Value $NoteContent -NoNewline
    }
}
Write-Output "::endgroup::`n"