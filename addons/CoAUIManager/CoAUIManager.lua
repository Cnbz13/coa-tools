local addonName = ...
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local panel = CreateFrame("Frame", "CoAUIManagerPanel", UIParent, "BackdropTemplate")
panel:SetSize(340, 210)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12 })
panel:SetBackdropColor(0.03, 0.04, 0.07, 0.96)
panel:SetBackdropBorderColor(0.75, 0.55, 0.25, 0.9)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("CoA UI Manager")

local function NewSlider(name, label, y, low, high, step)
    local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOP", 0, y)
    slider:SetWidth(250)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    _G[name .. "Low"]:SetText(low)
    _G[name .. "High"]:SetText(high)
    _G[name .. "Text"]:SetText(label)
    return slider
end

local scale = NewSlider("CoAUIManagerScale", "Échelle de l'interface", -64, 0.64, 1.15, 0.01)
local opacity = NewSlider("CoAUIManagerOpacity", "Opacité", -125, 0.35, 1, 0.05)

scale:SetScript("OnValueChanged", function(_, value)
    if not CoAUIManagerDB then return end
    CoAUIManagerDB.scale = value
    UIParent:SetScale(value)
end)
opacity:SetScript("OnValueChanged", function(_, value)
    if not CoAUIManagerDB then return end
    CoAUIManagerDB.opacity = value
    UIParent:SetAlpha(value)
    panel:SetAlpha(1)
end)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(100, 24)
reset:SetPoint("BOTTOMLEFT", 28, 18)
reset:SetText("Réinitialiser")
reset:SetScript("OnClick", function()
    scale:SetValue(1)
    opacity:SetValue(1)
end)

local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
close:SetSize(100, 24)
close:SetPoint("BOTTOMRIGHT", -28, 18)
close:SetText("Fermer")
close:SetScript("OnClick", function() panel:Hide() end)

eventFrame:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == addonName then
        CoAUIManagerDB = CoAUIManagerDB or { scale = 1, opacity = 1 }
        scale:SetValue(CoAUIManagerDB.scale)
        opacity:SetValue(CoAUIManagerDB.opacity)
    end
end)

SLASH_COAUI1 = "/coaui"
SlashCmdList.COAUI = function() panel:SetShown(not panel:IsShown()) end
