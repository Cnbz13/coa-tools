local addonName = ...

local BOOK = BOOKTYPE_SPELL or "spell"
local UPDATE_INTERVAL = 0.10
local MAX_ALERTS = 5
local learnedSpells, activeAlerts, cooldownState, ownedSummons = {}, {}, {}, {}
local playerClass, playerClassToken, specialization = "Unknown", "UNKNOWN", "Unknown"
local learning, debugMode, elapsed = false, false, 0

local function Chat(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffb16cffCoA Event Alert:|r " .. tostring(message)) end
end

local function Now() return GetTime and GetTime() or 0 end
local function Epoch() return time and time() or 0 end
local function Lower(value) return string.lower(tostring(value or "")) end

local function EnsureDatabase()
    CoAEventAlertDB = CoAEventAlertDB or {}
    CoAEventAlertDB.settings = CoAEventAlertDB.settings or { learning = false, debug = false }
    CoAEventAlertDB.learned = CoAEventAlertDB.learned or { spells = {}, buffs = {}, debuffs = {}, summons = {} }
    CoAEventAlertDB.characters = CoAEventAlertDB.characters or {}
    learning = CoAEventAlertDB.settings.learning == true
    debugMode = CoAEventAlertDB.settings.debug == true
end

local function CharacterKey()
    return (UnitName("player") or "Unknown") .. "-" .. ((GetRealmName and GetRealmName()) or "Ascension")
end

local function SpellIdFromBook(index, bookType)
    if not GetSpellLink then return nil end
    local link = GetSpellLink(index, bookType)
    return link and tonumber(string.match(link, "spell:(%d+)")) or nil
end

local function Remember(category, spellId, name, extra)
    if not learning or not spellId then return end
    local bucket = CoAEventAlertDB.learned[category]
    if not bucket[spellId] then
        bucket[spellId] = { name = name or "Unknown", firstSeen = Epoch(), extra = extra }
        Chat("apprentissage " .. category .. ": " .. tostring(name) .. " [" .. spellId .. "]")
    end
end

local function DetectSpecialization()
    local bestName, bestPoints = "Unknown", -1
    if GetNumTalentTabs and GetTalentTabInfo then
        local index
        for index = 1, GetNumTalentTabs() do
            local name, _, points = GetTalentTabInfo(index)
            points = tonumber(points) or 0
            if points > bestPoints then bestName, bestPoints = name or "Unknown", points end
        end
    end
    return bestName
end

local function ActiveModule()
    local modules = CoAEventAlertModules or {}
    local module = modules.NecromancerAnimation
    if not module then return nil end
    local classMatch, hintScore, value
    for _, value in ipairs(module.classNames or {}) do
        if Lower(playerClass) == Lower(value) then classMatch = true end
    end
    for _, value in ipairs(module.specializationHints or {}) do
        if string.find(Lower(specialization), Lower(value), 1, true) then hintScore = true end
    end
    if classMatch or hintScore then return module end
    for name in pairs(learnedSpells) do
        if module.spells[name] then return module end
    end
    return nil
end

local function ScanSpellbook()
    learnedSpells = {}
    local tabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    local tab
    for tab = 1, tabs do
        local _, _, offset, count = GetSpellTabInfo(tab)
        local slot
        for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local name, rank = GetSpellName(slot, BOOK)
            if name then
                local spellId = SpellIdFromBook(slot, BOOK)
                local texture = GetSpellTexture and GetSpellTexture(slot, BOOK) or nil
                learnedSpells[name] = { id = spellId, rank = rank, texture = texture, slot = slot }
                Remember("spells", spellId, name, rank)
            end
        end
    end
    playerClass, playerClassToken = UnitClass("player")
    playerClass, playerClassToken = playerClass or "Unknown", playerClassToken or "UNKNOWN"
    specialization = DetectSpecialization()
    EnsureDatabase()
    CoAEventAlertDB.characters[CharacterKey()] = {
        class = playerClass, classToken = playerClassToken, specialization = specialization,
        level = UnitLevel("player") or 0, spellCount = 0, lastScan = Epoch()
    }
    local count = 0
    for _ in pairs(learnedSpells) do count = count + 1 end
    CoAEventAlertDB.characters[CharacterKey()].spellCount = count
    if debugMode then Chat("scan: " .. count .. " sorts, " .. playerClass .. " / " .. specialization) end
    return count
end

local anchor = CreateFrame("Frame", "CoAEventAlertFrame", UIParent)
anchor:SetWidth(340)
anchor:SetHeight(72)
anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
anchor:SetClampedToScreen(true)

local visuals = {}
local function CreateVisual(index)
    local frame = CreateFrame("Frame", "CoAEventAlertIcon" .. index, anchor)
    frame:SetWidth(60); frame:SetHeight(70)
    frame:SetPoint("LEFT", anchor, "LEFT", (index - 1) * 68, 0)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetWidth(56); frame.icon:SetHeight(56); frame.icon:SetPoint("TOP", frame, "TOP", 0, 0)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetTexture("Interface/Buttons/UI-ActionButton-Border")
    frame.border:SetBlendMode("ADD"); frame.border:SetAlpha(0.75)
    frame.border:SetWidth(92); frame.border:SetHeight(92); frame.border:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame.icon)
    frame.timer = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    frame.timer:SetPoint("BOTTOM", frame.icon, "BOTTOM", 0, 3)
    frame.stacks = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    frame.stacks:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", -2, 2)
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetWidth(68); frame.label:SetPoint("TOP", frame.icon, "BOTTOM", 0, -1)
    frame:Hide(); visuals[index] = frame
