local Config                  = {}

Config.HotkeyToggle           = Key.F9

-- Panel position (pixels from the top-left corner of the screen).
-- Overridden at runtime by Scripts/hud_position.txt if it exists (see
-- Ctrl+Arrow reposition handling in main.lua).
Config.HudX                   = 20
Config.HudY                   = 200

-- How far Ctrl+Arrow nudges the panel per key press, in pixels.
Config.NudgeStep              = 4

-- Text size and panel background.
Config.FontSize               = 16
Config.PanelPadding           = 10
Config.BackgroundColor        = { R = 0.0, G = 0.0, B = 0.0, A = 0.55 }
Config.TextColor              = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

-- Skill grid layout (OSRS-style icon + level cells).
Config.IconSize               = 32
Config.GridColumns            = 3
Config.CellPadding            = 4
Config.CellBackground         = { R = 1.0, G = 1.0, B = 1.0, A = 0.08 }

-- Fixed width for the level text, so cells are the same width whether the
-- level is 1 or 2 (or 3) digits.
Config.LevelTextWidth         = 30

-- How often to refresh skill levels while the panel is visible (ms).
Config.RefreshIntervalMs      = 2000

-- Briefly tint a skill cell when its level increases since the last refresh.
Config.LevelUpFlashColor      = { R = 1.0, G = 0.84, B = 0.0, A = 0.6 }
Config.LevelUpFlashDurationMs = 1500

-- Highlight maxed skills (level 99) in a different color, OSRS-style.
Config.MaxLevel               = 99
Config.MaxLevelColor          = { R = 1.0, G = 0.84, B = 0.0, A = 1.0 }

-- XP progress bar shown under each skill icon.
Config.XpBarHeight            = 3
Config.XpBarGap               = 2
Config.XpBarColor             = { R = 1.0, G = 0.84, B = 0.0, A = 0.9 }
Config.XpBarBackground        = { R = 1.0, G = 1.0, B = 1.0, A = 0.12 }

return Config
