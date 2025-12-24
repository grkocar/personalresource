-- Slash commands for troubleshooting: unlock, resetpos, show
SLASH_PLAYERPOWERTEXT1 = "/ppt"
SlashCmdList["PLAYERPOWERTEXT"] = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    arg = (arg or ""):lower()
    if cmd == "unlock" then
        PlayerPowerTextDB.locked = false
        print("Player power text unlocked (drag to move)")
        if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
        return
    end
    if cmd == "lock" then
        PlayerPowerTextDB.locked = true
        print("Player power text locked")
        if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
        return
    end
    if cmd == "resetpos" then
        PlayerPowerTextDB.point = nil
        PlayerPowerTextDB.x = nil
        PlayerPowerTextDB.y = nil
        PlayerPowerTextDB.offsetX = 0
        PlayerPowerTextDB.offsetY = -120
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
        print("Player power text position reset")
        if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
        return
    end
    if cmd == "show" then
        frame:Show()
        print("Player power text shown")
        return
    end
    print("Commands: /ppt unlock | lock | resetpos | show")
end
-- PlayerPowerText.lua
-- PlayerPowerText: safe, taint-free player power text with options and lock/unlock dragging via slash commands.
-- Backdrop (white border + background) is shown only when unlocked.
-- SavedVariables: PlayerPowerTextDB (declare in the .toc)

local ADDON = "PlayerPowerText"

-- Default settings
local defaults = {
    anchorToPlayerFrame = true,
    snapToPRD = false, -- new option: snap to Personal Resource Display Power Bar
    offsetX = 0,
    offsetY = -120,
    fontChoice = "GameFontNormal",
    fontSize = 14,
    fontOutline = "OUTLINE", -- new: font outline option ("NONE", "OUTLINE", "THICKOUTLINE", etc)
    color = {1, 1, 1},
    textFormat = "currentmax", -- "currentmax", "current", "percent"
    fadeWhenFull = true,
    fadeAlpha = 0.35,
    visibleAlpha = 1.0,
    locked = false, -- false = unlocked (draggable by default)
}

-- SavedVariables
PlayerPowerTextDB = PlayerPowerTextDB or {}

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
CopyDefaults(PlayerPowerTextDB, defaults)

-- Create main frame with BackdropTemplate so SetBackdrop/SetBackdropColor are available
local frame = CreateFrame("Frame", "PlayerPowerTextFrame", UIParent, "BackdropTemplate")
frame:SetSize(160, 24)
frame:SetParent(UIParent)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(200)

-- Backdrop used as a visual cue while unlocked (border + background)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
-- Start hidden (fully transparent)
frame:SetBackdropColor(0, 0, 0, 0)
frame:SetBackdropBorderColor(1, 1, 1, 0)

-- Create FontString with a Blizzard FontObject to ensure a valid font is present
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER")
text:SetText("")
text:SetDrawLayer("OVERLAY", 7)

-- Enable mouse and dragging; only allow drag when unlocked
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")

-- Safe helper to call functions that may return secret values; returns number or nil
local function SafeNumberCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    if type(res) == "number" then return res end
    local n = tonumber(res)
    if type(n) == "number" then return n end
    return nil
end

-- Safely read unit power values
local function SafeGetUnitPower(unit)
    local cur = SafeNumberCall(UnitPower, unit)
    local max = SafeNumberCall(UnitPowerMax, unit)
    if cur == nil then
        cur = SafeNumberCall(UnitPower, unit, 0)
    end
    return cur, max
end

-- Safe font setter: prefer SetFontObject for built-in FontObjects, guard SetFont with pcall
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

-- Apply display settings (font, color, anchor, strata/level, backdrop visibility)

