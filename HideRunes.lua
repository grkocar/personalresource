local addonName = ...
local f = CreateFrame("Frame")

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if type(_G.UpdateMoveClassResource) == "function" then
        _G.UpdateMoveClassResource()
    end
end)

function _G.UpdateMoveClassResource()
    local x, y = 0, 0
    if PersonalResourceReskin and PersonalResourceReskin.db and PersonalResourceReskin.db.profile then
        x = PersonalResourceReskin.db.profile.prdClassFrameX or 0
        y = PersonalResourceReskin.db.profile.prdClassFrameY or 0
    end
    local f = _G["prdClassFrame"]
    if f and f.ClearAllPoints and f.SetPoint then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

