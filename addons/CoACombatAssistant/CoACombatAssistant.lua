local addonName = ...

local UPDATE_INTERVAL = 0.20
local MEMORY_LIMIT = 250
local AOE_THRESHOLD = 3
local ENEMY_TIMEOUT = 8

local animationSingleTarget = {
    "Command: Animates", "Command: Putrid Thrall", "Putrefy",
    "Animate: Knight of Decay", "Animate: Putrid Thrall", "Animate: Lesser Zombie",
    "Animate: Zombie", "Raise Skeleton", "Lich Bolt"
}

local animationArea = {
    "March of the Dead", "Bonestorm", "Command: Animates", "Command: Skeletal Warriors",
    "Putrefy", "Animate: Zombies", "Animate: Zombie", "Animate: Lesser Zombie", "Icequake"
}

local frame = CreateFrame("Frame", "CoACombatAssistantFrame", UIParent)
frame:SetWidth(330)
frame:SetHeight(178)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
frame:SetBackdropColor(0.03, 0.04, 0.07, 0.94)
frame:SetBackdropBorderColor(0.75, 0.55, 0.25, 0.9)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -12)
title:SetText("CoA Combat Assistant")

local characterText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
characterText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -38)
characterText:SetWidth(300)
characterText:SetJustifyH("LEFT")

local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
timerText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -57)
timerText:SetText("00:00")

local modeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
modeText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -62)
modeText:SetText("Mode ST")

local recommendationText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
recommendationText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -88)
recommendationText:SetWidth(300)
recommendationText:SetJustifyH("LEFT")
recommendationText:SetText("Conseil: analyse du spellbook…")

local memoryText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
memoryText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 32)
memoryText:SetWidth(300)
memoryText:SetJustifyH("LEFT")

local stateText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stateText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 13)
stateText:SetText("Prêt — /cca status")

local initialized = false
local unlocked = false
local startedAt = nil
local lastUpdate = 0
local playerGUID = nil
local petGUID = nil
local knownSpells = {}
local spellOrder = {}
local character = { level = 0, className = "Inconnue", classToken = "UNKNOWN", spec = "Inconnue" }
local activeEnemies = {}
local currentMobs = {}
local currentMode = "ST"
local currentRecommendation = nil

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66CoA Combat Assistant:|r " .. tostring(message))
    end
end

local function Trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
end

local function Lower(value)
    return string.lower(value or "")
end

local function EnsureDatabase()
    CoACombatAssistantDB = CoACombatAssistantDB or {}
    CoACombatAssistantDB.visible = CoACombatAssistantDB.visible ~= false
    CoACombatAssistantDB.locked = CoACombatAssistantDB.locked ~= false
    CoACombatAssistantDB.history = CoACombatAssistantDB.history or {}
    CoACombatAssistantDB.mobs = CoACombatAssistantDB.mobs or {}
    CoACombatAssistantDB.spellbook = CoACombatAssistantDB.spellbook or {}
end

local function SavePosition()
    if not initialized then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    CoACombatAssistantDB.position = { point or "CENTER", relativePoint or "CENTER", x or 0, y or 0 }
end

