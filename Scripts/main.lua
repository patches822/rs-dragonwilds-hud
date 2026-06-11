local UEHelpers         = require("UEHelpers")
local Config            = require("config")
local Skills            = require("skills")

local visible           = false
local refreshLoopActive = false

local function log(msg)
    print("[DragonwildsHUD] " .. msg .. "\n")
end

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
local panelIsPlaceholder = false -- true if current panel was built from placeholder skill data

local function isValid(o)
    return o and o.IsValid and o:IsValid()
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

        local hbox = StaticConstructObject(horizontal_box_cls, cellBg, FName("DragonwildsHUDCell" .. i .. "HBox"))
        cellBg:SetContent(hbox)

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
        levelText:SetColorAndOpacity({ SpecifiedColor = Config.TextColor, ColorUseRule = 0 })

        local levelSlot = hbox:AddChildToHorizontalBox(levelText)
        levelSlot:SetVerticalAlignment(VAlign_Center)
        levelSlot:SetPadding({ Left = Config.CellPadding, Top = 0, Right = 0, Bottom = 0 })

        grid:AddChildToUniformGrid(cellBg, row, col)

        cells[i] = { name = skill.name, levelText = levelText }
    end

    -- Total level footer.
    local total = StaticConstructObject(text_block_cls, vbox, FName("DragonwildsHUDTotal"))
    total.Font.Size = Config.FontSize
    total:SetColorAndOpacity({ SpecifiedColor = Config.TextColor, ColorUseRule = 0 })
    local total_slot = vbox:AddChildToVerticalBox(total)
    total_slot:SetPadding({ Left = 0, Top = Config.CellPadding * 2, Right = 0, Bottom = 0 })

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
        if cell then
            setWidgetText(cell.levelText, tostring(skill.level), cell.name)
        end
        local n = tonumber(skill.level)
        if n then
            total = total + n
        else
            incomplete = true
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
            end
            setPanelVisible(visible)
        end)
    end)
else
    log("RegisterKeyBind skipped: already registered (hot-reload)")
end

log("Loaded. F9 = toggle.")
