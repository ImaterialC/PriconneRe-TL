<h2 align="center">
<img src=".github/assets/logo.png" style="vertical-align: bottom">

[![Download](https://img.shields.io/github/downloads/ImaterialC/PriconneRe-TL/total.svg?color=brightgreen&label=download&style=flat)](https://github.com/ImaterialC/PriconneRe-TL/releases/latest "Download") [![Discord](https://img.shields.io/discord/967648014497890325?color=blue&labelColor=555555&label=discord&logo=discord&style=flat)](https://discord.gg/vZjAy67KpB "Discord") [![BepInEx](https://img.shields.io/badge/-BepInEx-yellow.svg?logo=unity&labelColor=555555&style=flat)](https://github.com/BepInEx/BepInEx "BepInEx") [![AutoTranslator](https://img.shields.io/badge/-AutoTranslator-orange.svg?logo=unity&labelColor=555555&style=flat)](https://github.com/bbepis/XUnity.AutoTranslator "AutoTranslator") [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Donate](https://img.shields.io/badge/_-donate-red.svg?logo=githubsponsors&labelColor=555555&style=flat)](#-donation "Donate")

<i>An English patch for Princess Connect! ReDive JP server</i>
</h2>

---

⚠️ **Warning:** _Please use it at your own risk!!  We are not responsible for any actions taken toward your account if you use this translation tool_

Priconne Re: TL is an unofficial English UI patch for [Cygames' Princess Connect Re: Dive JP](https://dmg.priconne-redive.jp/). This project's main focus is translating the game's user interface into English so non-Japanese people can play it easier.

_Any help and contributions are welcome!_

---

## ![Tantei](https://static.wikia.nocookie.net/princess-connect/images/f/fb/Kasumi_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925082622) Table of contents
- [ Table of contents](#-table-of-contents)
- [ INSTALLATION](#-installation)
- [ UPDATING](#-updating)
- [ UNINSTALLATION](#-uninstallation)
- [ SETTINGS, OPTIONS, AND FEATURES](#-settings-options-and-features)
- [ DONATION](#-donation)


## ![Nozomi](https://static.wikia.nocookie.net/princess-connect/images/4/46/Nozomi_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925084658) INSTALLATION

1. Make sure that you installed [PriconneR](https://dmg.priconne-redive.jp/) from DMM Game Launcher, not via Android Emulator
2. Download the latest release asset from [latest release](https://github.com/ImaterialC/PriconneRe-TL/releases/latest "Releases")
3. Extract all files from zip files to your `priconner` folder
4. Make sure your `priconner` folder looks like this

![Patched](https://github.com/ImaterialC/PriconneRe-TL/assets/105358849/f9ef7290-1ed4-41d4-b55e-616cb3d84636)

_The first run will cause a freeze for minutes, the second run and so on will be like usual._

## ![Shiori](https://static.wikia.nocookie.net/princess-connect/images/7/77/Shiori_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925113434) UPDATING

It is recommended to delete the old patch files instead of just replacing them

Delete the old `BepInEx` folder then extract the zip files again.

## ![Maho](https://static.wikia.nocookie.net/princess-connect/images/a/a7/Maho_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925080932) UNINSTALLATION

Simply delete patch files that were extracted to the `priconner` folder
No Priconne files that were modified or damaged while installing this patch so you can simply delete them manually. Your game will turn back to a vanilla state.

Files that must delete for uninstalling were:
```
BepInEx
dotnet
changelog.txt
doorstop_config.ini
winhttp.dll
.doorstop_version
```

The Vanilla state of the priconner folder was like the below picture:
![Vanila state](https://github.com/ImaterialC/PriconneRe-TL/assets/105358849/3d5823e6-5f67-42be-aaa7-dd2c452535a5)

## ![Kyouka](https://static.wikia.nocookie.net/princess-connect/images/3/39/Kyouka_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925113712) SETTINGS, OPTIONS, AND FEATURES

- Using [A fork of BepInEx Bleeding Edge](https://github.com/krulci/BepInEx) as the framework to inject [Kevga/XUnity.AutoTranslator](https://github.com/Kevga/XUnity.AutoTranslator) plugin.
- You can find their config here:
  - [BepInEx Config](https://docs.bepinex.dev/articles/user_guide/configuration.html)
  - [AutoTranslator Config](https://github.com/bbepis/XUnity.AutoTranslator#configuration)
- [krulci/BepInEx.FullScreenizer](https://github.com/krulci/FullScreenizer). You can press F4 to toggle fullscreen
- 16:9 aspect ratio and can maximize or adjust client sizes larger than 720p for a better experience on the modern monitor resolution.
- 2 strategies on textures based on size for Atlases and Name for others else, it will auto revert when textures are changed and unusable. **Unfortunately, AMD GPU users will need to replace atlas textures manually due to different compressing sizes.**

## ![Saren](https://static.wikia.nocookie.net/princess-connect/images/b/b3/Saren_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925084518) DONATION

Any donation is a huge encouragement for having more motivation to maintain text and texture translation. Many thanks, You guys! ![KokkoroThumpUp](https://cdn.discordapp.com/emojis/974959962814021683.webp?size=32)

Your name will appear on monthly video on [my channel](https://www.youtube.com/playlist?list=PL7rvyKiF8qfl4WgOAcSOuYnkg4fEbL66c)

[![ko-fi](https://img.shields.io/badge/_-kofi-red.svg?logo=kofi&labelColor=555555&style=for-the-badge)](https://ko-fi.com/E1E5HG8RP) [![saweria](https://img.shields.io/badge/_-Saweria.co-red.svg?logo=githubsponsors&labelColor=555555&style=for-the-badge)](https://saweria.co/imaterial "Saweria.co") [![patreon](https://img.shields.io/badge/_-Patreon-red.svg?logo=patreon&labelColor=555555&style=for-the-badge)](https://patreon.com/imaterial "patreon.com")