function ApplyDisplaySettings()
    local db = PlayerPowerTextDB
    -- Font and size
    local fontChoice = (type(_G.PlayerPowerTextDB) == "table" and _G.PlayerPowerTextDB.fontChoice) or db.fontChoice or defaults.fontChoice
    local fontPath = fontChoice
    if type(fontChoice) == "string" and LibStub and LibStub("LibSharedMedia-3.0", true) then
        local LSM = LibStub("LibSharedMedia-3.0")
        local lsmFont = LSM:Fetch("font", fontChoice)
        if lsmFont then
            fontPath = lsmFont
        else
            fontPath = LSM:Fetch("font", "Friz Quadrata TT")
        end
    end
    local fontOutline = (type(_G.PlayerPowerTextDB) == "table" and _G.PlayerPowerTextDB.fontOutline) or db.fontOutline or defaults.fontOutline or "OUTLINE"
    if fontPath then
        SafeSetFont(text, fontPath, db.fontSize or defaults.fontSize, fontOutline)
    end
    -- Color
    -- Use PlayerPowerTextDB.color if available, for unified color picker
    local color = (type(_G.PlayerPowerTextDB) == "table" and _G.PlayerPowerTextDB.color) or db.color or defaults.color
    local r, g, b = unpack(color)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        r, g, b = 1, 1, 1
    end
    if text and text.SetTextColor then
        text:SetTextColor(r, g, b)
    end

    -- Position / anchor and layering
    if db.snapToPRD and _G.PersonalResourceDisplayFrame and _G.PersonalResourceDisplayFrame.PowerBar then
        local prdBar = _G.PersonalResourceDisplayFrame.PowerBar
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", prdBar, "CENTER", db.offsetX or 0, db.offsetY or 0)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(200)
    elseif db.anchorToPlayerFrame and _G.PlayerFrame then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", _G.PlayerFrame, "BOTTOM", db.offsetX or 0, db.offsetY or -120)
        local baseLevel = 0
        if type(_G.PlayerFrame.GetFrameLevel) == "function" then
            local ok, lvl = pcall(_G.PlayerFrame.GetFrameLevel, _G.PlayerFrame)
            if ok and type(lvl) == "number" then baseLevel = lvl end
        end
        frame:SetFrameLevel(baseLevel + 20)
        frame:SetFrameStrata("DIALOG")
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 0, db.offsetY or -120)
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
        if PlayerPowerTextDB.locked then return end
        if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
        if type(self.StartMoving) == "function" then pcall(self.StartMoving, self) end
    end)
    frame:SetScript("OnDragStop", function(self)
        if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
        PlayerPowerTextDB.anchorToPlayerFrame = false
        local fx, fy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if fx and fy and ux and uy then
            PlayerPowerTextDB.offsetX = math.floor(fx - ux + 0.5)
            PlayerPowerTextDB.offsetY = math.floor(fy - uy + 0.5)
        end
        if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
    end)

    -- Backdrop visibility: show border+bg only when unlocked
    -- Remove backdrop entirely so only the number is visible
    frame:SetBackdrop(nil)
    frame:SetAlpha(db.visibleAlpha or 1.0)
end

-- Update function with guarded arithmetic and secret-value handling
function UpdatePowerText()
    if not UnitExists("player") then
        text:SetText("")
        return
    end

    local db = PlayerPowerTextDB
    local cur, max = SafeGetUnitPower("player")
    local pct = nil
    if type(cur) == "number" and type(max) == "number" and max > 0 then
        local ok, result = pcall(function() return (cur / max) * 100 end)
        if ok and type(result) == "number" and result == result then
            pct = result
        end
    end

    -- Ensure font is applied before setting text to avoid "Font not set" taint
    ApplyDisplaySettings()

    if db.textFormat == "percent" and pct then
        text:SetFormattedText("%.0f%%", pct)
    elseif db.textFormat == "current" and type(cur) == "number" then
        text:SetFormattedText("%d", cur)
    elseif db.textFormat == "currentmax" and type(cur) == "number" and type(max) == "number" then
        local ok = pcall(function() text:SetFormattedText("%d / %d", cur, max) end)
        if not ok then text:SetText("") end
    else
        text:SetText("")
    end

    -- Fade when full (only when pct is valid)
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
end

-- Safe drag handlers (use pcall and function existence checks)
frame:SetScript("OnDragStart", function(self)
    if PlayerPowerTextDB.locked then return end
    if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
    if type(self.StartMoving) == "function" then pcall(self.StartMoving, self) end
end)

