-- Thin Project Ascension compatibility layer for the genuine EventAlert 4.3.6 addon.
-- EventAlert remains responsible for every icon, sound, option and saved position.

local COA_COMPAT_VERSION = "1.4.0"
local BOOK = BOOKTYPE_SPELL or "spell"
local AUTO_LEARN_DEFAULT = true
local recentCasts = {}
local spellbookIds = {}
local initialized = false

local function Now()
    return GetTime and GetTime() or 0
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00EventAlert CoA:|r " .. tostring(message))
    end
end

local function IsEventAlertReady()
    return type(EA_Config) == "table"
        and type(EA_Items) == "table"
        and type(EA_AltItems) == "table"
        and type(EA_CustomItems) == "table"
        and type(EventAlert_PositionFrames) == "function"
        and type(EventAlert_DoAlert) == "function"
end

local function EnsureConfiguration()
    if not IsEventAlertReady() then return false end
    EA_Config.CoA = EA_Config.CoA or {}
    if EA_Config.CoA.AutoLearn == nil then EA_Config.CoA.AutoLearn = AUTO_LEARN_DEFAULT end
    if EA_Config.CoA.Initialized == nil then
        EA_Config.AllowAltAlerts = true
        EA_Config.CoA.Initialized = true
    end
    EA_Config.CoA.Version = COA_COMPAT_VERSION
    EA_TempBuffsTable = EA_TempBuffsTable or {}
    EA_PreLoadAlts = EA_PreLoadAlts or {}
    return true
end

local function SpellIdFromBook(slot)
    if not GetSpellLink then return nil end
    local link = GetSpellLink(slot, BOOK)
    return link and tonumber(string.match(link, "spell:(%d+)")) or nil
end

local function ScanSpellbook()
    spellbookIds = {}
    local tab, slot
    for tab = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local name = GetSpellName(slot, BOOK)
            local spellId = SpellIdFromBook(slot)
            if name and spellId then spellbookIds[name] = spellId end
        end
    end
end

local function IsActive(spellId)
    local _, value
    for _, value in ipairs(EA_TempBuffsTable or {}) do
        if value == spellId then return true end
    end
    return false
end

local function EnsureAlertFrame(spellId)
    local frameName = "EAFrame_" .. spellId
    if _G[frameName] then return _G[frameName] end
    if not EA_Main_Frame then return nil end

    local frame = CreateFrame("FRAME", frameName, EA_Main_Frame)
    if EA_Config.AllowESC == true then tinsert(UISpecialFrames, frameName) end
    frame:SetFrameStrata("DIALOG")

    frame.spellName = frame:CreateFontString(frameName .. "_Name", "OVERLAY")
    frame.spellName:SetFontObject(ChatFontNormal)
    frame.spellName:SetPoint("BOTTOM", 0, -15)

    frame.spellTimer = frame:CreateFontString(frameName .. "_Timer", "OVERLAY")
    frame.spellTimer:SetFontObject(ChatFontNormal)
    frame.spellTimer:SetPoint("TOP", 0, 20)

    frame.spellCounter = frame:CreateFontString(frameName .. "_Counter", "OVERLAY")
    frame.spellCounter:SetFontObject(ChatFontNormal)
    frame.spellCounter:SetPoint("RIGHT", 20, 0)

    frame:SetScript("OnEvent", EventAlert_OnEvent)
    return frame
end

local function RegisterAuraProc(spellId, spellName)
    if not spellId or not EnsureConfiguration() then return false end
    local learned = EA_CustomItems[spellId] == nil
    EA_CustomItems[spellId] = true
    EnsureAlertFrame(spellId)
    if learned then
        Chat("proc appris : " .. tostring(spellName or GetSpellInfo(spellId) or spellId) .. " [" .. spellId .. "]")
    end
    return learned
end

local function RegisterActiveSpell(spellId, spellName)
    if not spellId or not EnsureConfiguration() then return false end
    local learned = EA_AltItems[spellId] == nil
    EA_AltItems[spellId] = true
    if spellName then EA_PreLoadAlts[spellName] = tostring(spellId) end
    EnsureAlertFrame(spellId)
    if learned then
        Chat("reaction apprise : " .. tostring(spellName or GetSpellInfo(spellId) or spellId) .. " [" .. spellId .. "]")
    end
    return learned
end

local function Activate(spellId)
    if not spellId or IsActive(spellId) then return end
    if not EnsureAlertFrame(spellId) then return end
    table.insert(EA_TempBuffsTable, spellId)
    EventAlert_PositionFrames()
    EventAlert_DoAlert()
end

local function WasDirectlyCast(spellId, spellName)
    local castAt = recentCasts[spellId] or (spellName and recentCasts[spellName])
    return castAt and Now() - castAt < 2.5
