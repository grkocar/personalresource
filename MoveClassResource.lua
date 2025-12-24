-- Helper to get legacy combo scale from PersonalResourceReskin
local function GetLegacyComboScale()
    local addon = _G["PersonalResourceReskin"]
    if addon and addon.db and addon.db.profile then
        return addon.db.profile.legacyComboScale or 1
    end
    return 1
end
-- Resize Druid combo point textures using atlas 'interface/hud/uidruidcombopoints' on the Personal Resource Bar
local function ResizeDruidComboPointAtlas(width, height)
    local prd = _G.PersonalResourceDisplayFrame
    if prd and prd.ClassResourceFrame and prd.ClassResourceFrame.classResourceButtonTable then
        for _, btn in ipairs(prd.ClassResourceFrame.classResourceButtonTable) do
            for i = 1, btn:GetNumRegions() do
                local region = select(i, btn:GetRegions())
                if region and region.GetAtlas and type(region.GetAtlas) == "function" then
                    local atlas = region:GetAtlas()
                    if atlas == "interface/hud/uidruidcombopoints" then
                        region:SetSize(width, height)
                    end
                end
            end
        end
    end
end

-- Persistent hook for resizing Druid combo point atlas textures
local function HookResizeDruidComboPointAtlas()
    local width, height = 100, 100 -- Set your desired size here
    local function applyResize()
        ResizeDruidComboPointAtlas(width, height)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_POWER_UPDATE")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", applyResize)

    -- Optionally, use a timer to re-apply periodically
    C_Timer.NewTicker(2, applyResize)
end

HookResizeDruidComboPointAtlas()
-- MoveClassResource.lua
-- Moves class resource frames (runes, combo points, etc) above the Personal Resource Display health bar

local resourceFrames = {
    "ClassNameplateBarRogueFrame",
    "ClassNameplateBarDruidFrame",
    "ClassNameplateBarPaladinFrame",
    "ClassNameplateBarMonkFrame",
    "ClassNameplateBarDeathKnightFrame",
    "ClassNameplateBarMageFrame",
    -- "ClassNameplateBarWarlockFrame", -- Removed to prevent duplicate shards
    "ClassNameplateBarShamanFrame",
    "ClassNameplateBarDemonHunterFrame",
    "ClassNameplateBarEvokerFrame",
    "prdClassFrame", -- custom/third-party
}

local function getPowerBar()
    local prd = _G["PersonalResourceDisplayFrame"]
    if prd and prd.PowerBar then
        return prd.PowerBar
    end
    return prd
end

local function getResourceYOffset()
    local addon = _G["PersonalResourceReskin"]
    if addon and addon.db and addon.db.profile then
        return addon.db.profile.resourceYOffset or 14
    end
    return 14
end

local function MoveResourceFrames()
    local anchor = getPowerBar()
    if not anchor or not anchor:IsShown() then return end

    local yOffset = getResourceYOffset()
    local scale = GetLegacyComboScale()

    for _, frameName in ipairs(resourceFrames) do
        local f = _G[frameName]
        if f and f.ClearAllPoints and f.SetPoint then
            f:ClearAllPoints()
            f:SetPoint("BOTTOM", anchor, "TOP", 0, yOffset)
            if f.SetScale then
                f:SetScale(scale)
            end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_POWER_UPDATE")
f:RegisterEvent("UNIT_MAXPOWER")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:SetScript("OnEvent", function()
    C_Timer.After(0.1, MoveResourceFrames)
end)

_G.MoveClassResourceFrames = MoveResourceFrames
-- Resize Druid combo point textures using atlas 'interface/hud/uidruidcombopoints' on the Personal Resource Bar
local function ResizeDruidComboPointAtlas(width, height)
    local prd = _G.PersonalResourceDisplayFrame
    if prd and prd.ClassResourceFrame and prd.ClassResourceFrame.classResourceButtonTable then
        for _, btn in ipairs(prd.ClassResourceFrame.classResourceButtonTable) do
            for i = 1, btn:GetNumRegions() do
                local region = select(i, btn:GetRegions())
                if region and region.GetAtlas and type(region.GetAtlas) == "function" then
                    local atlas = region:GetAtlas()
                    if atlas == "interface/hud/uidruidcombopoints" then
                        region:SetSize(width, height)
                    end
                end
            end
        end
    end
end

-- Persistent hook for resizing Druid combo point atlas textures
local function HookResizeDruidComboPointAtlas()
    local width, height = 100, 100 -- Set your desired size here
    local function applyResize()
        ResizeDruidComboPointAtlas(width, height)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_POWER_UPDATE")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", applyResize)

    -- Optionally, use a timer to re-apply periodically
    C_Timer.NewTicker(2, applyResize)
end

HookResizeDruidComboPointAtlas()
