-- CoA compatibility layer for the genuine EventAlert 4.3.6 addon.
-- This file deliberately reuses EventAlert's frames, options, sounds and SavedVariables.

local COA_COMPAT_VERSION = "1.2.0"
local BOOK = BOOKTYPE_SPELL or "spell"
local AUTO_LEARN_DEFAULT = true
local recentCasts = {}
local spellbookIds = {}
local playerClassToken = "OTHER"

local function Now()
    return GetTime and GetTime() or 0
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00EventAlert CoA:|r " .. tostring(message))
    end
end

local function CurrentClassToken()
    local _, token = UnitClass("player")
    return token or EA_CLASS_OTHER or "OTHER"
end

local function EnsureConfiguration()
    EA_Config = EA_Config or {}
    EA_Config.CoA = EA_Config.CoA or {}
    if EA_Config.CoA.AutoLearn == nil then EA_Config.CoA.AutoLearn = AUTO_LEARN_DEFAULT end
    if EA_Config.CoA.Initialized == nil then
        EA_Config.AllowAltAlerts = true
        EA_Config.CoA.Initialized = true
    end
    EA_Config.CoA.Version = COA_COMPAT_VERSION
end

local function EnsureClassTables()
    playerClassToken = CurrentClassToken()
    EA_Items = EA_Items or {}
    EA_AltItems = EA_AltItems or {}
    EA_CustomItems = EA_CustomItems or {}
    if type(EA_Items[playerClassToken]) ~= "table" then EA_Items[playerClassToken] = {} end
    if type(EA_AltItems[playerClassToken]) ~= "table" then EA_AltItems[playerClassToken] = {} end
    if type(EA_CustomItems[playerClassToken]) ~= "table" then EA_CustomItems[playerClassToken] = {} end
    if EA_CLASS_OTHER and type(EA_Items[EA_CLASS_OTHER]) ~= "table" then EA_Items[EA_CLASS_OTHER] = {} end
    return playerClassToken
end

local function MigrateFlatTable(source, destination)
    -- A community Ascension port stored IDs at the root. Preserve those user choices
    -- while returning to the genuine EventAlert 4.3.6 class-based data model.
    local spellId, enabled
    for spellId, enabled in pairs(source) do
        if type(spellId) == "number" then
            if destination[spellId] == nil then destination[spellId] = enabled end
            source[spellId] = nil
        end
    end
end

local originalLoadSpellArray = EventAlert_LoadSpellArray
function EventAlert_LoadSpellArray()
    originalLoadSpellArray()
    EnsureConfiguration()
    local token = EnsureClassTables()
    MigrateFlatTable(EA_Items, EA_Items[token])
    MigrateFlatTable(EA_AltItems, EA_AltItems[token])
    MigrateFlatTable(EA_CustomItems, EA_CustomItems[token])
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
    frame.spellTimer:SetPoint("TOP", 0, 15)
    frame:SetScript("OnEvent", EventAlert_OnEvent)
    return frame
end

local function RegisterAuraProc(spellId, spellName)
    if not spellId then return false end
    local token = EnsureClassTables()
    local learned = EA_CustomItems[token][spellId] == nil
    EA_CustomItems[token][spellId] = true
    EnsureAlertFrame(spellId)
    if learned then Chat("proc appris : " .. tostring(spellName or GetSpellInfo(spellId) or spellId) .. " [" .. spellId .. "]") end
    return learned
end

local function RegisterActiveSpell(spellId, spellName)
    if not spellId then return false end
    local token = EnsureClassTables()
    local learned = EA_AltItems[token][spellId] == nil
    EA_AltItems[token][spellId] = true
    EA_PreLoadAlts = EA_PreLoadAlts or {}
    if spellName then EA_PreLoadAlts[spellName] = tostring(spellId) end
    EnsureAlertFrame(spellId)
    if learned then Chat("reaction apprise : " .. tostring(spellName or GetSpellInfo(spellId) or spellId) .. " [" .. spellId .. "]") end
    return learned
end