frame:SetScript("OnDragStop", function(self)
    if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
    -- When user drags, switch to free placement (not anchored to PlayerFrame)
    PlayerPowerTextDB.anchorToPlayerFrame = false
    -- Save offsets relative to UIParent center
    local fx, fy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if fx and fy and ux and uy then
        PlayerPowerTextDB.offsetX = math.floor(fx - ux + 0.5)
        PlayerPowerTextDB.offsetY = math.floor(fy - uy + 0.5)
    end
    if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
end)

-- Keep anchor synced if PlayerFrame moves (hook SetPoint once)
do
    local function AnchorUpdater()
        if PlayerPowerTextDB.anchorToPlayerFrame and _G.PlayerFrame then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", _G.PlayerFrame, "BOTTOM", PlayerPowerTextDB.offsetX or 0, PlayerPowerTextDB.offsetY or -120)
            local baseLevel = 0
            if type(_G.PlayerFrame.GetFrameLevel) == "function" then
                local ok, lvl = pcall(_G.PlayerFrame.GetFrameLevel, _G.PlayerFrame)
                if ok and type(lvl) == "number" then baseLevel = lvl end
            end
            frame:SetFrameLevel(baseLevel + 20)
            frame:SetFrameStrata("DIALOG")
        end
    end

    if _G.PlayerFrame and not _G.PlayerFrame.__pptHooked then
        local origSetPoint = _G.PlayerFrame.SetPoint
        _G.PlayerFrame.SetPoint = function(self, ...)
            origSetPoint(self, ...)
            AnchorUpdater()
        end
        _G.PlayerFrame.__pptHooked = true
    end
end

-- Built-in FontObject choices (safe defaults)
local FONT_CHOICES = {
    { key = "GameFontNormal", label = "GameFontNormal" },
    { key = "GameFontNormalLarge", label = "GameFontNormalLarge" },
    { key = "GameFontHighlight", label = "GameFontHighlight" },
    { key = "GameFontDisable", label = "GameFontDisable" },
}

-- ---------- Options panel (created now, registered on PLAYER_LOGIN) ----------
local panel = CreateFrame("Frame", "PlayerPowerTextOptions", UIParent)
panel.name = "PlayerPowerText"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("PlayerPowerText Settings")



-- Anchor to PlayerFrame checkbox
local anchorCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
anchorCheck:SetPoint("TOPLEFT", snapCheck, "BOTTOMLEFT", 0, -8)
anchorCheck.Text:SetText("Anchor to PlayerFrame")
anchorCheck:SetScript("OnClick", function(self)
    PlayerPowerTextDB.anchorToPlayerFrame = self:GetChecked()
    ApplyDisplaySettings()
end)

-- Unlock to move checkbox
local unlockCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
unlockCheck:SetPoint("TOPLEFT", anchorCheck, "BOTTOMLEFT", 0, -12)
unlockCheck.Text:SetText("Unlock to move (drag to place)")
unlockCheck:SetScript("OnClick", function(self)
    PlayerPowerTextDB.locked = not self:GetChecked()
    if PlayerPowerTextDB.locked then
        if type(frame.StopMovingOrSizing) == "function" then pcall(frame.StopMovingOrSizing, frame) end
        frame:EnableMouse(false)
        frame:SetMovable(false)
    else
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
    end
    ApplyDisplaySettings()
end)

-- X slider (named to avoid nil GetName)
local xSlider = CreateFrame("Slider", "PlayerPowerText_XSlider", panel, "OptionsSliderTemplate")
xSlider:SetPoint("TOPLEFT", unlockCheck, "BOTTOMLEFT", 0, -24)
xSlider:SetWidth(260)
xSlider:SetMinMaxValues(-500, 500)
xSlider:SetValueStep(1)
xSlider:SetObeyStepOnDrag(true)
do
    local txt = _G["PlayerPowerText_XSliderText"]
    if txt then txt:SetText("Offset X") end
    local low = _G["PlayerPowerText_XSliderLow"]
    local high = _G["PlayerPowerText_XSliderHigh"]
    if low then low:SetText("-500") end
    if high then high:SetText("500") end
