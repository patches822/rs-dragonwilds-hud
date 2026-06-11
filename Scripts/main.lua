local UEHelpers         = require("UEHelpers")
local Config            = require("config")
local Skills            = require("skills")

local visible           = false
local refreshLoopActive = false
local nudgeLoopActive   = false

local function log(msg)
    print("[DragonwildsHUD] " .. msg .. "\n")
end

-- ---------------------------------------------------------------------------
-- Panel position persistence (Ctrl+Arrow reposition, see bottom of file).
-- ---------------------------------------------------------------------------
local function getScriptDir()
    local source = debug.getinfo(1, "S").source
    source = source:match("^@(.*)$") or source
    return source:match("^(.*)[/\\]")
end

local POSITION_FILE = getScriptDir() and (getScriptDir() .. "\\hud_position.txt")

local function loadSavedPosition()
    if not POSITION_FILE then return end
    local f = io.open(POSITION_FILE, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    local x, y = content:match("(-?%d+),(-?%d+)")
    if x and y then
        Config.HudX = tonumber(x)
        Config.HudY = tonumber(y)
    end
end

local function savePosition()
    if not POSITION_FILE then return end
    local f = io.open(POSITION_FILE, "w")
    if not f then
        log("savePosition: failed to open " .. POSITION_FILE)
        return
    end
    f:write(tostring(Config.HudX) .. "," .. tostring(Config.HudY))
    f:close()
end

loadSavedPosition()

-- ---------------------------------------------------------------------------------------
-- Custom UMG panel, built entirely from /Script/UMG C++ classes via StaticConstructObject
-- ---------------------------------------------------------------------------------------
local Visibility_HIDDEN = 2
local Visibility_SELF_HIT_TEST_INVISIBLE = 4
local VAlign_Center = 2

local panelCanvas = nil
local panelBorder = nil
local panelCells = nil
local panelTotalText = nil
local panelSlot = nil
local panelIsPlaceholder = false -- true if current panel was built from placeholder skill data

local function isValid(o)
    return o and o.IsValid and o:IsValid()
end

-- Color a skill's level text gold once it's maxed (Config.MaxLevel), white otherwise.
local function levelTextColor(level)
    local n = tonumber(level)
    if n and n >= Config.MaxLevel then
        return Config.MaxLevelColor
    end
    return Config.TextColor
end

local function setWidgetText(widget, text, label)
    if not isValid(widget) then return end
    local ok, err = pcall(function()
        widget:SetText(FText(text))
    end)
    if not ok then
        log("setWidgetText: failed for " .. label .. ": " .. tostring(err))
    end
end

-- Remove the previously-constructed panel from the viewport so ensurePanel()
-- can safely rebuild (used when transitioning from placeholder to real data).
local function teardownPanel()
    if isValid(panelBorder) then
        pcall(function() panelBorder:RemoveFromParent() end)
    end
    if isValid(panelCanvas) then
        pcall(function() panelCanvas:RemoveFromParent() end)
    end
    panelCanvas = nil
    panelBorder = nil
    panelCells = nil
    panelTotalText = nil
    panelSlot = nil
    panelIsPlaceholder = false
end

local function ensurePanel()
    if isValid(panelBorder) then return true end

    local game_instance
    local ok_gi = pcall(function() game_instance = UEHelpers.GetGameInstance() end)
    if not ok_gi or not game_instance then
        log("ensurePanel: GetGameInstance failed")
        return false
    end

    local user_widget_cls    = StaticFindObject("/Script/UMG.UserWidget")
    local widget_tree_cls    = StaticFindObject("/Script/UMG.WidgetTree")
    local canvas_panel_cls   = StaticFindObject("/Script/UMG.CanvasPanel")
    local border_cls         = StaticFindObject("/Script/UMG.Border")
    local text_block_cls     = StaticFindObject("/Script/UMG.TextBlock")
    local image_cls          = StaticFindObject("/Script/UMG.Image")
    local vertical_box_cls   = StaticFindObject("/Script/UMG.VerticalBox")
    local grid_cls           = StaticFindObject("/Script/UMG.UniformGridPanel")
    local horizontal_box_cls = StaticFindObject("/Script/UMG.HorizontalBox")
    local size_box_cls       = StaticFindObject("/Script/UMG.SizeBox")
    if not (user_widget_cls and widget_tree_cls and canvas_panel_cls and border_cls and text_block_cls
            and image_cls and vertical_box_cls and grid_cls and horizontal_box_cls and size_box_cls) then
        log("ensurePanel: required UMG classes not found")
        return false
    end

    local hud = StaticConstructObject(user_widget_cls, game_instance, FName("DragonwildsHUDPanel"))
    hud.WidgetTree = StaticConstructObject(widget_tree_cls, hud, FName("DragonwildsHUDTree"))

    local canvas = StaticConstructObject(canvas_panel_cls, hud.WidgetTree, FName("DragonwildsHUDCanvas"))
    hud.WidgetTree.RootWidget = canvas

    local border = StaticConstructObject(border_cls, canvas, FName("DragonwildsHUDBorder"))
    border:SetBrushColor(Config.BackgroundColor)
    border:SetPadding({
        Left = Config.PanelPadding,
        Top = Config.PanelPadding,
        Right = Config.PanelPadding,
        Bottom = Config.PanelPadding,
    })

    local vbox = StaticConstructObject(vertical_box_cls, border, FName("DragonwildsHUDVBox"))
    border:SetContent(vbox)

    -- Skill grid.
    local grid = StaticConstructObject(grid_cls, vbox, FName("DragonwildsHUDGrid"))
    vbox:AddChildToVerticalBox(grid)
    grid.SlotPadding = {
        Left = Config.CellPadding,
        Top = Config.CellPadding,
        Right = Config.CellPadding,
        Bottom = Config.CellPadding,
    }

    local ok_fetch, skillsList = pcall(Skills.Fetch)
    if not ok_fetch or not skillsList then
        log("ensurePanel: Skills.Fetch failed: " .. tostring(skillsList))
        skillsList = { { name = "error", level = "?", marker = Skills.PLACEHOLDER } }
    end
    panelIsPlaceholder = Skills.IsPlaceholder(skillsList)

    local cells = {}
    for i, skill in ipairs(skillsList) do
        local row = math.floor((i - 1) / Config.GridColumns)
        local col = (i - 1) % Config.GridColumns

        local cellBg = StaticConstructObject(border_cls, grid, FName("DragonwildsHUDCell" .. i .. "Bg"))
        cellBg:SetBrushColor(Config.CellBackground)
        cellBg:SetPadding({ Left = 2, Top = 2, Right = 2, Bottom = 2 })

        local cellVBox = StaticConstructObject(vertical_box_cls, cellBg, FName("DragonwildsHUDCell" .. i .. "VBox"))
        cellBg:SetContent(cellVBox)

        local hbox = StaticConstructObject(horizontal_box_cls, cellVBox, FName("DragonwildsHUDCell" .. i .. "HBox"))
        cellVBox:AddChildToVerticalBox(hbox)

        local sizeBox = StaticConstructObject(size_box_cls, hbox, FName("DragonwildsHUDCell" .. i .. "Size"))
        sizeBox:SetWidthOverride(Config.IconSize)
        sizeBox:SetHeightOverride(Config.IconSize)
        local iconSlot = hbox:AddChildToHorizontalBox(sizeBox)
        iconSlot:SetVerticalAlignment(VAlign_Center)

        local icon = StaticConstructObject(image_cls, sizeBox, FName("DragonwildsHUDCell" .. i .. "Icon"))
        sizeBox:SetContent(icon)

        local ok_tex, tex = pcall(LoadAsset, Skills.IconPath(skill.name))
        if ok_tex and tex then
            pcall(function() icon:SetBrushFromTexture(tex, false) end)
        end

        local levelText = StaticConstructObject(text_block_cls, hbox, FName("DragonwildsHUDCell" .. i .. "Level"))
        levelText.Font.Size = Config.FontSize - 2
        levelText:SetText(FText(tostring(skill.level)))
        levelText:SetColorAndOpacity({ SpecifiedColor = levelTextColor(skill.level), ColorUseRule = 0 })

        -- Fixed-width wrapper so cells don't resize between 1- and 2-digit levels.
        local levelSizeBox = StaticConstructObject(size_box_cls, hbox, FName("DragonwildsHUDCell" .. i .. "LevelSize"))
        levelSizeBox:SetWidthOverride(Config.LevelTextWidth)
        levelSizeBox:SetContent(levelText)

        local levelSlot = hbox:AddChildToHorizontalBox(levelSizeBox)
        levelSlot:SetVerticalAlignment(VAlign_Center)
        levelSlot:SetPadding({ Left = Config.CellPadding, Top = 0, Right = 0, Bottom = 0 })

        -- XP progress bar: a thin two-segment bar (filled + empty) spanning
        -- the full cell width, sized via HorizontalBox fill weights.
        local progress = tonumber(skill.progress) or 0

        local xpRow = StaticConstructObject(horizontal_box_cls, cellVBox, FName("DragonwildsHUDCell" .. i .. "XpRow"))

        local xpFillSize = StaticConstructObject(size_box_cls, xpRow, FName("DragonwildsHUDCell" .. i .. "XpFillSize"))
        xpFillSize:SetHeightOverride(Config.XpBarHeight)
        local xpFillBorder = StaticConstructObject(border_cls, xpFillSize, FName("DragonwildsHUDCell" .. i .. "XpFillBorder"))
        xpFillBorder:SetBrushColor(Config.XpBarColor)
        xpFillSize:SetContent(xpFillBorder)
        local xpFillSlot = xpRow:AddChildToHorizontalBox(xpFillSize)
        xpFillSlot:SetSize({ SizeRule = 1, Value = progress })

        local xpEmptySize = StaticConstructObject(size_box_cls, xpRow, FName("DragonwildsHUDCell" .. i .. "XpEmptySize"))
        xpEmptySize:SetHeightOverride(Config.XpBarHeight)
        local xpEmptyBorder = StaticConstructObject(border_cls, xpEmptySize, FName("DragonwildsHUDCell" .. i .. "XpEmptyBorder"))
        xpEmptyBorder:SetBrushColor(Config.XpBarBackground)
        xpEmptySize:SetContent(xpEmptyBorder)
        local xpEmptySlot = xpRow:AddChildToHorizontalBox(xpEmptySize)
        xpEmptySlot:SetSize({ SizeRule = 1, Value = 1 - progress })

        local xpRowSlot = cellVBox:AddChildToVerticalBox(xpRow)
        xpRowSlot:SetPadding({ Left = 0, Top = Config.XpBarGap, Right = 0, Bottom = 0 })

        grid:AddChildToUniformGrid(cellBg, row, col)

        cells[i] = {
            name = skill.name,
            levelText = levelText,
            bg = cellBg,
            lastLevel = tonumber(skill.level),
            lastDisplayed = skill.level,
            xpFillSlot = xpFillSlot,
            xpEmptySlot = xpEmptySlot,
            lastProgress = progress,
        }
    end

    -- Total level footer (optional).
    local total = nil
    if Config.ShowTotalLevel then
        total = StaticConstructObject(text_block_cls, vbox, FName("DragonwildsHUDTotal"))
        total.Font.Size = Config.FontSize
        total:SetColorAndOpacity({ SpecifiedColor = Config.TextColor, ColorUseRule = 0 })
        local total_slot = vbox:AddChildToVerticalBox(total)
        total_slot:SetPadding({ Left = 0, Top = Config.CellPadding * 2, Right = 0, Bottom = 0 })
    end

    local slot = canvas:AddChildToCanvas(border)
    slot:SetAutoSize(true)
    slot:SetAnchors({ Minimum = { X = 0.0, Y = 0.0 }, Maximum = { X = 0.0, Y = 0.0 } })
    slot:SetAlignment({ X = 0.0, Y = 0.0 })
    slot:SetPosition({ X = Config.HudX, Y = Config.HudY })

    canvas.Visibility = Visibility_HIDDEN
    border.Visibility = Visibility_HIDDEN

    hud:AddToViewport(50)

    panelCanvas = canvas
    panelBorder = border
    panelCells = cells
    panelTotalText = total
    panelSlot = slot
    return true
end

local function setPanelVisible(show)
    if not isValid(panelCanvas) then return end
    local vis = show and Visibility_SELF_HIT_TEST_INVISIBLE or Visibility_HIDDEN
    pcall(function() panelCanvas:SetVisibility(vis) end)
    if isValid(panelBorder) then
        pcall(function() panelBorder:SetVisibility(vis) end)
    end
end

-- Briefly tint a cell's background to highlight a level-up, then revert
-- it back to the normal cell background after a short delay.
local function flashCell(cellBg)
    if not isValid(cellBg) then return end
    pcall(function() cellBg:SetBrushColor(Config.LevelUpFlashColor) end)
    if not LoopAsync then return end
    LoopAsync(Config.LevelUpFlashDurationMs, function()
        if isValid(cellBg) then
            pcall(function() cellBg:SetBrushColor(Config.CellBackground) end)
        end
        return true
    end)
end

local function updatePanelData()
    if not panelCells then return end

    local ok_fetch, skillsList = pcall(Skills.Fetch)
    if not ok_fetch or not skillsList then
        log("updatePanelData: Skills.Fetch failed: " .. tostring(skillsList))
        return
    end

    -- If the panel was built from placeholder data but real data is now
    -- available, tear down and rebuild the panel so the grid is sized
    -- correctly.
    if panelIsPlaceholder and not Skills.IsPlaceholder(skillsList) then
        log("updatePanelData: real skill data now available, rebuilding panel")
        teardownPanel()
        if not ensurePanel() then
            log("updatePanelData: rebuild failed")
            return
        end
        setPanelVisible(visible)
    end

    local total = 0
    local incomplete = false
    for i, skill in ipairs(skillsList) do
        local cell = panelCells[i]
        if cell and cell.lastDisplayed ~= skill.level then
            setWidgetText(cell.levelText, tostring(skill.level), cell.name)
            if isValid(cell.levelText) then
                pcall(function()
                    cell.levelText:SetColorAndOpacity({ SpecifiedColor = levelTextColor(skill.level), ColorUseRule = 0 })
                end)
            end
            cell.lastDisplayed = skill.level
        end
        local n = tonumber(skill.level)
        if n then
            total = total + n
            if cell and cell.lastLevel and n > cell.lastLevel then
                flashCell(cell.bg)
            end
            if cell then cell.lastLevel = n end
        else
            incomplete = true
        end

        if cell and cell.xpFillSlot and cell.xpEmptySlot then
            local progress = tonumber(skill.progress) or 0
            if math.abs(progress - (cell.lastProgress or 0)) > 0.0005 then
                pcall(function()
                    cell.xpFillSlot:SetSize({ SizeRule = 1, Value = progress })
                    cell.xpEmptySlot:SetSize({ SizeRule = 1, Value = 1 - progress })
                end)
                cell.lastProgress = progress
            end
        end
    end

    local totalLabel = "Total level: " .. tostring(total) .. (incomplete and "+" or "")
    setWidgetText(panelTotalText, totalLabel, "Total")
end

-- While the panel is visible, periodically refresh the displayed skill
-- levels. The loop self-terminates (returns true) once the panel is
-- hidden, and is restarted the next time the panel is shown.
local function startRefreshLoop()
    if refreshLoopActive or not LoopAsync then return end
    refreshLoopActive = true
    LoopAsync(Config.RefreshIntervalMs, function()
        if not visible then
            refreshLoopActive = false
            return true
        end
        local ok, err = pcall(updatePanelData)
        if not ok then log("startRefreshLoop: updatePanelData failed: " .. tostring(err)) end
        return false
    end)
end

-- Move the panel by (dx, dy) pixels and persist the new position so it
-- survives a restart.
local function nudgePanel(dx, dy)
    Config.HudX = Config.HudX + dx
    Config.HudY = Config.HudY + dy
    if isValid(panelSlot) then
        pcall(function() panelSlot:SetPosition({ X = Config.HudX, Y = Config.HudY }) end)
    end
    savePosition()
end

-- Reposition: while Ctrl + an arrow key are held, repeatedly nudge the panel
-- every tick so users can hold the keys instead of repeatedly pressing them.
local CTRL_FKEYS = {
    { KeyName = FName("LeftControl") },
    { KeyName = FName("RightControl") },
}
local NUDGE_FKEYS = {
    { key = { KeyName = FName("Left") },  dx = -1, dy = 0 },
    { key = { KeyName = FName("Right") }, dx = 1,  dy = 0 },
    { key = { KeyName = FName("Up") },    dx = 0,  dy = -1 },
    { key = { KeyName = FName("Down") },  dx = 0,  dy = 1 },
}
local NUDGE_INTERVAL_MS = 60

local function isAnyKeyDown(pc, fkeys)
    for _, fkey in ipairs(fkeys) do
        local ok, held = pcall(function() return pc:IsInputKeyDown(fkey) end)
        if ok and held then return true end
    end
    return false
end

-- While the panel is visible, poll for Ctrl+Arrow being held and nudge the
-- panel each tick. The loop self-terminates once the panel is hidden.
local function startNudgeLoop()
    if nudgeLoopActive or not LoopAsync then return end
    nudgeLoopActive = true
    LoopAsync(NUDGE_INTERVAL_MS, function()
        if not visible then
            nudgeLoopActive = false
            return true
        end
        local ok_pc, pc = pcall(UEHelpers.GetPlayerController)
        if ok_pc and isValid(pc) and pc.IsInputKeyDown and isAnyKeyDown(pc, CTRL_FKEYS) then
            for _, nudge in ipairs(NUDGE_FKEYS) do
                local ok, held = pcall(function() return pc:IsInputKeyDown(nudge.key) end)
                if ok and held then
                    nudgePanel(nudge.dx * Config.NudgeStep, nudge.dy * Config.NudgeStep)
                end
            end
        end
        return false
    end)
end

-- ---------------------------------------------------------------------------
-- Hotkey: F9 toggles the skill-level panel.
-- ---------------------------------------------------------------------------
-- Reload guard: RegisterKeyBind has no "unregister" API, so on hot-reload
-- avoid stacking a second toggle handler for the same hotkey.
if not _G.__DragonwildsHUD_KeybindRegistered then
    _G.__DragonwildsHUD_KeybindRegistered = true
    RegisterKeyBind(Config.HotkeyToggle, function()
        ExecuteInGameThread(function()
            visible = not visible
            if not ensurePanel() then
                log("ensurePanel failed — aborting")
                return
            end
            if visible then
                local ok, err = pcall(updatePanelData)
                if not ok then log("F9 handler: updatePanelData failed: " .. tostring(err)) end
                startRefreshLoop()
                startNudgeLoop()
            end
            setPanelVisible(visible)
        end)
    end)
else
    log("RegisterKeyBind skipped: already registered (hot-reload)")
end

log("Loaded. F9 = toggle, Ctrl+Arrows = reposition while visible (hold to repeat).")
