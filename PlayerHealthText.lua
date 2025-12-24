-- MovablePlayerHealthText.lua (robust, secret-value safe)
-- Drop into an addon and include "## SavedVariables: MovablePlayerHealthTextDB" in the .toc to persist position.

MovablePlayerHealthTextDB = MovablePlayerHealthTextDB or {}

local CONFIG = {
    font = "Fonts\\FRIZQT__.TTF",
    fontSize = 14,
    fontFlags = "OUTLINE",
    displayStyle = MovablePlayerHealthTextDB.style or "both", -- "current", "percent", "both", "both_reverse"
    separator = " - ",
    abbreviate = true,
    showOnLogin = true,
    locked = MovablePlayerHealthTextDB.locked == nil and false or MovablePlayerHealthTextDB.locked,
}

-- Safe helpers --------------------------------------------------------------

local function safe_tonumber(v)
    if type(v) == "number" then return v end
    local ok, n = pcall(tonumber, v)
    if ok and type(n) == "number" then return n end
    return nil
end



local function SafeUnitHealthPercent(unit)
    -- Prefer UnitHealthPercent if available, but guard with pcall
    if type(UnitHealthPercent) == "function" then
        local ok, pct = pcall(UnitHealthPercent, unit)
        if ok and type(pct) == "number" then return pct end
    end

    -- Fallback to computing from UnitHealth/UnitHealthMax with guarded calls
    local ok1, cur = pcall(UnitHealth, unit)
    local ok2, max = pcall(UnitHealthMax, unit)
    if not ok1 or not ok2 or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
        return nil
    end
    local okCmp, pct = pcall(function() return math.min(100, math.max(0, (cur / max) * 100)) end)
    if okCmp then return pct end
    return nil
end

local function SafeNumbers(unit)
    local ok1, cur = pcall(UnitHealth, unit)
    local ok2, max = pcall(UnitHealthMax, unit)
    if not ok1 or not ok2 then return nil, nil end
    if type(cur) ~= "number" or type(max) ~= "number" then return nil, nil end
    return cur, max
end

local function FormatText(style, cur, max, pct)
    -- Ensure cur/max/pct are numbers before formatting
    if type(cur) ~= "number" then cur = safe_tonumber(cur) end
    if type(max) ~= "number" then max = safe_tonumber(max) end
    if type(pct) ~= "number" then pct = safe_tonumber(pct) end
    if style == "percent" then
        if type(pct) ~= "number" then return "?" end
        return string.format("%.0f%%", pct)
    elseif style == "both" then
        if type(cur) ~= "number" or type(pct) ~= "number" then return "?" end
        return tostring(cur or 0) .. (CONFIG.separator or " - ") .. string.format("%.0f%%", pct)
    elseif style == "both_reverse" then
        if type(cur) ~= "number" or type(pct) ~= "number" then return "?" end
        return string.format("%.0f%%", pct) .. (CONFIG.separator or " - ") .. tostring(cur or 0)
    elseif style == "currentmax" then
        if type(cur) ~= "number" or type(max) ~= "number" then return "?" end
        return tostring(cur) .. " / " .. tostring(max)
    elseif style == "current" then
        if type(cur) ~= "number" then return "?" end
        return tostring(cur)
    end
end
-- Add abbreviation style option to SavedVariables and default


-- UI: movable frame --------------------------------------------------------

local frame = CreateFrame("Frame", "MovablePlayerHealthTextFrame", UIParent)
frame:SetSize(220, 26)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)

-- PlayerHealthText.lua (robust, taint-free, feature-matched to PlayerPowerText)
-- SavedVariables: PlayerHealthTextDB (declare in the .toc)

local ADDON = "PlayerHealthText"

-- Default settings
local defaults = {
    anchorToPlayerFrame = true,
    snapToPRD = false,
    offsetX = 0,
    offsetY = -160,
    fontChoice = "GameFontNormal",
    fontSize = 14,
    color = {1, 1, 1},
    textFormat = "currentmax", -- "currentmax", "current", "percent"
    fadeWhenFull = true,
    fadeAlpha = 0.35,
    visibleAlpha = 1.0,
    locked = false,
}

PlayerHealthTextDB = PlayerHealthTextDB or {}