end
xSlider:SetScript("OnValueChanged", function(self, val)
    PlayerPowerTextDB.offsetX = math.floor(val + 0.5)
    ApplyDisplaySettings()
end)

-- Y slider (named)
local ySlider = CreateFrame("Slider", "PlayerPowerText_YSlider", panel, "OptionsSliderTemplate")
ySlider:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -36)
ySlider:SetWidth(260)
ySlider:SetMinMaxValues(-500, 500)
ySlider:SetValueStep(1)
ySlider:SetObeyStepOnDrag(true)
do
    local txt = _G["PlayerPowerText_YSliderText"]
    if txt then txt:SetText("Offset Y") end
    local low = _G["PlayerPowerText_YSliderLow"]
    local high = _G["PlayerPowerText_YSliderHigh"]
    if low then low:SetText("-500") end
    if high then high:SetText("500") end
end
ySlider:SetScript("OnValueChanged", function(self, val)
    PlayerPowerTextDB.offsetY = math.floor(val + 0.5)
    ApplyDisplaySettings()
end)

-- Font dropdown
local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -24)
fontLabel:SetText("Font")

local fontDropdown = CreateFrame("Frame", "PlayerPowerTextFontDropdown", panel, "UIDropDownMenuTemplate")
fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", 10, 0)
UIDropDownMenu_SetWidth(fontDropdown, 160)

-- Font size slider
local sizeSlider = CreateFrame("Slider", "PlayerPowerText_SizeSlider", panel, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 0, -36)
sizeSlider:SetWidth(260)
sizeSlider:SetMinMaxValues(8, 36)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)
do
    local txt = _G["PlayerPowerText_SizeSliderText"]
    if txt then txt:SetText("Font Size") end
    local low = _G["PlayerPowerText_SizeSliderLow"]
    local high = _G["PlayerPowerText_SizeSliderHigh"]
    if low then low:SetText("8") end
    if high then high:SetText("36") end
end
sizeSlider:SetScript("OnValueChanged", function(self, val)
    PlayerPowerTextDB.fontSize = math.floor(val + 0.5)
    ApplyDisplaySettings()
end)

-- Color picker
local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
colorLabel:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -24)
colorLabel:SetText("Text Color")

local colorButton = CreateFrame("Button", nil, panel)
colorButton:SetSize(24, 24)
colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
colorButton.texture = colorButton:CreateTexture(nil, "BACKGROUND")
colorButton.texture:SetAllPoints()
local function UpdateColorButton()
    local r, g, b = unpack(PlayerPowerTextDB.color or defaults.color)
    if colorButton.texture.SetColorTexture then
        colorButton.texture:SetColorTexture(r, g, b, 1)
    else
        colorButton.texture:SetTexture(r, g, b, 1)
    end
end
UpdateColorButton()

colorButton:SetScript("OnClick", function()
    local r, g, b = unpack(PlayerPowerTextDB.color or defaults.color)
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame.func = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        PlayerPowerTextDB.color = {nr, ng, nb}
        UpdateColorButton()
        ApplyDisplaySettings()
    end
    ColorPickerFrame.cancelFunc = function(prev)
        local pr, pg, pb = prev.r, prev.g, prev.b
        PlayerPowerTextDB.color = {pr, pg, pb}
        UpdateColorButton()
        ApplyDisplaySettings()
    end
    ColorPickerFrame:Show()
end)



-- Text format dropdown
local formatLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
formatLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -36)
formatLabel:SetText("Text Format")

local formatDropdown = CreateFrame("Frame", "PlayerPowerTextFormatDropdown", panel, "UIDropDownMenuTemplate")
formatDropdown:SetPoint("TOPLEFT", formatLabel, "BOTTOMLEFT", 0, -8)
UIDropDownMenu_SetWidth(formatDropdown, 160)

local FORMAT_CHOICES = {
    { key = "currentmax", label = "Current / Max" },
    { key = "current", label = "Current Only" },
    { key = "percent", label = "Percent" },
}


