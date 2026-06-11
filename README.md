# DragonwildsHUD

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for *RuneScape: Dragonwilds* that adds a
toggleable HUD overlay showing your skill levels (icon + level) without opening any menus.

## Features

- Press **F9** to toggle a skill panel showing every skill's icon, current level, and total level.
- Skill levels refresh automatically every few seconds while the panel is visible.
- Each skill icon has a thin XP progress bar showing progress toward the next level.
- A skill cell briefly flashes gold when that skill levels up.
- While the panel is visible, hold **Ctrl** and the **arrow keys** to reposition it (hold to
  repeat). The new position is saved to `Scripts/hud_position.txt` and restored on the next
  launch.
- Fully configurable via `Scripts/config.lua`: hotkey, panel position, font size, icon size,
  grid columns, padding, and colors.

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) installed for RuneScape: Dragonwilds.
- A recent UE4SS **experimental** build (from the
  [`experimental-latest`](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest)
  release). Older UE4SS builds (e.g. ~September 2025 and earlier) crash the game with an access
  violation inside `UE4SS.dll` the first time a UMG `TextBlock`'s `SetText` is called — which
  happens when this mod's panel is first built. If F9 crashes your game, update UE4SS via the
  link above.

## Installation

Run `install.ps1` from the repo root in PowerShell:

```powershell
.\install.ps1
```

This auto-detects your Steam install of RSDragonwilds, creates a directory junction from the
game's `Binaries\Win64\ue4ss\Mods\DragonwildsHUD` to this repo (so edits here take effect
immediately), and registers the mod in `mods.txt`.

If the game can't be found automatically (e.g. a non-Steam install), pass its path explicitly:

```powershell
.\install.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\RSDragonwilds\RSDragonwilds"
```

Launch the game and check `UE4SS.log` for `[DragonwildsHUD] Loaded. F9 = toggle.` to confirm
the mod loaded successfully.

## Configuration

Edit `Scripts/config.lua` to adjust:

| Setting | Description |
| --- | --- |
| `HotkeyToggle` | Key that toggles the panel (default `F9`). |
| `HudX`, `HudY` | Panel position, in pixels from the top-left of the screen. |
| `FontSize` | Base text size for skill levels and the total. |
| `PanelPadding` | Padding around the whole panel. |
| `BackgroundColor`, `TextColor` | Panel background and text colors (RGBA, 0-1). |
| `IconSize` | Size of each skill icon, in pixels. |
| `GridColumns` | Number of columns in the skill grid. |
| `CellPadding` | Spacing between/around grid cells. |
| `CellBackground` | Background color of each skill cell (RGBA, 0-1). |
| `RefreshIntervalMs` | How often (in milliseconds) skill levels refresh while the panel is visible. |
| `ShowTotalLevel` | Whether to show the "Total level: N" footer beneath the skill grid. |
| `LevelUpFlashColor`, `LevelUpFlashDurationMs` | Tint and duration for the brief flash when a skill levels up. |
| `MaxLevel`, `MaxLevelColor` | Level (default 99) at which a skill's level text is highlighted in a different color. |
| `XpBarHeight`, `XpBarGap`, `XpBarColor`, `XpBarBackground` | Size, spacing, and colors of the XP progress bar shown under each skill icon. |

## Hot reloading

UE4SS's hot-reload system (`Ctrl+R` by default) reloads all mods, picking up changes to these
scripts without restarting the game. This requires `EnableHotReloadSystem = 1` in
`UE4SS-settings.ini`, which takes effect after a game restart.

## Project structure

```text
Scripts/
  main.lua    - entry point: builds the UMG panel, hotkey, refresh loop
  skills.lua  - reads live skill levels from the player's SkillComponent
  config.lua  - user-configurable settings
install.ps1   - deploys the mod via a directory junction
```
