# Root hashtable for Import-PowerShellDataFile (pwsh 7)
@{
    Plugins = @(
        @{ Pattern = '^src/BepInEx/plugins/PriconneTLFixup\.dll$';           Name = 'PriconneTLFixup';           Note = 'Skill/UI TL fixes & QoL' }
        @{ Pattern = '^src/BepInEx/plugins/PriconneSkillTLFixup\.dll$';      Name = 'PriconneSkillTLFixup';      Note = 'Skill description TL fixes' }
        @{ Pattern = '^src/BepInEx/plugins/AlphaSwap\.dll$';                 Name = 'AlphaSwap';                 Note = 'Alpha texture swapping (name/serif assets)' }
        @{ Pattern = '^src/BepInEx/plugins/PrincessRedirector\.dll$';        Name = 'PrincessRedirector';        Note = 'Story/asset redirection' }
        @{ Pattern = '^src/BepInEx/plugins/XUnity\.AutoTranslator/';         Name = 'XUnity.AutoTranslator';     Note = 'MTL framework — translation behavior' }
        @{ Pattern = '^src/BepInEx/plugins/XUnity\.ResourceRedirector/';     Name = 'XUnity.ResourceRedirector'; Note = 'Resource redirection for TL assets' }
        @{ Pattern = '^src/BepInEx/plugins/AssetsTools\.NET\.dll$';          Name = 'AssetsTools.NET';           Note = 'Asset bundle library (dependency)' }
        @{ Pattern = '^src/BepInEx/plugins/classdata\.tpk$';                 Name = 'classdata.tpk';             Note = 'Unity class database (dependency)' }
        @{ Pattern = '^src/BepInEx/plugins/FullScreenizer';                  Name = 'FullScreenizer';            Note = 'Fullscreen/resolution toggle (F4)' }
        @{ Pattern = '^src/BepInEx/plugins/README';                          Name = 'Plugin docs';               Note = 'Documentation only' }
    )
}