-- Fade when full checkbox
local fadeCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
fadeCheck:SetPoint("TOPLEFT", formatDropdown, "BOTTOMLEFT", 0, -20)
fadeCheck.Text:SetText("Fade out when at full power")
fadeCheck:SetScript("OnClick", function(self)
    PlayerPowerTextDB.fadeWhenFull = self:GetChecked()
    UpdatePowerText()
end)

-- Fade alpha slider
local fadeSlider = CreateFrame("Slider", "PlayerPowerText_FadeSlider", panel, "OptionsSliderTemplate")
fadeSlider:SetPoint("TOPLEFT", fadeCheck, "BOTTOMLEFT", 0, -36)
fadeSlider:SetWidth(260)
fadeSlider:SetMinMaxValues(0.05, 1.0)
fadeSlider:SetValueStep(0.05)
fadeSlider:SetObeyStepOnDrag(true)
do
    local txt = _G["PlayerPowerText_FadeSliderText"]
    if txt then txt:SetText("Alpha when full") end
    local low = _G["PlayerPowerText_FadeSliderLow"]
    local high = _G["PlayerPowerText_FadeSliderHigh"]
    if low then low:SetText("0.05") end
    if high then high:SetText("1.0") end
end
fadeSlider:SetScript("OnValueChanged", function(self, val)
    PlayerPowerTextDB.fadeAlpha = tonumber(string.format("%.2f", val))
    UpdatePowerText()
end)

-- Reset button
local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
resetBtn:SetSize(140, 24)
resetBtn:SetText("Reset to Defaults")
resetBtn:SetScript("OnClick", function()
    PlayerPowerTextDB = {}
    CopyDefaults(PlayerPowerTextDB, defaults)
    if anchorCheck then anchorCheck:SetChecked(PlayerPowerTextDB.anchorToPlayerFrame) end
    if unlockCheck then unlockCheck:SetChecked(not PlayerPowerTextDB.locked) end
    if xSlider then xSlider:SetValue(PlayerPowerTextDB.offsetX) end
    if ySlider then ySlider:SetValue(PlayerPowerTextDB.offsetY) end
    if UIDropDownMenu_SetSelectedValue and fontDropdown then UIDropDownMenu_SetSelectedValue(fontDropdown, PlayerPowerTextDB.fontChoice) end
    if UIDropDownMenu_SetSelectedValue and formatDropdown then UIDropDownMenu_SetSelectedValue(formatDropdown, PlayerPowerTextDB.textFormat) end
    if sizeSlider then sizeSlider:SetValue(PlayerPowerTextDB.fontSize) end
    UpdateColorButton()
    if fadeCheck then fadeCheck:SetChecked(PlayerPowerTextDB.fadeWhenFull) end
    if fadeSlider then fadeSlider:SetValue(PlayerPowerTextDB.fadeAlpha) end
    ApplyDisplaySettings()
    UpdatePowerText()
end)

panel.okay = function() end
panel.refresh = function()
    if anchorCheck then anchorCheck:SetChecked(PlayerPowerTextDB.anchorToPlayerFrame) end
    if unlockCheck then unlockCheck:SetChecked(not PlayerPowerTextDB.locked) end
    if xSlider then xSlider:SetValue(PlayerPowerTextDB.offsetX) end
    if ySlider then ySlider:SetValue(PlayerPowerTextDB.offsetY) end
    if UIDropDownMenu_SetSelectedValue and fontDropdown then UIDropDownMenu_SetSelectedValue(fontDropdown, PlayerPowerTextDB.fontChoice) end
    if UIDropDownMenu_SetSelectedValue and formatDropdown then UIDropDownMenu_SetSelectedValue(formatDropdown, PlayerPowerTextDB.textFormat) end
    if sizeSlider then sizeSlider:SetValue(PlayerPowerTextDB.fontSize) end
    UpdateColorButton()
    if fadeCheck then fadeCheck:SetChecked(PlayerPowerTextDB.fadeWhenFull) end
    if fadeSlider then fadeSlider:SetValue(PlayerPowerTextDB.fadeAlpha) end
end

