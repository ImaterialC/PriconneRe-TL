@{
    # Plugin filename prefix -> friendly label (case-insensitive, anchored at start).
    # NOTE: [ordered] is NOT allowed here. Import-PowerShellDataFile rejects dynamic
    # expressions, so a plain hashtable must be used.
    # Keys are deliberately non-overlapping (no key is a prefix of another), so the
    # match result is deterministic regardless of hashtable enumeration order.
    Mappings = @{
        'XUnity.AutoTranslator'        = 'XUnity.AutoTranslator (MTL)'
        'XUnity.ResourceRedirector'    = 'XUnity.ResourceRedirector'
        'BepInEx.ConfigurationManager' = 'Configuration Manager'
        'ConfigurationManager'         = 'Configuration Manager'
        'PriconneTL'                   = 'PriconneTL Core Plugin'
        'GTranslateProxyServer'        = 'GTranslate Proxy (MTL)'
        'TextMeshPro'                  = 'TextMeshPro Helper'
        'FullScreenizer'               = 'FullScreenizer'
        'AssetsTools'                  = 'AssetsTools.NET'
        'classdata'                    = 'Unity Class Database'
    }
}