-- ...existing code...
-- PersonalResourceReskin.lua
-- Reskins the Personal Resource Display bar using LibSharedMedia

local ADDON_NAME = ...
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if not LSM then
    print("|cffff0000[PersonalResourceReskin]|r LibSharedMedia-3.0 not loaded! Please check your TOC file and library installation.")
    return
end

local AceDB = LibStub("AceDB-3.0")
local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local PersonalResourceReskin = AceAddon:NewAddon("PersonalResourceReskin", "AceConsole-3.0")
_G["PersonalResourceReskin"] = PersonalResourceReskin

-- Register a custom texture (optional, replace with your own if needed)
LSM:Register("statusbar", "White8x8", "Interface\\AddOns\\Personal Resource Display\\media\\White8x8.tga")


local defaults = {
    profile = {
        texture = "White8x8",
        font = "Friz Quadrata TT",
        fontFlags = "OUTLINE",
        fontColor = {1, 1, 1, 1},
        powerBgColor = {0, 0, 0, 0.5},
        healthBgColor = {0, 0, 0, 0.5},
        healthBarColor = {0.2, 0.8, 0.2, 1}, -- default green
        useClassColor = false,
        width = 220, -- PowerBar width
        frameWidth = 220, -- Overall frame width
        healthTextSize = 14,
        showHealthText = true,
        comboPointSize = 24,
        comboPointScale = 1,
        legacyComboScale = 1,
    }
}

local function GetProfile()
    return PersonalResourceReskin.db and PersonalResourceReskin.db.profile or defaults.profile
end

local function ReskinBar(bar, barType)
    if not bar then return end
    local profile = GetProfile()
    local tex = LSM:Fetch("statusbar", profile.texture) or "Blizzard"
    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(tex)
    end
    -- Set or update background
    local bgColor = (barType == "power") and profile.powerBgColor or profile.healthBgColor
    if not bar.__PRD_BG then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(unpack(bgColor))
        bar.__PRD_BG = bg
    else
        bar.__PRD_BG:SetColorTexture(unpack(bgColor))
    end

    -- Add or update text
    if not bar.__PRD_Text then
        local text = bar:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        bar.__PRD_Text = text
    end
    local fontPath = LSM:Fetch("font", profile.font)
    bar.__PRD_Text:SetFont(fontPath, profile.healthTextSize or 14, profile.fontFlags ~= "NONE" and profile.fontFlags or nil)
    bar.__PRD_Text:SetTextColor(unpack(profile.fontColor))

    -- Set health bar color or class color
    if barType == "health" and bar.SetStatusBarColor then
        local color = profile.healthBarColor or {0.2, 0.8, 0.2, 1}
        if profile.useClassColor and UnitClassBase and UnitClassBase("player") then
            local class = UnitClassBase("player")
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then
                bar:SetStatusBarColor(c.r, c.g, c.b, 1)
            else
                bar:SetStatusBarColor(unpack(color))
            end
        else
            bar:SetStatusBarColor(unpack(color))
        end
    end

    -- Set width
    if barType == "power" then
        if profile.width and type(profile.width) == "number" then
            bar:SetWidth(profile.width)
        end
    elseif barType == "health" then
        if profile.healthWidth and type(profile.healthWidth) == "number" then
            bar:SetWidth(profile.healthWidth)
        end
    end
end

local function ApplyReskinToPRD()
    local prd = _G["PersonalResourceDisplayFrame"]
    if not prd then return end
    local profile = GetProfile()
    -- Always apply saved frame width
    if prd.SetWidth and profile.frameWidth then
        prd:SetWidth(profile.frameWidth)
    end
    -- Power Bar
    if prd.PowerBar then
        if profile.width then
            prd.PowerBar:SetWidth(profile.width)
        end
        ReskinBar(prd.PowerBar, "power")
    end
    -- Health Bar: try both healthBar and healthBar.healthBar
    local healthBar = nil
    if prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar then
        if prd.HealthBarsContainer.healthBar.healthBar then
            healthBar = prd.HealthBarsContainer.healthBar.healthBar
        else
            healthBar = prd.HealthBarsContainer.healthBar
        end
    end
    if healthBar then
        ReskinBar(healthBar, "health")
    end
    if type(_G.UpdateMoveClassResource) == "function" then _G.UpdateMoveClassResource() end
end


-- Hook PRD OnShow and OnEvent to reapply skin
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("UNIT_DISPLAYPOWER")
f:SetScript("OnEvent", function()
    C_Timer.After(0.5, ApplyReskinToPRD)
end)

-- Also hook PRD OnShow
hooksecurefunc(PersonalResourceDisplayFrame, "Show", function()
    C_Timer.After(0.1, ApplyReskinToPRD)
end)

