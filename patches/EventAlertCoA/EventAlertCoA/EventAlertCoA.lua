-- Thin Project Ascension compatibility layer for the genuine EventAlert 4.3.6 addon.
-- EventAlert remains responsible for every icon, sound, option and saved position.

local COA_COMPAT_VERSION = "1.4.2"
local BOOK = BOOKTYPE_SPELL or "spell"
local AUTO_LEARN_DEFAULT = true
local recentCasts = {}
local spellbookIds = {}
local initialized = false
local safePositionerInstalled = false
local buffManagerFrame = nil
local buffManagerRows = {}
local buffManagerPage = 1
local BUFFS_PER_PAGE = 10

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
    EA_Config.CoA.KnownBuffs = EA_Config.CoA.KnownBuffs or {}
    EA_Config.CoA.DisabledBuffs = EA_Config.CoA.DisabledBuffs or {}
    if EA_Config.CoA.Initialized == nil then
        EA_Config.AllowAltAlerts = true
        EA_Config.CoA.Initialized = true
    end
    EA_Config.CoA.Version = COA_COMPAT_VERSION
    EA_TempBuffsTable = EA_TempBuffsTable or {}
    EA_PreLoadAlts = EA_PreLoadAlts or {}
    local spellId, enabled
    for spellId, enabled in pairs(EA_CustomItems) do
        if enabled then
            spellId = tonumber(spellId) or spellId
            EA_Config.CoA.KnownBuffs[spellId] = EA_Config.CoA.KnownBuffs[spellId]
                or GetSpellInfo(spellId) or tostring(spellId)
        end
    end
    return true
end

local function IsBuffDisabled(spellId)
    if not EA_Config or not EA_Config.CoA or not EA_Config.CoA.DisabledBuffs then return false end
    spellId = tonumber(spellId) or spellId
    return EA_Config.CoA.DisabledBuffs[spellId] == true
        or EA_Config.CoA.DisabledBuffs[tostring(spellId)] == true
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

local function ActiveAlertFrames()
    local source = EA_TempBuffsTable or {}
    local active = {}
    local seen = {}
    local _, rawSpellId

    for _, rawSpellId in ipairs(source) do
        local spellId = tonumber(rawSpellId) or rawSpellId
        local frame = _G["EAFrame_" .. tostring(spellId)]
        if frame and not seen[spellId] and not IsBuffDisabled(spellId) then
            seen[spellId] = true
            table.insert(active, spellId)
        elseif frame and IsBuffDisabled(spellId) then
            frame:Hide()
        end
    end

    -- EventAlert 4.3.6 can insert the same proc more than once. Keep the
    -- original table object because the genuine addon owns this state.
    for index = #source, 1, -1 do source[index] = nil end
    for index, spellId in ipairs(active) do source[index] = spellId end
    EA_TempBuffsTable = source
    return active
end

local function AlertSpellData(spellId)
    local spellName, icon
    if spellId == 48517 then
        spellName = GetSpellInfo(spellId)
        _, _, icon = GetSpellInfo(5176)
    elseif spellId == 48518 then
        spellName = GetSpellInfo(spellId)
        _, _, icon = GetSpellInfo(2912)
    else
        spellName, _, icon = GetSpellInfo(spellId)
    end
    return spellName, icon
end

local function SafePositionFrames()
    if not EA_Config or EA_Config.ShowFrame ~= true or not EA_Main_Frame or not EA_Position then return end

    EA_Main_Frame:ClearAllPoints()
    EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)

    local active = ActiveAlertFrames()
    local _, spellId

    -- This must be a separate first pass. When proc A disappears, 4.3.6 can
    -- reverse the order of A and B while B still points at A. Anchoring A to B
    -- before clearing B creates the "is dependent on this" SetPoint cycle.
    for _, spellId in ipairs(active) do
        local frame = _G["EAFrame_" .. tostring(spellId)]
        if frame then frame:ClearAllPoints() end
    end

    local previous = EA_Main_Frame
    for _, spellId in ipairs(active) do
        local frame = _G["EAFrame_" .. tostring(spellId)]
        if frame then
            local spellName, icon = AlertSpellData(spellId)
            if previous == EA_Main_Frame then
                frame:SetPoint("CENTER", EA_Main_Frame, "CENTER", 0, 0)
            else
                frame:SetPoint("CENTER", previous, "CENTER", 100 + (EA_Position.xOffset or 0), EA_Position.yOffset or 0)
            end

            frame:SetWidth(EA_Config.IconSize or 60)
            frame:SetHeight(EA_Config.IconSize or 60)
            if icon then frame:SetBackdrop({ bgFile = icon }) end
            if frame.spellName then
                frame.spellName:SetText(EA_Config.ShowName == true and (spellName or tostring(spellId)) or "")
            end
            frame:SetScript("OnUpdate", EventAlert_OnUpdate)
            frame:Show()
            previous = frame
        end
    end
