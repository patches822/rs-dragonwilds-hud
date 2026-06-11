local UEHelpers = require("UEHelpers")

local Skills = {}

local function log(msg)
    print("[DragonwildsHUD] " .. msg .. "\n")
end

-- Sentinel marker for placeholder/error results, so callers can detect
-- "no real skill data yet" and trigger a panel rebuild once real data
-- becomes available.
Skills.PLACEHOLDER = "placeholder"

-- Returns true if `results` (the return value of Skills.Fetch()) is
-- placeholder/error data rather than real skill data.
function Skills.IsPlaceholder(results)
    return results and results[1] and results[1].marker == Skills.PLACEHOLDER
end

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

-- Returns a 0..1 fraction of progress toward the next level, or nil if it
-- can't be determined. A skill at (or beyond) the level cap is reported as
-- fully complete (1.0).
local function computeProgress(comp, sd, level)
    local ok_total, totalXP = pcall(function() return comp:GetTotalXP(sd) end)
    local ok_next, xpForNext = pcall(function() return comp:GetTotalXPNeededForNextLevel(sd) end)
    local ok_cur, xpForCurrent = pcall(function() return comp:GetTotalXPNeededForLevel(level) end)
    if not (ok_total and ok_next and ok_cur) then return nil end
    if xpForNext <= xpForCurrent then return 1.0 end

    local p = (totalXP - xpForCurrent) / (xpForNext - xpForCurrent)
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    return p
end

-- Returns a list of { name = "Mining", level = 12, progress = 0.42 } tables.
function Skills.Fetch()
    local comp, err = getSkillComponent()
    if not comp then
        return { { name = err or "no skill component", level = "?", marker = Skills.PLACEHOLDER } }
    end

    local skills
    local ok_skills = pcall(function() skills = comp.Skills end)
    if not ok_skills or not skills then
        log("Skills.Fetch: failed to read comp.Skills")
        return { { name = "skills unavailable", level = "?", marker = Skills.PLACEHOLDER } }
    end

    local n = 0
    pcall(function() n = #skills end)

    local results = {}
    for i = 1, n do
        local ok_entry, entry = pcall(function() return skills[i] end)
        if ok_entry and entry then
            local sd
            local ok_sd = pcall(function() sd = entry.SkillData end)
            if not ok_sd then sd = nil end

            local short = "?"
            if isValid(sd) then
                local fn
                pcall(function() fn = sd:GetFName():ToString() end)
                if fn and fn ~= "" then short = fn end
            end
            local display = short:gsub("^SKILL_", "")

            local lvl = "?"
            local ok_lvl, lvl_result = pcall(function() return comp:GetSkillLevel(sd) end)
            if ok_lvl and lvl_result ~= nil then
                lvl = lvl_result
            else
                log("Skills.Fetch: GetSkillLevel failed for " .. tostring(display))
            end

            local progress = nil
            if isValid(sd) and ok_lvl and lvl_result ~= nil then
                progress = computeProgress(comp, sd, lvl_result)
            end

            results[#results + 1] = { name = display, level = lvl, progress = progress }
        end
    end

    if #results == 0 then
        results[1] = { name = "No skills found", level = "?", marker = Skills.PLACEHOLDER }
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