-- Initial skin
C_Timer.After(1, ApplyReskinToPRD)

-- AceConfig options table
local options = {
    name = "PersonalResourceReskin",
    type = "group",
    args = {
        phtCommands = {
            name = "Player Health Text Commands",
            type = "group",
            inline = true,
            order = 0.1,
            args = {
                phtToggle = {
                    name = "Toggle Show/Hide",
                    desc = "Toggle the health text display.",
                    type = "execute",
                    func = function()
                        if _G.PlayerHealthTextDB then
                            if PlayerHealthTextDB.visibleAlpha > 0 then
                                PlayerHealthTextDB.visibleAlpha = 0
                                if PlayerHealthTextFrame then PlayerHealthTextFrame:Hide() end
                            else
                                PlayerHealthTextDB.visibleAlpha = 1
                                if PlayerHealthTextFrame then PlayerHealthTextFrame:Show() end
                            end
                        end
                    end,
                    order = 1,
                },
                phtShow = {
                    name = "Show",
                    desc = "Show the health text.",
                    type = "execute",
                    func = function()
                        if PlayerHealthTextFrame then PlayerHealthTextFrame:Show() end
                        if _G.PlayerHealthTextDB then PlayerHealthTextDB.visibleAlpha = 1 end
                    end,
                    order = 2,
                },
                phtHide = {
                    name = "Hide",
                    desc = "Hide the health text.",
                    type = "execute",
                    func = function()
                        if PlayerHealthTextFrame then PlayerHealthTextFrame:Hide() end
                        if _G.PlayerHealthTextDB then PlayerHealthTextDB.visibleAlpha = 0 end
                    end,
                    order = 3,
                },
                phtLock = {
                    name = "Lock",
                    desc = "Lock the health text frame.",
                    type = "execute",
                    func = function()
                        if _G.PlayerHealthTextDB then PlayerHealthTextDB.locked = true end
                        if type(_G.ApplyDisplaySettings) == "function" then pcall(_G.ApplyDisplaySettings) end
                    end,
                    order = 4,
                },
                phtUnlock = {
                    name = "Unlock",
                    desc = "Unlock the health text frame for dragging.",
                    type = "execute",
                    func = function()
                        if _G.PlayerHealthTextDB then PlayerHealthTextDB.locked = false end
                        if type(_G.ApplyDisplaySettings) == "function" then pcall(_G.ApplyDisplaySettings) end
                    end,
                    order = 5,
                },
                phtStyle = {
                    name = "Set Style",
                    desc = "Set health text style: current, percent, or currentmax.",
                    type = "select",
                    values = { current = "Current", percent = "Percent", currentmax = "Current / Max" },
                    get = function() return _G.PlayerHealthTextDB and _G.PlayerHealthTextDB.textFormat or "currentmax" end,
                    set = function(_, val)
                        if _G.PlayerHealthTextDB then
                            PlayerHealthTextDB.textFormat = val
                            if type(_G.UpdateHealthText) == "function" then pcall(_G.UpdateHealthText) end
                        end
                    end,
                    order = 6,
                },
                phtReset = {
                    name = "Reset Position",
                    desc = "Reset the health text position to default.",
                    type = "execute",
                    func = function()
                        if _G.PlayerHealthTextDB then
                            PlayerHealthTextDB.point = nil
                            PlayerHealthTextDB.x = nil
                            PlayerHealthTextDB.y = nil
                            PlayerHealthTextDB.offsetX = 0
                            PlayerHealthTextDB.offsetY = -160
                        end
                        if PlayerHealthTextFrame then
                            PlayerHealthTextFrame:ClearAllPoints()
                            PlayerHealthTextFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
                        end
                        if type(_G.ApplyDisplaySettings) == "function" then pcall(_G.ApplyDisplaySettings) end
                    end,
                    order = 7,
                },
            },
        },
        -- ...existing code...
        pptLock = {
            name = "Lock Player Power Text",
            desc = "Lock or unlock the PlayerPowerText frame for dragging.",
            type = "toggle",
            get = function()
                return _G.PlayerPowerTextDB and _G.PlayerPowerTextDB.locked
            end,
            set = function(_, val)
                if not _G.PlayerPowerTextDB then return end
                _G.PlayerPowerTextDB.locked = val
                local frame = _G.PlayerPowerTextFrame
                if frame and type(frame.StopMovingOrSizing) == "function" then pcall(frame.StopMovingOrSizing, frame) end
                if type(_G.ApplyDisplaySettings) == "function" then pcall(_G.ApplyDisplaySettings) end
            end,
            order = 0.6,
        },
        playerPowerTextOptions = {
            name = "Player Power Text Options",
            desc = "Open PlayerPowerText settings panel",
            type = "execute",
            func = function()
                if InterfaceOptionsFrame_OpenToCategory then
                    InterfaceOptionsFrame_OpenToCategory("PlayerPowerText")
                    InterfaceOptionsFrame_OpenToCategory("PlayerPowerText")
                else
                    print("Interface Options are not available yet. Use /ppt unlock to move the text.")
                end
            end,
            order = 0.5,
        },
        texture = {
            name = "Bar Texture",
            desc = "Select the bar texture",
            type = "select",
            values = function() return LSM:HashTable("statusbar") end,
            get = function() return GetProfile().texture end,
            set = function(_, val)
                GetProfile().texture = val
                ApplyReskinToPRD()
            end,
            dialogControl = "Dropdown",
            width = 2,
        },
        -- Font dropdown removed as requested
        -- Font style dropdown removed as requested
        fontColor = {
            name = "Font Color",
            desc = "Set the font color for bar text",
            type = "color",
            hasAlpha = true,
            get = function() return unpack(GetProfile().fontColor) end,
            set = function(_, r, g, b, a)
                GetProfile().fontColor = {r, g, b, a}
                ApplyReskinToPRD()
                -- Also update PlayerPowerText color if present
                if _G.PlayerPowerTextDB then
                    _G.PlayerPowerTextDB.color = {r, g, b}
                    if type(_G.ApplyDisplaySettings) == "function" then pcall(_G.ApplyDisplaySettings) end
                end
            end,
        },
        healthBarColor = {
            name = "Health Bar Color",
            desc = "Set the color for the health bar (overrides class color if unchecked).",
            type = "color",
            hasAlpha = true,
            get = function() return unpack(GetProfile().healthBarColor) end,
            set = function(_, r, g, b, a)
                GetProfile().healthBarColor = {r, g, b, a}
                ApplyReskinToPRD()
            end,
            disabled = function() return GetProfile().useClassColor end,
            order = 0.45,
        },
        useClassColor = {
            name = "Use Class Color",
            desc = "Use your class color for the health bar.",
            type = "toggle",
            get = function() return GetProfile().useClassColor end,
            set = function(_, val)
                GetProfile().useClassColor = val
                ApplyReskinToPRD()
            end,
            order = 0.46,
        },
        powerBgColor = {
            name = "Mana/Power Bar Background",
            desc = "Set the background color for the mana/power bar.",
            type = "color",
            hasAlpha = true,
            get = function() return unpack(GetProfile().powerBgColor) end,
            set = function(_, r, g, b, a)
                GetProfile().powerBgColor = {r, g, b, a}
                local prd = _G["PersonalResourceDisplayFrame"]
                if prd and prd.PowerBar and prd.PowerBar.__PRD_BG then
                    prd.PowerBar.__PRD_BG:SetColorTexture(r, g, b, a)
                end
                ApplyReskinToPRD()
            end,
        },
        healthBgColor = {
            name = "Health Bar Background",
            desc = "Set the background color for the health bar.",
            type = "color",
            hasAlpha = true,
            get = function() return unpack(GetProfile().healthBgColor) end,
            set = function(_, r, g, b, a)
                GetProfile().healthBgColor = {r, g, b, a}
                local prd = _G["PersonalResourceDisplayFrame"]
                if prd and prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar and prd.HealthBarsContainer.healthBar.__PRD_BG then
                    prd.HealthBarsContainer.healthBar.__PRD_BG:SetColorTexture(r, g, b, a)
                end
                ApplyReskinToPRD()
            end,
        },
        width = {
            name = "Power Bar Width",
            desc = "Adjust the width of the mana/power bar.",
            type = "range",
            min = 1,
            max = 600,
            step = 1,
            get = function() return GetProfile().width end,
            set = function(_, val)
                GetProfile().width = val
                local prd = _G["PersonalResourceDisplayFrame"]
                if prd and prd.PowerBar then
                    prd.PowerBar:SetWidth(val)
                end
                ApplyReskinToPRD()
            end,
            order = 0.81,
        },
        frameWidth = {
            name = "Overall Frame Width",
            desc = "Adjust the width of the entire Personal Resource Display frame (affects all bars).",
            type = "range",
            min = 1,
            max = 600,
            step = 1,
            get = function() return GetProfile().frameWidth end,
            set = function(_, val)
                GetProfile().frameWidth = val
                local prd = _G["PersonalResourceDisplayFrame"]
                if prd and prd.SetWidth then
                    prd:SetWidth(val)
                end
                ApplyReskinToPRD()
            end,
            order = 0.8,
        },
        resourceYOffset = {
            name = "Class Resource Y Offset",
            desc = "Move the class resource bar up/down above the power bar.",
            type = "range",
            min = -50,
            max = 50,
            step = 1,
            get = function()
                return PersonalResourceReskin.db and PersonalResourceReskin.db.profile and (PersonalResourceReskin.db.profile.resourceYOffset or 14) or 14
            end,
            set = function(_, val)
                if PersonalResourceReskin.db and PersonalResourceReskin.db.profile then
                    PersonalResourceReskin.db.profile.resourceYOffset = val
                    if type(_G.MoveClassResourceFrames) == "function" then _G.MoveClassResourceFrames() end
                end
            end,
            order = 0.83,
        },
        legacyComboScale = {
            name = "Legacy Combo Scale",
            desc = "Set the scale of legacy combo point frames.",
            type = "range",
            min = 0.5,
            max = 5,
            step = 0.01,
            get = function()
                return PersonalResourceReskin.db and PersonalResourceReskin.db.profile and (PersonalResourceReskin.db.profile.legacyComboScale or 1) or 1
            end,
            set = function(_, val)
                if PersonalResourceReskin.db and PersonalResourceReskin.db.profile then
                    PersonalResourceReskin.db.profile.legacyComboScale = val
                    -- Live update all resource frames using MoveClassResourceFrames if available
                    if type(_G.MoveClassResourceFrames) == "function" then
                        _G.MoveClassResourceFrames()
                    end
                    -- Example: apply to a legacy combo frame if it exists
                    if _G.LegacyComboFrame and _G.LegacyComboFrame.SetScale then
                        _G.LegacyComboFrame:SetScale(val)
                    end
                end
            end,
            order = 0.834,
        },
        comboPointScale = {
            name = "Combo Points Scale",
            desc = "Set the scale of Rogue combo points.",
            type = "range",
            min = 0.5,
            max = 2,
            step = 0.01,
            get = function()
                return PersonalResourceReskin.db and PersonalResourceReskin.db.profile and (PersonalResourceReskin.db.profile.comboPointScale or 1) or 1
            end,
            set = function(_, val)
                if PersonalResourceReskin.db and PersonalResourceReskin.db.profile then
                    PersonalResourceReskin.db.profile.comboPointScale = val
                    if type(_G.MoveClassResourceFrames) == "function" then _G.MoveClassResourceFrames() end
                    -- Apply scale to combo points and runes if they exist
                    if _G.PersonalResourceDisplayFrame and _G.PersonalResourceDisplayFrame.classResourceFrame then
                        local frame = _G.PersonalResourceDisplayFrame.classResourceFrame
                        if frame.SetScale then
                            frame:SetScale(val)
                        end
                        -- If combo points are individual frames, scale them too
                        if frame.comboPoints then
                            for i = 1, #frame.comboPoints do
                                if frame.comboPoints[i] and frame.comboPoints[i].SetScale then
                                    frame.comboPoints[i]:SetScale(val)
                                end
                            end
                        end
                        -- If runes are present, scale all rune subframes
                        if frame.Rune1 then
                            for runeIndex = 1, 6 do
                                local rune = frame["Rune" .. runeIndex]
                                if rune then
                                    for _, subName in ipairs({"BG_Active","BG_Inactive","BG_Shadow","Glow","Glow2","Rune_Active","Rune_Eyes","Rune_Grad","Rune_Inactive","Rune_Lines","Rune_Mid","Smoke"}) do
                                        local subFrame = rune[subName]
                                        if subFrame and subFrame.SetScale then
                                            subFrame:SetScale(val)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end,
            order = 0.835,
        },
        comboPointSize = {
            name = "Combo Points Size",
            desc = "Set the size of Rogue combo points.",
            type = "range",
            min = 10,
            max = 60,
            step = 1,
            get = function()
                return PersonalResourceReskin.db and PersonalResourceReskin.db.profile and (PersonalResourceReskin.db.profile.comboPointSize or 24) or 24
            end,
            set = function(_, val)
                if PersonalResourceReskin.db and PersonalResourceReskin.db.profile then
                    PersonalResourceReskin.db.profile.comboPointSize = val
                    if type(_G.MoveClassResourceFrames) == "function" then _G.MoveClassResourceFrames() end
                end
            end,
            order = 0.84,
        },
        -- (X/Y offset config options for runes removed, restoring to previous state)
    },
}

function PersonalResourceReskin:OnInitialize()
    self.db = AceDB:New("PersonalResourceReskinDB", defaults, true)
    AceConfig:RegisterOptionsTable("PersonalResourceReskin", options)
    AceConfigDialog:AddToBlizOptions("PersonalResourceReskin", "PersonalResourceReskin")
end

function PersonalResourceReskin:OnEnable()
    ApplyReskinToPRD()
end
