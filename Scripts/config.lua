local Config             = {}

Config.HotkeyToggle      = Key.F9

-- Panel position (pixels from the top-left corner of the screen).
Config.HudX              = 20
Config.HudY              = 200

-- Text size and panel background.
Config.FontSize          = 16
Config.PanelPadding      = 10
Config.BackgroundColor   = { R = 0.0, G = 0.0, B = 0.0, A = 0.55 }
Config.TextColor         = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

-- Skill grid layout (OSRS-style icon + level cells).
Config.IconSize          = 32
Config.GridColumns       = 3
Config.CellPadding       = 4
Config.CellBackground    = { R = 1.0, G = 1.0, B = 1.0, A = 0.08 }

-- How often to refresh skill levels while the panel is visible (ms).
Config.RefreshIntervalMs = 2000

return Config
