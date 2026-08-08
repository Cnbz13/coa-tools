local addonName = ...
local frame = CreateFrame("Frame", "CoACombatAssistantFrame", UIParent, "BackdropTemplate")
frame:SetSize(260, 112)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    CoACombatAssistantDB.position = { point, relativePoint, x, y }
end)
frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12 })
frame:SetBackdropColor(0.03, 0.04, 0.07, 0.92)
frame:SetBackdropBorderColor(0.75, 0.55, 0.25, 0.9)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("CoA Combat Assistant")

local timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
timer:SetPoint("CENTER", 0, 2)
timer:SetText("00:00")

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("BOTTOM", 0, 12)
status:SetText("Prêt — /coacombat")

local startedAt
local function SetRunning(running, label)
    if running then
        startedAt = GetTime()
        status:SetText(label or "Combat en cours")
        frame:SetScript("OnUpdate", function()
            local elapsed = math.floor(GetTime() - startedAt)
            timer:SetFormattedText("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
        end)
    else
        frame:SetScript("OnUpdate", nil)
        startedAt = nil
        status:SetText(label or "Combat terminé")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        CoACombatAssistantDB = CoACombatAssistantDB or { visible = true, history = {} }
        if CoACombatAssistantDB.position then
            self:ClearAllPoints()
            self:SetPoint(unpack(CoACombatAssistantDB.position))
        end
        if not CoACombatAssistantDB.visible then self:Hide() end
    elseif event == "ENCOUNTER_START" then
        local _, name = ...
        SetRunning(true, name)
    elseif event == "ENCOUNTER_END" then
        local _, name, _, _, success = ...
        table.insert(CoACombatAssistantDB.history, 1, { name = name, success = success == 1, duration = startedAt and math.floor(GetTime() - startedAt) or 0, at = time() })
        while #CoACombatAssistantDB.history > 20 do table.remove(CoACombatAssistantDB.history) end
        SetRunning(false, success == 1 and "Victoire" or "Rencontre terminée")
    elseif event == "PLAYER_REGEN_DISABLED" and not startedAt then
        SetRunning(true)
    elseif event == "PLAYER_REGEN_ENABLED" and startedAt then
        SetRunning(false)
    end
end)

SLASH_COACOMBAT1 = "/coacombat"
SlashCmdList.COACOMBAT = function(message)
    message = message:lower():match("^%s*(.-)%s*$")
    if message == "reset" then
        CoACombatAssistantDB.position = nil
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    elseif frame:IsShown() then
        frame:Hide()
        CoACombatAssistantDB.visible = false
    else
        frame:Show()
        CoACombatAssistantDB.visible = true
    end
end