local function CopyDefaults(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            CopyDefaults(dest[k], v)
        else
            if dest[k] == nil then dest[k] = v end
        end
    end
end
CopyDefaults(PlayerHealthTextDB, defaults)

-- Create main frame
local frame = CreateFrame("Frame", "PlayerHealthTextFrame", UIParent, "BackdropTemplate")
frame:SetSize(160, 24)
frame:SetParent(UIParent)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(200)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, 0)
frame:SetBackdropBorderColor(1, 1, 1, 0)

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER")
text:SetText("")
text:SetDrawLayer("OVERLAY", 7)

frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")

-- Safe helpers
local function SafeNumberCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    if type(res) == "number" then return res end
    local n = tonumber(res)
    if type(n) == "number" then return n end
    return nil
end

local function SafeGetUnitHealth(unit)
    local cur = SafeNumberCall(UnitHealth, unit)
    local max = SafeNumberCall(UnitHealthMax, unit)
    return cur, max
end

function SafeSetFont(fs, fontChoice, size, fontFlags)
    if type(fontChoice) == "string" and _G[fontChoice] and type(_G[fontChoice]) == "table" then
        fs:SetFontObject(_G[fontChoice])
        pcall(function()
            local fontPath = fs:GetFont()
            if fontPath then fs:SetFont(fontPath, size, fontFlags ~= "NONE" and fontFlags or nil) end
        end)
    else
        local ok = pcall(function() fs:SetFont(fontChoice, size, fontFlags ~= "NONE" and fontFlags or nil) end)
        if not ok then
            fs:SetFontObject(GameFontNormal)
            pcall(function()
                local fontPath = fs:GetFont()
                if fontPath then fs:SetFont(fontPath, size, fontFlags ~= "NONE" and fontFlags or nil) end
            end)
        end
    end
end

function ApplyDisplaySettings()
    local db = PlayerHealthTextDB
    -- Use PlayerPowerTextDB.fontChoice if available, for unified font dropdown
    local fontChoice = (type(_G.PlayerPowerTextDB) == "table" and _G.PlayerPowerTextDB.fontChoice) or db.fontChoice or defaults.fontChoice
    -- Use fontFlags from PersonalResourceReskin config if available, else PlayerPowerTextDB, else default
    local fontFlags = (type(_G.PersonalResourceReskinDB) == "table" and _G.PersonalResourceReskinDB.profile and _G.PersonalResourceReskinDB.profile.fontFlags)
        or (type(_G.PlayerPowerTextDB) == "table" and _G.PlayerPowerTextDB.fontFlags)
        or db.fontFlags or "OUTLINE"
    SafeSetFont(text, fontChoice, db.fontSize or defaults.fontSize, fontFlags)
    -- Use PlayerPowerTextDB.color if available, for unified color picker
    local color = (type(_G.PlayerPowerTextDB) == "table" and _G.PlayerPowerTextDB.color) or db.color or defaults.color
    local r, g, b = unpack(color)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        r, g, b = unpack(defaults.color)
    end
    text:SetTextColor(r, g, b)

    if db.snapToPRD and _G.PersonalResourceDisplayFrame then
        local prd = _G.PersonalResourceDisplayFrame
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", prd, "CENTER", db.offsetX or 0, db.offsetY or 0)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(200)
    elseif db.anchorToPlayerFrame and _G.PlayerFrame then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", _G.PlayerFrame, "BOTTOM", db.offsetX or 0, db.offsetY or -160)
        local baseLevel = 0
        if type(_G.PlayerFrame.GetFrameLevel) == "function" then
            local ok, lvl = pcall(_G.PlayerFrame.GetFrameLevel, _G.PlayerFrame)
            if ok and type(lvl) == "number" then baseLevel = lvl end
        end
        frame:SetFrameLevel(baseLevel + 20)
        frame:SetFrameStrata("DIALOG")
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 0, db.offsetY or -160)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(200)
    end

    -- Always set drag/mouse state based on locked
    if db.locked then
        frame:EnableMouse(false)
        frame:SetMovable(false)
    else
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
    end
    frame:SetScript("OnDragStart", function(self)
        if PlayerHealthTextDB.locked then return end
        if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
        if type(self.StartMoving) == "function" then pcall(self.StartMoving, self) end
    end)
    frame:SetScript("OnDragStop", function(self)
        if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
        PlayerHealthTextDB.anchorToPlayerFrame = false
        local fx, fy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if fx and fy and ux and uy then
            PlayerHealthTextDB.offsetX = math.floor(fx - ux + 0.5)
            PlayerHealthTextDB.offsetY = math.floor(fy - uy + 0.5)
        end
        if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
    end)

    if db.locked then
        if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(1, 1, 1, 0) end
    else
        if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0.45) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(1, 1, 1, 1) end
    end
    frame:SetAlpha(db.visibleAlpha or 1.0)