local function Activate(spellId)
    if not spellId or IsActive(spellId) or not _G["EAFrame_" .. spellId] then return end
    table.insert(EA_TempBuffsTable, spellId)
    EventAlert_PositionFrames()
    EventAlert_DoAlert()
end

local function WasDirectlyCast(spellName)
    local castAt = spellName and recentCasts[spellName]
    return castAt and Now() - castAt < 2.5
end

local function IsTracked(spellId)
    local token = EnsureClassTables()
    return EA_Items[token][spellId]
        or (EA_CLASS_OTHER and EA_Items[EA_CLASS_OTHER][spellId])
        or EA_CustomItems[token][spellId]
end

local function IsOwnedSource(sourceGUID, sourceFlags)
    if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then return true end
    if sourceFlags and bit and bit.band and COMBATLOG_OBJECT_AFFILIATION_MINE then
        return bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
    end
    -- Some CoA triggered auras omit their source GUID on the 3.3.5 combat log.
    return sourceGUID == nil and UnitAffectingCombat and UnitAffectingCombat("player")
end

local function HandleCombatLog(...)
    local subEvent = select(2, ...)
    local sourceGUID = select(3, ...)
    local destGUID = select(6, ...)
    local spellId = tonumber(select(9, ...))
    local spellName = select(10, ...)
    local playerGUID = UnitGUID("player")

    if subEvent == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID and spellName then
        recentCasts[spellName] = Now()
        return
    end

    local applied = subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_APPLIED_DOSE"
    local refreshed = subEvent == "SPELL_AURA_REFRESH"
    if (applied or refreshed) and destGUID == playerGUID and spellId then
        local tracked = IsTracked(spellId)
        if not tracked and EA_Config.CoA.AutoLearn and IsOwnedSource(sourceGUID, select(5, ...)) and not WasDirectlyCast(spellName) then
            RegisterAuraProc(spellId, spellName)
            tracked = true
        end
        -- The upstream 3.3.5 handler already displays APPLIED and APPLIED_DOSE.
        -- REFRESH is a CoA event used by several stacking procs, so refresh it here.
        if refreshed and tracked then Activate(spellId) end
    end
end

local function HandleSpellActive(spellName)
    if not spellName then return end
    local spellId = spellbookIds[spellName]
    if not spellId then ScanSpellbook(); spellId = spellbookIds[spellName] end
    if spellId then RegisterActiveSpell(spellId, spellName) end
end

local function CountEntries(values)
    local count = 0
    for _, enabled in pairs(values or {}) do if enabled then count = count + 1 end end
    return count
end

local function CoAStatus()
    local token = EnsureClassTables()
    Chat("compatibilite " .. COA_COMPAT_VERSION .. " ; classe " .. token
        .. " ; " .. CountEntries(EA_CustomItems[token]) .. " proc(s) appris ; "
        .. CountEntries(EA_AltItems[token]) .. " reaction(s) ; apprentissage "
        .. (EA_Config.CoA.AutoLearn and "ON" or "OFF"))
end

local originalSlashHandler = EventAlert_SlashHandler
function EventAlert_SlashHandler(message)
    local normalized = string.lower(tostring(message or ""))
    if normalized == "coa" or normalized == "coa status" then
        CoAStatus()
    elseif normalized == "coa learn" then
        EA_Config.CoA.AutoLearn = not EA_Config.CoA.AutoLearn
        Chat("apprentissage automatique " .. (EA_Config.CoA.AutoLearn and "active" or "desactive"))
    elseif normalized == "coa scan" then
        ScanSpellbook()
        CoAStatus()
    else
        originalSlashHandler(message)
    end
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
        if select(1, ...) == "EventAlert" then EnsureConfiguration() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then
        EnsureConfiguration()
        EnsureClassTables()
        ScanSpellbook()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLog(...)
    elseif event == "COMBAT_TEXT_UPDATE" and select(1, ...) == "SPELL_ACTIVE" then
        HandleSpellActive(select(2, ...))
    end
end)