-- Defer adding the options panel and initialize dropdown on PLAYER_LOGIN
local optionsRegistrar = CreateFrame("Frame")
optionsRegistrar:RegisterEvent("PLAYER_LOGIN")
optionsRegistrar:SetScript("OnEvent", function(self)
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and UIDropDownMenu_SetSelectedValue then
        local function FontDropdown_OnClick(self)
            PlayerPowerTextDB.fontChoice = self.value
            UIDropDownMenu_SetSelectedValue(fontDropdown, self.value)
            ApplyDisplaySettings()
        end

        local function FontDropdown_Initialize(frame, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, f in ipairs(FONT_CHOICES) do
                info.text = f.label
                info.value = f.key
                info.func = FontDropdown_OnClick
                UIDropDownMenu_AddButton(info)
            end
        end

        UIDropDownMenu_Initialize(fontDropdown, FontDropdown_Initialize)
        UIDropDownMenu_SetSelectedValue(fontDropdown, PlayerPowerTextDB.fontChoice)

        -- Format dropdown
        local function FormatDropdown_OnClick(self)
            PlayerPowerTextDB.textFormat = self.value
            UIDropDownMenu_SetSelectedValue(formatDropdown, self.value)
            UpdatePowerText()
        end

        local function FormatDropdown_Initialize(frame, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, f in ipairs(FORMAT_CHOICES) do
                info.text = f.label
                info.value = f.key
                info.func = FormatDropdown_OnClick
                UIDropDownMenu_AddButton(info)
            end
        end

        UIDropDownMenu_Initialize(formatDropdown, FormatDropdown_Initialize)
        UIDropDownMenu_SetSelectedValue(formatDropdown, PlayerPowerTextDB.textFormat)
    end

    if anchorCheck then anchorCheck:SetChecked(PlayerPowerTextDB.anchorToPlayerFrame) end
    if unlockCheck then unlockCheck:SetChecked(not PlayerPowerTextDB.locked) end
    if xSlider then xSlider:SetValue(PlayerPowerTextDB.offsetX) end
    if ySlider then ySlider:SetValue(PlayerPowerTextDB.offsetY) end
    if sizeSlider then sizeSlider:SetValue(PlayerPowerTextDB.fontSize) end
    UpdateColorButton()
    if fadeCheck then fadeCheck:SetChecked(PlayerPowerTextDB.fadeWhenFull) end
    if fadeSlider then fadeSlider:SetValue(PlayerPowerTextDB.fadeAlpha) end

    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Slash commands
SLASH_PLAYERPOWERTEXT1 = "/ppt"
SLASH_PLAYERPOWERTEXT2 = "/playerpowertext"

SlashCmdList["PLAYERPOWERTEXT"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(%S*)") or ""
    if cmd == "lock" then
        PlayerPowerTextDB.locked = true
        if type(frame.StopMovingOrSizing) == "function" then pcall(frame.StopMovingOrSizing, frame) end
        ApplyDisplaySettings()
        print("PlayerPowerText locked.")
    elseif cmd == "unlock" then
        PlayerPowerTextDB.locked = false
        ApplyDisplaySettings()
        print("PlayerPowerText unlocked. Drag the text to place it.")
    elseif cmd == "options" or cmd == "config" or cmd == "" then
        if InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        else
            print("Interface Options are not available yet. Use /ppt unlock to move the text.")
        end
    else
        print("PlayerPowerText commands:")
        print("/ppt or /playerpowertext options - open options")
        print("/ppt unlock - allow dragging to place the text")
        print("/ppt lock - lock position and stop dragging")
    end
end

-- Events for updating
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_MAXPOWER")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:SetScript("OnEvent", function(self, event, unit)
    if (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") and unit ~= "player" then
        return
    end
    ApplyDisplaySettings()
    UpdatePowerText()
end)


-- Initial apply and update
ApplyDisplaySettings()
UpdatePowerText()

-- Listen for external font/color/fontFlags changes (from main config menu)
local lastFont, lastColor, lastFontFlags
local function MonitorExternalFontColor()
    local db = _G.PersonalResourceReskinDB and _G.PersonalResourceReskinDB.profile
    if db then
        -- Font
        if db.font and db.font ~= PlayerPowerTextDB.fontChoice then
            PlayerPowerTextDB.fontChoice = db.font
            ApplyDisplaySettings()
            UpdatePowerText()
        end
        -- Font color
        if db.fontColor and (not PlayerPowerTextDB.color or db.fontColor[1] ~= PlayerPowerTextDB.color[1] or db.fontColor[2] ~= PlayerPowerTextDB.color[2] or db.fontColor[3] ~= PlayerPowerTextDB.color[3]) then
            PlayerPowerTextDB.color = {db.fontColor[1], db.fontColor[2], db.fontColor[3]}
            ApplyDisplaySettings()
            UpdatePowerText()
        end
        -- Font style (fontFlags)
        if db.fontFlags and db.fontFlags ~= PlayerPowerTextDB.fontFlags then
            PlayerPowerTextDB.fontFlags = db.fontFlags
            ApplyDisplaySettings()
            UpdatePowerText()
        end
    end
    C_Timer.After(0.2, MonitorExternalFontColor)
end
C_Timer.After(1, MonitorExternalFontColor)

-- Patch ApplyDisplaySettings to use fontFlags and LibSharedMedia font if available
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local orig_ApplyDisplaySettings = ApplyDisplaySettings
function ApplyDisplaySettings()
    local db = PlayerPowerTextDB
    local fontFlags = db.fontFlags or (_G.PersonalResourceReskinDB and _G.PersonalResourceReskinDB.profile and _G.PersonalResourceReskinDB.profile.fontFlags) or "OUTLINE"
    local fontChoice = db.fontChoice
    if LSM and LSM:Fetch("font", fontChoice) then
        fontChoice = LSM:Fetch("font", fontChoice)
    end
    -- Font and size with style
    SafeSetFont(text, fontChoice or defaults.fontChoice, db.fontSize or defaults.fontSize, fontFlags)
    -- Color
    local r, g, b = unpack(db.color or defaults.color)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        r, g, b = unpack(defaults.color)
    end
    text:SetTextColor(r, g, b)

    -- Position / anchor and layering
    if db.anchorToPlayerFrame and _G.PlayerFrame then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", _G.PlayerFrame, "BOTTOM", db.offsetX or 0, db.offsetY or -120)
        local baseLevel = 0
        if type(_G.PlayerFrame.GetFrameLevel) == "function" then
            local ok, lvl = pcall(_G.PlayerFrame.GetFrameLevel, _G.PlayerFrame)
            if ok and type(lvl) == "number" then baseLevel = lvl end
        end
        frame:SetFrameLevel(baseLevel + 20)
        frame:SetFrameStrata("DIALOG")
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 0, db.offsetY or -120)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(200)
    end
    -- Drag logic: always allow drag when unlocked
    if not db.locked then
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self)
            if PlayerPowerTextDB.locked then return end
            if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
            if type(self.StartMoving) == "function" then pcall(self.StartMoving, self) end
        end)
        frame:SetScript("OnDragStop", function(self)
            if type(self.StopMovingOrSizing) == "function" then pcall(self.StopMovingOrSizing, self) end
            PlayerPowerTextDB.anchorToPlayerFrame = false
            local fx, fy = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if fx and fy and ux and uy then
                PlayerPowerTextDB.offsetX = math.floor(fx - ux + 0.5)
                PlayerPowerTextDB.offsetY = math.floor(fy - uy + 0.5)
            end
            if type(ApplyDisplaySettings) == "function" then pcall(ApplyDisplaySettings) end
        end)
    else
        frame:EnableMouse(false)
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    end

    -- Backdrop visibility: show border+bg only when unlocked
    if db.locked then
        -- hide backdrop and border
        if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(1, 1, 1, 0) end
    else
        -- show backdrop and border (white border, dark translucent bg)
        if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0.45) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(1, 1, 1, 1) end
    end

    -- Alpha
    frame:SetAlpha(db.visibleAlpha or 1.0)
end

-- Patch SafeSetFont to always apply fontFlags for LSM and Blizzard fonts
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
