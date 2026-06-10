local UEHelpers = require("UEHelpers")

local Skills = {}

local function isValid(o)
    return o and o.IsValid and o:IsValid()
end

-- Try the GetPlayerSkillComponent() UFUNCTION first, then fall back to the SkillComponent property directly.
local function getSkillComponent()
    local pc = UEHelpers.GetPlayerController()
    if not isValid(pc) then return nil, "no PlayerController" end
    local ok, comp = pcall(function() return pc:GetPlayerSkillComponent() end)
    if ok and isValid(comp) then return comp end
    ok, comp = pcall(function() return pc.SkillComponent end)
    if ok and isValid(comp) then return comp end
    return nil, "no SkillComponent"
end

-- Returns a list of { name = "Mining", level = 12 } tables.
function Skills.Fetch()
    local comp, err = getSkillComponent()
    if not comp then
        return { { name = err or "no skill component", level = "?" } }
    end

    local skills = comp.Skills
    local n = 0
    pcall(function() n = #skills end)

    local results = {}
    for i = 1, n do
        local entry = skills[i]
        if entry then
            local sd = entry.SkillData
            local short = "?"
            if isValid(sd) then
                local fn
                pcall(function() fn = sd:GetFName():ToString() end)
                if fn and fn ~= "" then short = fn end
            end
            local lvl = 0
            pcall(function() lvl = comp:GetSkillLevel(sd) end)
            local display = short:gsub("^SKILL_", "")
            results[#results + 1] = { name = display, level = lvl }
        end
    end

    if #results == 0 then
        results[1] = { name = "No skills found", level = "?" }
    end
    return results
end

-- Maps a display name (e.g. "Woodcutting") to a Dragonwilds skill-tag icon
-- asset path, suitable for LoadAsset + Image:SetBrushFromTexture.
local ICON_DIR_OVERRIDES = {
    Fishing = "/Fishing/Art/UI/Icons/Fishing_Skill_Icons",
}

function Skills.IconPath(name)
    local dir = ICON_DIR_OVERRIDES[name] or "/Game/Art/UI/Skills/Icons/Tags"
    local asset = "T_Icon_Tag_Skill_" .. name
    return dir .. "/" .. asset .. "." .. asset
end

return Skills