end

local function InstallSafePositioner()
    if safePositionerInstalled or type(EventAlert_PositionFrames) ~= "function" then return end
    EventAlert_PositionFrames = SafePositionFrames
    safePositionerInstalled = true
end

local function RegisterAuraProc(spellId, spellName)
    if not spellId or not EnsureConfiguration() then return false end
    spellId = tonumber(spellId) or spellId
    EA_Config.CoA.KnownBuffs[spellId] = spellName or GetSpellInfo(spellId) or tostring(spellId)
    if IsBuffDisabled(spellId) then return false end
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
    if not spellId or IsBuffDisabled(spellId) or IsActive(spellId) then return end
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
    if IsBuffDisabled(spellId) then return false end
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

local function RemoveActiveBuff(spellId)
    spellId = tonumber(spellId) or spellId
    local active = EA_TempBuffsTable or {}
    local index
    for index = #active, 1, -1 do
        if (tonumber(active[index]) or active[index]) == spellId then table.remove(active, index) end
    end
    local frame = _G["EAFrame_" .. tostring(spellId)]
    if frame then
        frame:ClearAllPoints()
        frame:Hide()
    end
    if type(EventAlert_PositionFrames) == "function" then EventAlert_PositionFrames() end
end

local function LearnedBuffEntries()
    local entries = {}
    if not EnsureConfiguration() then return entries end
    local rawSpellId, storedName
    for rawSpellId, storedName in pairs(EA_Config.CoA.KnownBuffs) do
        local spellId = tonumber(rawSpellId) or rawSpellId
        local name = GetSpellInfo(spellId) or storedName or tostring(spellId)
        table.insert(entries, { id = spellId, name = tostring(name) })
    end
    table.sort(entries, function(left, right)
        local leftName = string.lower(left.name)
        local rightName = string.lower(right.name)
        if leftName == rightName then return tostring(left.id) < tostring(right.id) end
        return leftName < rightName
    end)
    return entries
end

local RefreshBuffManager

local function SetLearnedBuffEnabled(spellId, enabled)
    if not EnsureConfiguration() then return end
    spellId = tonumber(spellId) or spellId
    local name = GetSpellInfo(spellId) or EA_Config.CoA.KnownBuffs[spellId] or tostring(spellId)
    EA_Config.CoA.KnownBuffs[spellId] = name
    EA_Config.CoA.DisabledBuffs[tostring(spellId)] = nil
    if enabled then
        EA_Config.CoA.DisabledBuffs[spellId] = nil
        EA_CustomItems[spellId] = true
        EnsureAlertFrame(spellId)
        local index
        for index = 1, 40 do
            local activeName = UnitBuff("player", index)
            if not activeName then break end
            if activeName == name then Activate(spellId); break end
        end
    else
        EA_Config.CoA.DisabledBuffs[spellId] = true
        EA_CustomItems[spellId] = nil
        EA_CustomItems[tostring(spellId)] = nil
        RemoveActiveBuff(spellId)
    end
    Chat(tostring(name) .. " [" .. tostring(spellId) .. "] " .. (enabled and "active" or "ignore"))
    if RefreshBuffManager then RefreshBuffManager() end
end

