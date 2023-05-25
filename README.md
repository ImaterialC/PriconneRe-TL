
# PriconeTL

Princess Connect! Re:Dive Translation Project

[![Download](https://img.shields.io/github/downloads/ImaterialC/PriconeTL/total.svg?color=brightgreen&label=download&style=flat)](https://github.com/ImaterialC/PriconeTL/releases/latest "Download") [![Discord](https://img.shields.io/discord/967648014497890325?color=blue&labelColor=555555&label=discord&logo=discord&style=flat)](https://discord.gg/vZjAy67KpB "Discord") [![BepInEx](https://img.shields.io/badge/-BepInEx-yellow.svg?logo=unity&labelColor=555555&style=flat)](https://github.com/BepInEx/BepInEx "BepInEx") [![AutoTranslator](https://img.shields.io/badge/-AutoTranslator-orange.svg?logo=unity&labelColor=555555&style=flat)](https://github.com/bbepis/XUnity.AutoTranslator "AutoTranslator") [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Donate](https://img.shields.io/badge/_-donate-red.svg?logo=githubsponsors&labelColor=555555&style=flat)](#-donation "Donate")

---
**At 2023 April 12 Cygame change game system from Mono Unity 32bit into IL2CPP Unity 64bit.**
**this patch no longer available**

---
**!!! WARNING !!!**

Please use at your own risk!!  We are not responsible for any actions taken towards your account if you use this translation tool.

---

PriconeTL is an unofficial English UI patch for [Cygames' Princess Connect Re:Dive JP](https://dmg.priconne-redive.jp/). The main focus of project is translating game's user interface into English so non-Japanese people can play it easier. Any help and contribute is welcome!

## ![Tantei](https://static.wikia.nocookie.net/princess-connect/images/f/fb/Kasumi_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925082622) Table of contents

- [PriconeTL](#priconetl)
  - [ Table of contents](#-table-of-contents)
  - [ INSTALLATION](#-installation)
    - [Manual](#manual)
    - [Automatic](#automatic)
  - [ UPDATING](#-updating)
  - [ UNINSTALLATION](#-uninstallation)
  - [ SETTINGS AND OPTIONS](#-settings-and-options)
  - [ DONATION](#-donation)

## ![Nozomi](https://static.wikia.nocookie.net/princess-connect/images/4/46/Nozomi_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925084658) INSTALLATION

### Manual

0. Make sure that you installed [PriconneR](https://dmg.priconne-redive.jp/) from DMM Game Launcher, not via Android Emulator
1. Download the latest release asset from [latest release](https://github.com/ImaterialC/PriconeTL/releases/latest "Releases")
2. Extract all files from zip files to your `priconner` folder
3. Make sure your `priconner` folder looks like this

![filestructure](https://user-images.githubusercontent.com/105358849/220214406-429aeff9-c488-4e3f-a023-4f9e65336127.png)

### Automatic

Check out [touanu/PriconeTL_Updater](https://github.com/touanu/PriconeTL_Updater) for more

Simply open powershell and run the following code:

`irm https://bit.ly/3RjFnwE | iex`

*For detail instruction and help, you can join our [Discord](https://discord.gg/vZjAy67KpB). You will get a notification via @Member tag each update*

## ![Shiori](https://static.wikia.nocookie.net/princess-connect/images/7/77/Shiori_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925113434) UPDATING

It is recommended to delete the old patch files instead of just replacing them
Delete the old `BepInEx` folder then extract zip files again.

## ![Maho](https://static.wikia.nocookie.net/princess-connect/images/a/a7/Maho_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925080932) UNINSTALLATION

Simply delete patch files which were extracted to `priconner` folder
There are no Priconne files that modified or damaged while installing this patch so you can simply delete them manually. Your game will turn it back to a vanilla state.

Files that must delete for uninstalling were:
```
BepInEx
changelog.txt
doorstop_config.ini
winhttp.dll
```

Vanilla state of priconner folder was like the below picture:

![vanilla_state](https://cdn.discordapp.com/attachments/1042973733272424491/1042973733540868228/unknown.png)

## ![Kyouka](https://static.wikia.nocookie.net/princess-connect/images/3/39/Kyouka_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925113712) SETTINGS AND OPTIONS

PriconeTL uses [BepInEx](https://github.com/BepInEx/BepInEx) as framework and uses [bbepis/XUnity.AutoTranslator](https://github.com/bbepis/XUnity.AutoTranslator) plugin to translate text. Configurations of both are available too!
- [BepInEx Config](https://docs.bepinex.dev/articles/user_guide/configuration.html)
- [AutoTranslator Config](https://github.com/bbepis/XUnity.AutoTranslator#configuration)

PriconeTL also included [FineBrewDev/BepInEx.FullScreenizer](https://github.com/FineBrewDev/BepInEx.FullScreenizer). You can press F4 to toggle fullscreen

## ![Saren](https://static.wikia.nocookie.net/princess-connect/images/b/b3/Saren_Box_Icon.png/revision/latest/scale-to-width-down/40?cb=20190925084518) DONATION

Any donation is a huge encouragement for having more motivation to maintain text and texture translation. Many thanks you guys! ![KokkoroThumpUp](https://cdn.discordapp.com/emojis/974959962814021683.webp?size=32)

[![ko-fi](https://img.shields.io/badge/_-kofi-red.svg?logo=kofi&labelColor=555555&style=for-the-badge)](https://ko-fi.com/E1E5HG8RP) [![saweria](https://img.shields.io/badge/_-Saweria.co-red.svg?logo=githubsponsors&labelColor=555555&style=for-the-badge)](https://saweria.co/imaterial "Saweria.co") [![saweria](https://img.shields.io/badge/_-Patreon-red.svg?logo=patreon&labelColor=555555&style=for-the-badge)](https://patreon.com/imaterial "Saweria.co")
