# PriconneRe-TL Release Automation Scripts

This directory contains the PowerShell scripts and data files that generate GitHub Release notes and Discord notifications for **PriconneRe-TL**.

## File Manifest

- `initialize.ps1` — Sets UTF-8 console encoding and provides safe `.psd1` loaders, watchlist parsers, and UTF-16 surrogate-safe truncation utilities.
- `make_changelog.ps1` — Parses `git diff --name-status -M` against the previous release tag, separates **Added**, **Updated**, **Renamed**, **Moved**, and **Deleted** items, renders dynamic Summary table columns, inspects watched `.ini` / `.cfg` keys, and writes `RELEASE_NOTE` plus `CHANGES.json`.
- `make_announce.ps1` — Builds Kokkoro's deterministic seasonal/calendar/birthday greeting (`<= 380` UTF-16 chars) and the compact Discord announcement (`<= 2000` UTF-16 chars total including role mention).
- `kokkoro_greetings.psd1` — Editable dialogue pools for Kokkoro's birthday (May 11, H-6 to H+1), Gourmet Guild birthdays (H-1 to H), seasonal/calendar holidays (H-3 to H+1), and context/seasonal lines.
- `character_birthdays.psd1` — Official Japanese birthday list for 105+ *Princess Connect! Re:Dive* characters appended politely on exact birthdays.
- `changelog_blacklist.txt` — Regex patterns excluded from release changelogs (auto-generated translation dumps, backups, archives, `.psd` files).
- `config_watchlist.txt` — Sections and keys in `BepInEx/config/` that trigger a critical configuration warning banner when modified.
- `plugin_map.psd1` & `story_prefix.psd1` — Optional friendly display label mappings for plugins and story folders.
- `test_changelog.ps1` — Local acceptance and regression test suite (`pwsh -ExecutionPolicy Bypass -File .\.github\scripts\test_changelog.ps1`).