end

local function IsTracked(spellId)
    return EA_Items[spellId] or EA_CustomItems[spellId]
end

local function IsOwnedSource(sourceGUID, sourceFlags)
    if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then return true end
    if sourceFlags and bit and bit.band and COMBATLOG_OBJECT_AFFILIATION_MINE then
        return bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
    end
    -- Several CoA triggered auras omit the source GUID on the 3.3.5 combat log.
    return sourceGUID == nil and UnitAffectingCombat and UnitAffectingCombat("player")
end

local function HandleCombatLog(...)
    if not EnsureConfiguration() then return end
    local subEvent = select(2, ...)
    local sourceGUID = select(3, ...)
    local sourceFlags = select(5, ...)
    local destGUID = select(6, ...)
    -- select() returns every argument from this position onward. Passing it
    -- directly to tonumber() accidentally supplied spellName as the numeric
    -- base on Ascension (for example 91810, "Keeper's Scroll...", 1, "BUFF").
    local rawSpellId = select(9, ...)
    local spellId = tonumber(rawSpellId)
    local spellName = select(10, ...)
    local playerGUID = UnitGUID("player")

    if subEvent == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID then
        local castAt = Now()
        if spellId then recentCasts[spellId] = castAt end
        if spellName then recentCasts[spellName] = castAt end
        return
    end

    local applied = subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_APPLIED_DOSE"
    local refreshed = subEvent == "SPELL_AURA_REFRESH"
    if (applied or refreshed) and destGUID == playerGUID and spellId then
        local tracked = IsTracked(spellId)
        if not tracked and EA_Config.CoA.AutoLearn and IsOwnedSource(sourceGUID, sourceFlags)
            and not WasDirectlyCast(spellId, spellName) then
            RegisterAuraProc(spellId, spellName)
            tracked = true
        end
        -- This companion loads after EventAlert. Activate here so the very first
        -- occurrence is visible; IsActive prevents duplicates on known procs.
        if tracked then Activate(spellId) end
    end
end

local function HandleSpellActive(spellName)
    if not spellName or not EnsureConfiguration() then return end
    local spellId = spellbookIds[spellName]
    if not spellId then ScanSpellbook(); spellId = spellbookIds[spellName] end
    if spellId then
        RegisterActiveSpell(spellId, spellName)
        Activate(spellId)
    end
end

local function CountEntries(values)
    local count = 0
    for _, enabled in pairs(values or {}) do if enabled then count = count + 1 end end
    return count
end

local function CoAStatus()
    if not EnsureConfiguration() then
        Chat("EventAlert 4.3.6 n'est pas charge")
        return
    end
    local _, classToken = UnitClass("player")
    Chat("compatibilite " .. COA_COMPAT_VERSION .. " chargee ; classe " .. tostring(classToken or "OTHER")
        .. " ; " .. CountEntries(EA_CustomItems) .. " proc(s) personnalise(s) ; "
        .. CountEntries(EA_AltItems) .. " reaction(s) ; apprentissage "
        .. (EA_Config.CoA.AutoLearn and "ON" or "OFF"))
end

local originalSlashHandler = EventAlert_SlashHandler
local function CoASlashHandler(message)
    local normalized = string.lower(tostring(message or ""))
    if normalized == "coa" or normalized == "coa status" then
        CoAStatus()
    elseif normalized == "coa learn" then
        if EnsureConfiguration() then
            EA_Config.CoA.AutoLearn = not EA_Config.CoA.AutoLearn
            Chat("apprentissage automatique " .. (EA_Config.CoA.AutoLearn and "active" or "desactive"))
        end
    elseif normalized == "coa scan" then
        ScanSpellbook()
        CoAStatus()
    else
        originalSlashHandler(message)
    end
end

local function Initialize()
    if not EnsureConfiguration() then return false end
    ScanSpellbook()
    EventAlert_SlashHandler = CoASlashHandler
    SlashCmdList["EVENTALERT"] = CoASlashHandler
    if not initialized then
        initialized = true
        Chat("compatibilite CoA " .. COA_COMPAT_VERSION .. " chargee avec EventAlert 4.3.6")
    end
    return true
end

local eventFrame = CreateFrame("Frame", "EventAlertCoAEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("COMBAT_TEXT_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = select(1, ...)
        if addonName == "EventAlert" or addonName == "EventAlertCoA" then Initialize() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then
        Initialize()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLog(...)
    elseif event == "COMBAT_TEXT_UPDATE" and select(1, ...) == "SPELL_ACTIVE" then
        HandleSpellActive(select(2, ...))
    end
end)

Initialize()