end

function UpdateHealthText()
    if not UnitExists("player") then
        text:SetText("")
        return
    end
    if UnitIsDeadOrGhost("player") then
        text:SetText("Dead")
        frame:Show()
        return
    end
    local db = PlayerHealthTextDB
    local cur, max = SafeGetUnitHealth("player")
    local pct = nil
    if type(cur) == "number" and type(max) == "number" and max > 0 then
        local ok, result = pcall(function() return (cur / max) * 100 end)
        if ok and type(result) == "number" and result == result then
            pct = result
        end
    end
    ApplyDisplaySettings()
    local style = db.textFormat or "currentmax"
    local textValue = FormatText(style, cur, max, pct)
    text:SetText(textValue or "")
    if db.fadeWhenFull and pct then
        local ok = pcall(function()
            if math.floor(pct + 0.5) >= 100 then
                frame:SetAlpha(db.fadeAlpha or 0.35)
            else
                frame:SetAlpha(db.visibleAlpha or 1.0)
            end
        end)
        if not ok then frame:SetAlpha(db.visibleAlpha or 1.0) end
    else
        frame:SetAlpha(db.visibleAlpha or 1.0)
    end
    frame:Show()
end

frame:SetScript("OnDragStart", function(self)
    if PlayerHealthTextDB.locked then return end
    if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
    if type(self.StartMoving) == "function" then pcall(self.StartMoving, self) end
end)
frame:SetScript("OnDragStop", function(self)
    if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
    PlayerHealthTextDB.anchorToPlayerFrame = false
    local fx, fy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if fx and fy and ux and uy then
        PlayerHealthTextDB.offsetX = math.floor(fx - ux + 0.5)
        PlayerHealthTextDB.offsetY = math.floor(fy - uy + 0.5)
    end
    if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
end)

-- Event handling
local evt = CreateFrame("Frame")
evt:RegisterUnitEvent("UNIT_HEALTH", "player")
evt:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("PLAYER_UNGHOST")
evt:RegisterEvent("PLAYER_ALIVE")
evt:RegisterEvent("PLAYER_REGEN_ENABLED")
evt:RegisterEvent("PLAYER_REGEN_DISABLED")
evt:SetScript("OnEvent", function(self, event, unit)
    if unit and unit ~= "player" then return end
    UpdateHealthText()
end)

-- Slash commands
SLASH_PLAYERHEALTHTEXT1 = "/pht"
SlashCmdList["PLAYERHEALTHTEXT"] = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    arg = (arg or ""):lower()
    if cmd == "" or cmd == "toggle" then
        if frame:IsShown() then frame:Hide(); print("Player health text hidden") else UpdateHealthText(); frame:Show(); print("Player health text shown") end
        return
    end
    if cmd == "lock" then
        PlayerHealthTextDB.locked = true
        print("Player health text locked")
        ApplyDisplaySettings()
        return
    end
    if cmd == "unlock" then
        PlayerHealthTextDB.locked = false
        print("Player health text unlocked (drag to move)")
        ApplyDisplaySettings()
        return
    end
    if cmd == "style" or cmd == "format" then
        if arg == "current" or arg == "percent" or arg == "currentmax" then
            PlayerHealthTextDB.textFormat = arg
            UpdateHealthText()
            print("Player health text format set to", arg)
        else
            print("Usage: /pht style <current|percent|currentmax>")
        end
        return
    end
    if cmd == "resetpos" then
        PlayerHealthTextDB.point = nil
        PlayerHealthTextDB.x = nil
        PlayerHealthTextDB.y = nil
        PlayerHealthTextDB.offsetX = 0
        PlayerHealthTextDB.offsetY = -160
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
        print("Player health text position reset")
        ApplyDisplaySettings()
        return
    end
    if cmd == "show" then UpdateHealthText(); frame:Show(); print("Player health text shown"); return end
    if cmd == "hide" then frame:Hide(); print("Player health text hidden"); return end
    print("Commands: /pht toggle | show | hide | lock | unlock | style <current|percent|currentmax> | resetpos")
end

-- Initial state
ApplyDisplaySettings()
UpdateHealthText()
if PlayerHealthTextDB.visibleAlpha > 0 then frame:Show() end