RefreshBuffManager = function()
    if not buffManagerFrame or not buffManagerFrame:IsVisible() then return end
    local entries = LearnedBuffEntries()
    local pageCount = math.max(1, math.ceil(#entries / BUFFS_PER_PAGE))
    if buffManagerPage > pageCount then buffManagerPage = pageCount end
    if buffManagerPage < 1 then buffManagerPage = 1 end

    local enabledCount = 0
    local _, entry
    for _, entry in ipairs(entries) do
        if EA_CustomItems[entry.id] and not IsBuffDisabled(entry.id) then enabledCount = enabledCount + 1 end
    end
    buffManagerFrame.summary:SetText(tostring(enabledCount) .. " actif(s) / " .. tostring(#entries) .. " memorise(s)")
    buffManagerFrame.pageText:SetText("Page " .. tostring(buffManagerPage) .. " / " .. tostring(pageCount))
    buffManagerFrame.autoLearn:SetChecked(EA_Config.CoA.AutoLearn == true)

    local rowIndex
    for rowIndex = 1, BUFFS_PER_PAGE do
        local row = buffManagerRows[rowIndex]
        entry = entries[(buffManagerPage - 1) * BUFFS_PER_PAGE + rowIndex]
        if entry then
            row.spellId = entry.id
            row.check:SetChecked(EA_CustomItems[entry.id] == true and not IsBuffDisabled(entry.id))
            row.text:SetText(entry.name .. "  |cff888888[" .. tostring(entry.id) .. "]|r")
            row:Show()
        else
            row.spellId = nil
            row:Hide()
        end
    end
    if buffManagerPage > 1 then buffManagerFrame.previous:Enable() else buffManagerFrame.previous:Disable() end
    if buffManagerPage < pageCount then buffManagerFrame.next:Enable() else buffManagerFrame.next:Disable() end
end

local function CreateBuffManager()
    if buffManagerFrame then return buffManagerFrame end
    local frame = CreateFrame("Frame", "EventAlertCoABuffManagerFrame", UIParent)
    frame:SetWidth(520)
    frame:SetHeight(410)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnShow", function() buffManagerPage = 1; RefreshBuffManager() end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("EventAlert CoA - Buffs memorises")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    frame.autoLearn = CreateFrame("CheckButton", "EventAlertCoAAutoLearnCheck", frame, "UICheckButtonTemplate")
    frame.autoLearn:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -51)
    frame.autoLearn:SetScript("OnClick", function(self)
        EA_Config.CoA.AutoLearn = self:GetChecked() and true or false
        Chat("apprentissage automatique " .. (EA_Config.CoA.AutoLearn and "active" or "desactive"))
    end)
    local autoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoText:SetPoint("LEFT", frame.autoLearn, "RIGHT", 2, 1)
    autoText:SetText("Apprendre automatiquement les nouveaux procs")

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -58)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -83)
    help:SetText("Decoche un buff pour le masquer et empecher son reapprentissage.")

    local rowIndex
    for rowIndex = 1, BUFFS_PER_PAGE do
        local row = CreateFrame("Frame", nil, frame)
        row:SetWidth(470)
        row:SetHeight(25)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -105 - ((rowIndex - 1) * 25))
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.check:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if parent.spellId then SetLearnedBuffEnabled(parent.spellId, self:GetChecked() and true or false) end
        end)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.check, "RIGHT", 3, 1)
        row.text:SetWidth(425)
        row.text:SetJustifyH("LEFT")
        buffManagerRows[rowIndex] = row
    end

    frame.previous = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.previous:SetWidth(90)
    frame.previous:SetHeight(22)
    frame.previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 21)
    frame.previous:SetText("Precedent")
    frame.previous:SetScript("OnClick", function() buffManagerPage = buffManagerPage - 1; RefreshBuffManager() end)

    frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.next:SetWidth(90)
    frame.next:SetHeight(22)
    frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 21)
    frame.next:SetText("Suivant")
    frame.next:SetScript("OnClick", function() buffManagerPage = buffManagerPage + 1; RefreshBuffManager() end)

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 27)
    buffManagerFrame = frame
    return frame
end

local function ToggleBuffManager()
    if not EnsureConfiguration() then return end
    local frame = CreateBuffManager()
    if frame:IsVisible() then frame:Hide() else frame:Show() end
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
        .. (EA_Config.CoA.AutoLearn and "ON" or "OFF")
        .. " ; /ea coa buffs pour gerer la liste")
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
    elseif normalized == "coa buffs" then
        ToggleBuffManager()
    else
        originalSlashHandler(message)
    end
end

local function Initialize()
    if not EnsureConfiguration() then return false end
    InstallSafePositioner()
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