end
for visualIndex = 1, MAX_ALERTS do CreateVisual(visualIndex) end

local function AddAlert(key, data)
    data.key = key
    activeAlerts[key] = data
end

local function AuraFields(unit, index, filter)
    local getter = filter == "HARMFUL" and UnitDebuff or UnitBuff
    local name, rank, texture, count, dispelType, duration, expirationTime, source, stealable, consolidate, spellId = getter(unit, index)
    return name, texture, count or 0, duration or 0, expirationTime or 0, spellId, source
end

local function ScanAuras(unit, filter)
    local alertPrefix = "aura:" .. unit .. ":"
    local alertKey
    for alertKey in pairs(activeAlerts) do
        if string.sub(alertKey, 1, string.len(alertPrefix)) == alertPrefix then activeAlerts[alertKey] = nil end
    end
    local index = 1
    while index <= 40 do
        local name, texture, count, duration, expiration, spellId, source = AuraFields(unit, index, filter)
        if not name then break end
        local category = filter == "HARMFUL" and "debuffs" or "buffs"
        Remember(category, spellId, name, unit)
        local module = ActiveModule()
        local rule = module and module.spells[name]
        if rule and (unit == "player" or source == "player") then
            AddAlert("aura:" .. unit .. ":" .. tostring(spellId or name), {
                name = name, texture = texture, count = count, duration = duration,
                expiration = expiration, priority = rule.priority or 1, kind = rule.kind
            })
        end
        index = index + 1
    end
end

local function ScanCooldowns()
    local module = ActiveModule()
    if not module then return end
    local name, learned
    for name, learned in pairs(learnedSpells) do
        local rule = module.spells[name]
        if rule and (rule.kind == "cooldown" or rule.kind == "proc") and GetSpellCooldown then
            local start, duration, enabled = GetSpellCooldown(name)
            local ready = enabled ~= 0 and (not start or start == 0 or not duration or duration <= 1.5)
            if cooldownState[name] == false and ready then
                AddAlert("ready:" .. name, { name = name, texture = learned.texture, duration = 2.5, expiration = Now() + 2.5, priority = rule.priority or 2, kind = "ready" })
            end
            cooldownState[name] = ready
        end
    end
end

