@{
    # Folder-name prefixes under RedirectedResources -> readable group titles.
    # NOTE: [ordered] is NOT allowed (Import-PowerShellDataFile rejects it).
    # These match FOLDER names only. Files sitting at the RedirectedResources root
    # fall into group "General"; digit-based storydata labeling needs a code change.
    Prefixes = @{
        'storydata'   = 'Story Data'
        'chara'       = 'Character Stories'
        'main'        = 'Main Story'
        'event'       = 'Event Stories'
        'guild'       = 'Guild Stories'
        'tower'       = 'Tower of Luna'
        'birthday'    = 'Birthday Episodes'
        'anniversary' = 'Anniversary Specials'
    }
}