frame:SetScript("OnDragStart", function(self)
    if not initialized or not unlocked then return end
    if InCombatLockdown and InCombatLockdown() then Chat("Déplacement interdit en combat.") return end
    self:StartMoving()
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

local function CountMemory()
    local count = 0
    local _
    for _ in pairs(CoACombatAssistantDB.mobs) do count = count + 1 end
    return count
end

local function PruneMemory()
    local count = CountMemory()
    while count > MEMORY_LIMIT do
        local oldestKey, oldestAt = nil, nil
        local key, data
        for key, data in pairs(CoACombatAssistantDB.mobs) do
            local at = data.lastSeen or 0
            if not oldestAt or at < oldestAt then oldestKey, oldestAt = key, at end
        end
        if not oldestKey then break end
        CoACombatAssistantDB.mobs[oldestKey] = nil
        count = count - 1
    end
end

local function RememberMob(guid, name, eventType)
    if not initialized or not guid or guid == playerGUID or guid == petGUID then return end
    name = name or "Créature inconnue"
    local memory = CoACombatAssistantDB.mobs[guid]
    if not memory then
        memory = { name = name, firstSeen = time(), lastSeen = time(), events = 0, encounters = 0, deaths = 0 }
        CoACombatAssistantDB.mobs[guid] = memory
    end
    memory.name = name
    memory.lastSeen = time()
    memory.events = (memory.events or 0) + 1
    if eventType == "UNIT_DIED" then memory.deaths = (memory.deaths or 0) + 1 end
    activeEnemies[guid] = GetTime()
    currentMobs[guid] = true
    PruneMemory()
end

local function IsHostile(flags)
    if flags and COMBATLOG_OBJECT_REACTION_HOSTILE and bit and bit.band then
        return bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
    end
    return true
end

local function ScanCharacter()
    local className, classToken = UnitClass("player")
    character.level = UnitLevel("player") or 0
    character.className = className or "Inconnue"
    character.classToken = classToken or "UNKNOWN"
    local bestName, bestPoints = "Inconnue", -1
    if GetNumTalentTabs and GetTalentTabInfo then
        local tab
        for tab = 1, GetNumTalentTabs() do
            local talentName, _, points = GetTalentTabInfo(tab)
            points = tonumber(points) or 0
            if points > bestPoints then bestName, bestPoints = talentName or "Inconnue", points end
        end
    end
    local animationScore = 0
    local _, spell
    for _, spell in ipairs(spellOrder) do
        local lowered = Lower(spell.name)
        if string.find(lowered, "animate:", 1, true) or string.find(lowered, "command:", 1, true) or string.find(lowered, "raise skeleton", 1, true) then
            animationScore = animationScore + 1
        end
    end
    character.spec = animationScore >= 2 and "Animation" or bestName
    characterText:SetText("Niveau " .. character.level .. "  •  " .. character.className .. "  •  " .. character.spec)
end

local function ScanSpellbook(silent)
    knownSpells = {}
    spellOrder = {}
    local book = BOOKTYPE_SPELL or "spell"
    local tab
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, number = GetSpellTabInfo(tab)
            local index
            for index = (offset or 0) + 1, (offset or 0) + (number or 0) do
                local name, rank = GetSpellName(index, book)
                if name then
                    local entry = { name = name, rank = rank or "", index = index }
                    knownSpells[Lower(name)] = entry
                    table.insert(spellOrder, entry)
                end
            end
        end
    end
    EnsureDatabase()
    local names = {}
    local _, spell
    for _, spell in ipairs(spellOrder) do table.insert(names, spell.name) end
    CoACombatAssistantDB.spellbook = { scannedAt = time(), count = #spellOrder, names = names }
    ScanCharacter()
    if not silent then Chat(#spellOrder .. " sorts scannés. Spécialisation détectée: " .. character.spec) end
end

local function LearnedSpell(name)
    return knownSpells[Lower(name)]
end

local function SpellReady(spell)
    if not spell then return false end
    if not GetSpellCooldown then return true end
    local start, duration, enabled = GetSpellCooldown(spell.name)
    if enabled == 0 then return false end
    start = tonumber(start) or 0
    duration = tonumber(duration) or 0
    return duration == 0 or start + duration <= GetTime() + 0.05
end

local function FindFallbackSpell(mode)
    local patterns
    if mode == "AOE" then
        patterns = { "march", "bonestorm", "command:", "putrefy", "animate:", "icequake" }
    else
        patterns = { "command:", "putrefy", "animate:", "raise", "bolt" }
    end
    local _, pattern, spell
    for _, pattern in ipairs(patterns) do
        for _, spell in ipairs(spellOrder) do
            if string.find(Lower(spell.name), pattern, 1, true) and SpellReady(spell) then return spell end
        end
    end
    return nil
end

local function Recommendation(mode)
    local priority = mode == "AOE" and animationArea or animationSingleTarget
    local _, name, spell
    for _, name in ipairs(priority) do
        spell = LearnedSpell(name)
        if SpellReady(spell) then return spell end
    end
    return FindFallbackSpell(mode)
end

local function RefreshEnemyMode()
    local now = GetTime()
    local count = 0
    local guid, seenAt
    for guid, seenAt in pairs(activeEnemies) do
        if now - seenAt > ENEMY_TIMEOUT then activeEnemies[guid] = nil else count = count + 1 end
    end
    currentMode = count >= AOE_THRESHOLD and "AOE" or "ST"
    currentRecommendation = Recommendation(currentMode)
    modeText:SetText("Mode " .. currentMode .. "  •  " .. count .. " cible" .. (count > 1 and "s" or ""))
    if currentRecommendation then
        recommendationText:SetText("Conseil: " .. currentRecommendation.name .. (currentRecommendation.rank ~= "" and " (" .. currentRecommendation.rank .. ")" or ""))
    else
        recommendationText:SetText("Conseil: aucun sort compatible prêt")
    end
end

local function StartCombat()
    if startedAt then return end
    startedAt = GetTime()
    activeEnemies = {}
    currentMobs = {}
    stateText:SetText("Combat en cours — recommandations uniquement")
end

local function EndCombat()
    if not startedAt then return end
    local duration = math.floor(GetTime() - startedAt)
    local mobCount = 0
    local guid
    for guid in pairs(currentMobs) do
        mobCount = mobCount + 1
        local memory = CoACombatAssistantDB.mobs[guid]
        if memory then
            memory.encounters = (memory.encounters or 0) + 1
            memory.combatTime = (memory.combatTime or 0) + duration
        end
    end
    table.insert(CoACombatAssistantDB.history, 1, { duration = duration, mobs = mobCount, mode = currentMode, at = time() })
    while #CoACombatAssistantDB.history > 30 do table.remove(CoACombatAssistantDB.history) end
    startedAt = nil
    activeEnemies = {}
    currentMobs = {}
    timerText:SetText("00:00")
    stateText:SetText("Combat terminé • " .. mobCount .. " créature(s) mémorisée(s)")
end

local function RefreshDisplay()
    if startedAt then
        local elapsed = math.floor(GetTime() - startedAt)
        timerText:SetText(string.format("%02d:%02d", math.floor(elapsed / 60), math.mod(elapsed, 60)))
    end
    playerGUID = UnitGUID("player") or playerGUID
    petGUID = UnitGUID("pet")
    RefreshEnemyMode()
    memoryText:SetText("Mémoire: " .. CountMemory() .. " créature(s)  •  Spellbook: " .. #spellOrder .. " sorts")
end

frame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < UPDATE_INTERVAL then return end
    lastUpdate = 0
    RefreshDisplay()
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        EnsureDatabase()
        initialized = true
        playerGUID = UnitGUID("player")
        if CoACombatAssistantDB.position then
            self:ClearAllPoints()
            self:SetPoint(CoACombatAssistantDB.position[1], UIParent, CoACombatAssistantDB.position[2], CoACombatAssistantDB.position[3], CoACombatAssistantDB.position[4])
        end
        if CoACombatAssistantDB.visible then self:Show() else self:Hide() end
    elseif not initialized then
        return
    elseif event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" then
        ScanSpellbook(true)
    elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" then
        ScanCharacter()
    elseif event == "PLAYER_REGEN_DISABLED" then
        StartCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        EndCombat()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
        if not subevent then return end
        local playerSource = sourceGUID and (sourceGUID == playerGUID or sourceGUID == petGUID)
        local playerDestination = destGUID and (destGUID == playerGUID or destGUID == petGUID)
        local relevant = string.find(subevent, "_DAMAGE", 1, true) or string.find(subevent, "_MISSED", 1, true) or string.find(subevent, "_AURA_", 1, true)
        if relevant and playerSource and destGUID and IsHostile(destFlags) then
            RememberMob(destGUID, destName, subevent)
        elseif relevant and playerDestination and sourceGUID and IsHostile(sourceFlags) then
            RememberMob(sourceGUID, sourceName, subevent)
        elseif subevent == "UNIT_DIED" and destGUID and currentMobs[destGUID] then
            RememberMob(destGUID, destName, subevent)
        end
    end
end)

local function PrintStatus()
    RefreshDisplay()
    Chat("Niveau " .. character.level .. ", " .. character.className .. ", spé " .. character.spec)
    Chat(#spellOrder .. " sorts connus, mode " .. currentMode .. ", conseil " .. (currentRecommendation and currentRecommendation.name or "aucun"))
end

local function PrintMemory()
    local entries = {}
    local guid, data
    for guid, data in pairs(CoACombatAssistantDB.mobs) do
        table.insert(entries, { guid = guid, name = data.name or "Inconnue", encounters = data.encounters or 0, lastSeen = data.lastSeen or 0 })
    end
    table.sort(entries, function(a, b) return a.lastSeen > b.lastSeen end)
    Chat(#entries .. " créature(s) mémorisée(s).")
    local index
    for index = 1, math.min(8, #entries) do
        Chat(index .. ". " .. entries[index].name .. " — " .. entries[index].encounters .. " combat(s)")
    end
end

local function SetUnlocked(value)
    unlocked = value and true or false
    CoACombatAssistantDB.locked = not unlocked
    if unlocked then
        frame:Show()
        CoACombatAssistantDB.visible = true
        stateText:SetText("Déverrouillé — glissez la fenêtre puis /cca lock")
        Chat("Fenêtre déverrouillée.")
    else
        SavePosition()
        stateText:SetText("Verrouillé — recommandations uniquement")
        Chat("Fenêtre verrouillée et position enregistrée.")
    end
end

local function SlashHandler(message)
    EnsureDatabase()
    local command, arguments = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = Lower(command)
    if command == "status" then
        PrintStatus()
    elseif command == "scan" then
        ScanSpellbook(false)
    elseif command == "unlock" then
        SetUnlocked(true)
    elseif command == "lock" then
        SetUnlocked(false)
    elseif command == "memory" then
        if Lower(Trim(arguments)) == "clear" then
            CoACombatAssistantDB.mobs = {}
            Chat("Mémoire des créatures effacée.")
        else
            PrintMemory()
        end
    elseif command == "reset" then
        CoACombatAssistantDB.position = nil
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
        Chat("Position réinitialisée.")
    elseif command == "show" then
        frame:Show()
        CoACombatAssistantDB.visible = true
    elseif command == "hide" then
        frame:Hide()
        CoACombatAssistantDB.visible = false
    elseif command == "" then
        if frame:IsVisible() then
            frame:Hide()
            CoACombatAssistantDB.visible = false
        else
            frame:Show()
            CoACombatAssistantDB.visible = true
        end
    else
        Chat("/cca status | scan | unlock | lock | memory [clear] | show | hide | reset")
    end
end

SLASH_COACOMBATASSISTANT1 = "/cca"
SLASH_COACOMBATASSISTANT2 = "/coacombat"
SlashCmdList.COACOMBATASSISTANT = SlashHandler