local function PruneAndRender()
    local now, ordered, key, alert = Now(), {}
    for key, alert in pairs(activeAlerts) do
        if alert.expiration == 0 or alert.expiration > now then table.insert(ordered, alert) else activeAlerts[key] = nil end
    end
    table.sort(ordered, function(a, b)
        if (a.priority or 0) ~= (b.priority or 0) then return (a.priority or 0) > (b.priority or 0) end
        return (a.expiration or 0) < (b.expiration or 0)
    end)
    local index
    for index = 1, MAX_ALERTS do
        local visual, data = visuals[index], ordered[index]
        if data then
            visual.icon:SetTexture(data.texture or "Interface/Icons/INV_Misc_QuestionMark")
            visual.label:SetText(data.name or "Alerte")
            visual.stacks:SetText((data.count or 0) > 1 and tostring(data.count) or "")
            local remaining = data.expiration and data.expiration > 0 and data.expiration - now or 0
            visual.timer:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
            if data.duration and data.duration > 0 and data.expiration and data.expiration > 0 then
                CooldownFrame_SetTimer(visual.cooldown, data.expiration - data.duration, data.duration, 1)
            else CooldownFrame_SetTimer(visual.cooldown, 0, 0, 0) end
            visual:Show()
        else visual:Hide() end
    end
end

local function CleanupSummons()
    local now, guid, summon = Now(), nil, nil
    for guid, summon in pairs(ownedSummons) do
        if summon.expires and summon.expires < now then ownedSummons[guid] = nil; activeAlerts["summon:" .. guid] = nil end
    end
end

local function HandleCombatLog(...)
    local timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName = ...
    if subEvent == "SPELL_SUMMON" or subEvent == "SPELL_CREATE" then
        local mine = sourceGUID == UnitGUID("player") or (sourceFlags and bit and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE or 1) > 0)
        if mine then
            Remember("summons", spellId, destName or spellName, spellName)
            ownedSummons[destGUID or tostring(timestamp)] = { name = destName or spellName, spellId = spellId, expires = Now() + 30 }
            AddAlert("summon:" .. tostring(destGUID or timestamp), { name = destName or spellName, texture = GetSpellTexture and GetSpellTexture(spellName), duration = 30, expiration = Now() + 30, priority = 2, kind = "summon" })
        end
    elseif (subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED") and destGUID then
        ownedSummons[destGUID] = nil; activeAlerts["summon:" .. destGUID] = nil
    elseif learning and (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_CAST_SUCCESS") then
        Remember("spells", spellId, spellName, subEvent)
    end
end

local function PrintStatus()
    local spells, alerts, summons = 0, 0, 0
    for _ in pairs(learnedSpells) do spells = spells + 1 end
    for _ in pairs(activeAlerts) do alerts = alerts + 1 end
    for _ in pairs(ownedSummons) do summons = summons + 1 end
    Chat(playerClass .. " / " .. specialization .. ", niveau " .. tostring(UnitLevel("player") or 0) .. ", " .. spells .. " sorts, " .. alerts .. " alertes, " .. summons .. " invocations, apprentissage " .. (learning and "ON" or "OFF"))
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_PET" }) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        EnsureDatabase()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        ScanSpellbook(); ScanCooldowns()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then ScanAuras("player", "HELPFUL") elseif unit == "target" then ScanAuras("target", "HARMFUL") end
    elseif event == "PLAYER_TARGET_CHANGED" then ScanAuras("target", "HARMFUL")
    elseif event == "SPELL_UPDATE_COOLDOWN" then ScanCooldowns()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then HandleCombatLog(...)
    elseif event == "UNIT_PET" then ScanAuras("player", "HELPFUL") end
end)
eventFrame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0; ScanCooldowns(); CleanupSummons(); PruneAndRender()
end)

SLASH_COAEVENTALERT1 = "/cea"
SlashCmdList.COAEVENTALERT = function(message)
    EnsureDatabase()
    local command = string.lower(string.match(message or "", "^%s*(%S*)") or "")
    if command == "status" or command == "" then PrintStatus()
    elseif command == "scan" then Chat("scan terminé: " .. ScanSpellbook() .. " sorts"); ScanAuras("player", "HELPFUL"); ScanAuras("target", "HARMFUL")
    elseif command == "learn" then learning = not learning; CoAEventAlertDB.settings.learning = learning; Chat("mode apprentissage " .. (learning and "activé" or "désactivé"))
    elseif command == "debug" then debugMode = not debugMode; CoAEventAlertDB.settings.debug = debugMode; Chat("debug " .. (debugMode and "activé" or "désactivé"))
    else Chat("/cea status | scan | learn | debug") end
end
