local addonName = ...

local UPDATE_INTERVAL = 0.08
local MEMORY_LIMIT = 250
local ENEMY_TIMEOUT = 8
local SUMMON_TIMEOUT = 300
local DEFAULT_AOE_THRESHOLD = 3
local DEFAULT_MAX_ARMY_SIZE = 4
local GLOBAL_RECENT_CAST_LOCK = 1.65
local ASSUMED_SELF_BUFF_SECONDS = 90
local ASSUMED_TARGET_DEBUFF_SECONDS = 12
local TARGET_EXPERIENCE_MAX_AGE = 30 * 24 * 60 * 60

local function Lower(value)
    return string.lower(value or "")
end

local function Trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
end

local function SpellKey(value)
    local cleaned = Trim(value)
    cleaned = string.gsub(cleaned, "%s*%([Rr]ank%s+[%dIVXivx]+%)%s*$", "")
    return Lower(cleaned)
end

local function Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function Join(values, separator)
    return table.concat(values or {}, separator or ", ")
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66CoA Combat Assistant:|r " .. tostring(message))
    end
end

local frame = CreateFrame("Frame", "CoACombatAssistantFrame", UIParent)
frame:SetWidth(64)
frame:SetHeight(64)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
frame:SetMovable(true)
frame:EnableMouse(false)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)

local function CreateSpellVisual(parent, size, point, relativeTo, relativePoint, x, y)
    local visual = CreateFrame("Frame", nil, parent)
    visual:SetWidth(size)
    visual:SetHeight(size)
    visual:SetPoint(point, relativeTo, relativePoint, x, y)

    visual.icon = visual:CreateTexture(nil, "ARTWORK")
    visual.icon:SetAllPoints(visual)
    visual.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    visual.cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
    visual.cooldown:SetAllPoints(visual)

    visual.glow = visual:CreateTexture(nil, "OVERLAY")
    visual.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    visual.glow:SetBlendMode("ADD")
    visual.glow:SetPoint("CENTER", visual, "CENTER", 0, 0)
    visual.glow:SetWidth(size * 1.75)
    visual.glow:SetHeight(size * 1.75)
    visual.glow:SetVertexColor(0.30, 1.00, 0.30, 0.90)
    visual.glow:Hide()

    visual.key = visual:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    visual.key:SetPoint("BOTTOMRIGHT", visual, "BOTTOMRIGHT", -2, 2)
    visual.key:SetText("")

    return visual
end

local mainVisual = CreateSpellVisual(frame, 56, "CENTER", frame, "CENTER", 0, 0)

-- Le moteur conserve ces informations pour /cca status et /cca debug, mais
-- l'interface en jeu n'affiche volontairement que l'icône recommandée.
local hiddenText = { SetText = function() end }
local characterText = hiddenText
local timerText = hiddenText
local modeText = hiddenText
local recommendationText = hiddenText
local recommendationReasonText = hiddenText
local memoryText = hiddenText
local stateText = hiddenText

local engineFrame = CreateFrame("Frame")
frame:Hide()

local initialized = false
local unlocked = false
local startedAt = nil
local lastUpdate = 0
local playerGUID = nil
local petGUID = nil
local knownSpells = {}
local spellOrder = {}
local actionBindings = {}
local activeEnemies = {}
local currentMobs = {}
local ownedSummons = {}
local lastCasts = {}
local assumedSelfBuffs = {}
local confirmedSelfBuffs = {}
local assumedTargetDebuffs = {}
local confirmedTargetDebuffs = {}
local lastPlayerCastName = nil
local lastPlayerCastAt = nil
local currentMode = "ST"
local currentEnemyCount = 0
local currentRecommendation = nil
local currentQueue = {}
local lastDecision = { candidates = {}, rejected = {} }
local combatDamageEvents = 0
local lastCombatInteraction = nil
local EndCombat
local character = { level = 0, className = "Inconnue", classToken = "UNKNOWN", spec = "Inconnue" }

-- Rotation Animation volontairement offensive et construite uniquement avec les
-- sorts réellement observés dans le spellbook. Les buffs, soins et invocations
-- ne sont jamais affichés dans l'icône de combat.
-- Sources de logique : changelog CoA (Crypt Swarm = filler Animation) et retours
-- récents de joueurs (Blight à l'ouverture, Crypt Swarm pour générer, Command
-- pour dépenser). Aucun motif générique "Command:" ou "Animate:" n'est utilisé.
local animationPriority = {
    -- AOE : uniquement quand le compteur réel atteint le seuil configuré.
    { name = "March of the Dead", score = 146, mode = "AOE", minEnemies = 5, requiresTarget = true, requiresCombat = true, directDamage = true, reason = "attaque AOE prioritaire sur cinq ennemis actifs ou plus" },
    { name = "Grave March", score = 144, mode = "AOE", minEnemies = 3, requiresTarget = true, requiresSummon = 2, requiresCombat = true, minRunic = 20, directDamage = true, reason = "commande AOE avec invocations et ressource disponible" },
    { name = "Corpse Explosion", score = 140, mode = "AOE", minEnemies = 3, requiresTarget = true, maxTargetHealth = 45, phase = "established", directDamage = true, reason = "explosion de finition dans un groupe" },

    -- ST : Blight seulement en ouverture sur une cible durable, puis la boucle
    -- générateur/dépense documentée pour Animation.
    { name = "Blight", score = 138, requiresTarget = true, targetDebuffMissing = "Blight", minTargetHealth = 70, openingOnly = true, longSetup = true, directDamage = true, reason = "ouvrir avec Blight sur une cible encore durable" },
    { name = "Command: Undead", score = 134, requiresTarget = true, requiresSummon = 1, minRunic = 20, directDamage = true, reason = "dépenser la puissance runique avec les invocations" },
    { name = "Crypt Swarm", score = 130, requiresTarget = true, directDamage = true, channel = true, reason = "filler Animation et génération de puissance runique" },

    -- Secours uniquement si ces sorts sont réellement appris et si les actions
    -- principales sont temporairement indisponibles.
    { name = "Lichfrost", score = 104, requiresTarget = true, directDamage = true, fallbackOnly = true, reason = "dégâts de secours appris" },
    { name = "Razorice", score = 102, requiresTarget = true, directDamage = true, fallbackOnly = true, reason = "dégâts de secours appris" }
}

local trackedSelfBuffs = {
    [SpellKey("Bone Ward")] = true,
    [SpellKey("Foul Mandate")] = true,
    [SpellKey("Unholy Frenzy")] = true
}

local trackedTargetDebuffs = {
    [SpellKey("Blight")] = true,
    [SpellKey("Harvest Plague")] = true
}

local function EnsureDatabase()
    CoACombatAssistantDB = CoACombatAssistantDB or {}
    CoACombatAssistantDB.visible = CoACombatAssistantDB.visible ~= false
    CoACombatAssistantDB.locked = CoACombatAssistantDB.locked ~= false
    CoACombatAssistantDB.history = CoACombatAssistantDB.history or {}
    CoACombatAssistantDB.mobs = CoACombatAssistantDB.mobs or {}
    CoACombatAssistantDB.spellbook = CoACombatAssistantDB.spellbook or {}
    CoACombatAssistantDB.settings = CoACombatAssistantDB.settings or {}
    CoACombatAssistantDB.settings.aoeThreshold = tonumber(CoACombatAssistantDB.settings.aoeThreshold) or DEFAULT_AOE_THRESHOLD
    CoACombatAssistantDB.settings.maxArmySize = tonumber(CoACombatAssistantDB.settings.maxArmySize) or DEFAULT_MAX_ARMY_SIZE
    CoACombatAssistantDB.version = "1.4.0"

    if not CoACombatAssistantDB.position and CoACombatAssistantDB.ui then
        local old = CoACombatAssistantDB.ui
        CoACombatAssistantDB.position = {
            old.point or old[1] or "CENTER",
            old.relativePoint or old[2] or "CENTER",
            old.x or old[3] or 0,
            old.y or old[4] or 180
        }
    end
end

local function SavePosition()
    if not initialized then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    CoACombatAssistantDB.position = { point or "CENTER", relativePoint or "CENTER", x or 0, y or 0 }
end

frame:SetScript("OnDragStart", function(self)
    if not initialized or not unlocked then return end
    if InCombatLockdown and InCombatLockdown() then
        Chat("Déplacement interdit en combat.")
        return
    end
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

local function CountOwnedSummons()
    local now = GetTime()
    local count = 0
    local guid, data
    for guid, data in pairs(ownedSummons) do
        if data.dead or now - (data.lastSeen or data.createdAt or now) > SUMMON_TIMEOUT then
            ownedSummons[guid] = nil
        else
            count = count + 1
        end
    end
    return count
end

local function NormalizedSummonName(value)
    return string.gsub(Lower(value), "[^%w]", "")
end

local function CountMatchingSummons(rule)
    if not rule or not rule.summonNames then return CountOwnedSummons() end
    CountOwnedSummons()
    local count = 0
    local guid, data, index, wanted
    for guid, data in pairs(ownedSummons) do
        local unitName = NormalizedSummonName(data.name)
        local spellName = NormalizedSummonName(data.spellName)
        for index, wanted in ipairs(rule.summonNames) do
            local match = NormalizedSummonName(wanted)
            if match ~= "" and (string.find(unitName, match, 1, true) or string.find(spellName, match, 1, true)) then
                count = count + 1
                break
            end
        end
    end
    return count
end

local function CurrentZone()
    local zone = GetRealZoneText and GetRealZoneText() or nil
    if not zone or zone == "" then zone = GetZoneText and GetZoneText() or nil end
    return zone or "Zone inconnue"
end

local function PruneMemory()
    local count = CountMemory()
    while count > MEMORY_LIMIT do
        local oldestKey, oldestAt = nil, nil
        local key, data
        for key, data in pairs(CoACombatAssistantDB.mobs) do
            if not currentMobs[key] then
                local at = data.lastSeen or 0
                if not oldestAt or at < oldestAt then oldestKey, oldestAt = key, at end
            end
        end
        if not oldestKey then break end
        CoACombatAssistantDB.mobs[oldestKey] = nil
        count = count - 1
    end
end

local function HasFlag(flags, mask)
    return flags and mask and bit and bit.band and bit.band(flags, mask) ~= 0
end

local function IsHostile(flags)
    if flags and COMBATLOG_OBJECT_REACTION_HOSTILE then
        return HasFlag(flags, COMBATLOG_OBJECT_REACTION_HOSTILE)
    end
    return true
end

local function HasMineFlag(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_AFFILIATION_MINE)
end

local function RegisterOwnedSummon(guid, name, flags, spellId, spellName)
    if not guid or guid == playerGUID then return end
    local now = GetTime()
    local summon = ownedSummons[guid] or { guid = guid, createdAt = now }
    summon.name = name or summon.name or "Invocation"
    summon.flags = flags or summon.flags
    summon.spellId = spellId or summon.spellId
    summon.spellName = spellName or summon.spellName
    summon.lastSeen = now
    summon.dead = false
    ownedSummons[guid] = summon
end

local function RefreshPetGUID()
    petGUID = UnitGUID("pet")
    if petGUID then
        RegisterOwnedSummon(petGUID, UnitName("pet"), COMBATLOG_OBJECT_AFFILIATION_MINE, nil, "Pet actif")
    end
end

local function IsOwnedActor(guid, flags, name)
    if not guid then return false end
    if guid == playerGUID or guid == petGUID then return true end
    if ownedSummons[guid] then
        ownedSummons[guid].lastSeen = GetTime()
        return true
    end
    if HasMineFlag(flags) then
        RegisterOwnedSummon(guid, name, flags, nil, "Affiliation joueur")
        return true
    end
    return false
end

local function UpdateTargetMetadata(memory, guid)
    if not memory or not guid or not UnitGUID or UnitGUID("target") ~= guid then return end
    memory.level = UnitLevel and UnitLevel("target") or memory.level
    memory.classification = UnitClassification and UnitClassification("target") or memory.classification
    memory.creatureType = UnitCreatureType and UnitCreatureType("target") or memory.creatureType
    memory.maxHealth = UnitHealthMax and UnitHealthMax("target") or memory.maxHealth
end

local function RememberMob(guid, name, eventType, damageDirection, amount)
    if not initialized or not guid or guid == playerGUID or guid == petGUID or ownedSummons[guid] then return nil end
    local nowEpoch = time()
    local now = GetTime()
    local memory = CoACombatAssistantDB.mobs[guid]
    if not memory then
        memory = {
            guid = guid,
            name = name or "Créature inconnue",
            firstSeen = nowEpoch,
            lastSeen = nowEpoch,
            lastEncounter = nowEpoch,
            encounters = 0,
            deaths = 0,
            combatTime = 0,
            damageTaken = 0,
            damageDone = 0,
            spellStats = {},
            events = 0,
            zone = CurrentZone()
        }
        CoACombatAssistantDB.mobs[guid] = memory
    end

    memory.guid = guid
    memory.name = name or memory.name or "Créature inconnue"
    memory.lastSeen = nowEpoch
    memory.lastEncounter = nowEpoch
    memory.zone = CurrentZone()
    memory.spellStats = memory.spellStats or {}
    UpdateTargetMetadata(memory, guid)
    if eventType and eventType ~= "TARGET_FALLBACK" then
        memory.events = (memory.events or 0) + 1
    end
    amount = tonumber(amount) or 0
    if damageDirection == "TAKEN" then
        memory.damageTaken = (memory.damageTaken or 0) + amount
    elseif damageDirection == "DONE" then
        memory.damageDone = (memory.damageDone or 0) + amount
    end

    activeEnemies[guid] = now
    if not currentMobs[guid] then
        currentMobs[guid] = { firstAt = now, lastAt = now }
    else
        currentMobs[guid].lastAt = now
    end
    PruneMemory()
    return memory
end

local function RecordSpellOutcome(memory, spellName, subevent, amount, missType)
    if not memory or not spellName or spellName == "" then return end
    memory.spellStats = memory.spellStats or {}
    local key = Lower(spellName)
    local stats = memory.spellStats[key]
    if not stats then
        stats = { name = spellName, hits = 0, damage = 0, misses = 0, immune = 0, resists = 0 }
        memory.spellStats[key] = stats
    end
    stats.name = spellName
    stats.lastSeen = time()
    if string.find(subevent or "", "_DAMAGE", 1, true) then
        stats.hits = (stats.hits or 0) + 1
        stats.damage = (stats.damage or 0) + (tonumber(amount) or 0)
    elseif string.find(subevent or "", "_MISSED", 1, true) then
        stats.misses = (stats.misses or 0) + 1
        if missType == "IMMUNE" then stats.immune = (stats.immune or 0) + 1 end
        if missType == "RESIST" then stats.resists = (stats.resists or 0) + 1 end
    end
end

local function MarkMobDeath(guid, name)
    if not guid or not currentMobs[guid] then return end
    local memory = RememberMob(guid, name, "UNIT_DIED")
    if memory then
        local nowEpoch = time()
        if not memory.lastDeathAt or nowEpoch - memory.lastDeathAt > 2 then
            memory.deaths = (memory.deaths or 0) + 1
            memory.lastDeathAt = nowEpoch
        end
    end
    activeEnemies[guid] = nil
end

local function CaptureHostileTarget()
    if not startedAt or not UnitExists("target") or UnitIsDead("target") then return end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return end
    local guid = UnitGUID("target")
    if guid then RememberMob(guid, UnitName("target"), "TARGET_FALLBACK") end
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
    local markers = {
        [Lower("Animate: Skeletal Archer")] = true,
        [Lower("Raise: Crypt Fiend")] = true,
        [Lower("Raise: Greater Skeletal Warrior")] = true,
        [Lower("March of the Dead")] = true,
        [Lower("Command: Undead")] = true
    }
    local _, spell
    for _, spell in ipairs(spellOrder) do
        if markers[Lower(spell.name)] then animationScore = animationScore + 1 end
    end
    character.spec = animationScore >= 2 and "Animation" or bestName
    characterText:SetText("Niveau " .. character.level .. "  •  " .. character.className .. "  •  " .. character.spec)
end

local function BindingCommandForSlot(slot)
    if slot >= 1 and slot <= 12 then return "ACTIONBUTTON" .. slot end
    if slot >= 61 and slot <= 72 then return "MULTIACTIONBAR1BUTTON" .. (slot - 60) end
    if slot >= 49 and slot <= 60 then return "MULTIACTIONBAR2BUTTON" .. (slot - 48) end
    if slot >= 25 and slot <= 36 then return "MULTIACTIONBAR3BUTTON" .. (slot - 24) end
    if slot >= 37 and slot <= 48 then return "MULTIACTIONBAR4BUTTON" .. (slot - 36) end
    return nil
end

local function ScanActionBindings()
    actionBindings = {}
    if not GetActionInfo or not GetBindingKey then return end
    local slot
    for slot = 1, 120 do
        local actionType, actionId = GetActionInfo(slot)
        if actionType == "spell" and actionId and GetSpellInfo then
            local spellName = GetSpellInfo(actionId)
            local command = BindingCommandForSlot(slot)
            if spellName and command then
                local key = GetBindingKey(command)
                if key then
                    local shown = GetBindingText and GetBindingText(key, "KEY_", 1) or key
                    actionBindings[Lower(spellName)] = shown ~= "" and shown or key
                end
            end
        end
    end
    local key, spell
    for key, spell in pairs(knownSpells) do spell.key = actionBindings[key] end
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
                    local icon
                    if GetSpellInfo then
                        local _, _, spellIcon = GetSpellInfo(index, book)
                        icon = spellIcon
                    end
                    if not icon and GetSpellTexture then icon = GetSpellTexture(index, book) end
                    local entry = {
                        name = name,
                        rank = rank or "",
                        index = index,
                        texture = icon,
                        passive = IsPassiveSpell and IsPassiveSpell(index, book) and true or false
                    }
                    knownSpells[Lower(name)] = entry
                    table.insert(spellOrder, entry)
                end
            end
        end
    end

    ScanActionBindings()
    EnsureDatabase()
    local names = {}
    local _, spell
    for _, spell in ipairs(spellOrder) do table.insert(names, spell.name) end
    CoACombatAssistantDB.spellbook = { scannedAt = time(), count = #spellOrder, names = names }
    ScanCharacter()
    if not silent then Chat(#spellOrder .. " sorts scannés. Spécialisation détectée : " .. character.spec) end
end

local function LearnedSpell(name)
    return knownSpells[Lower(name)]
end

local Percent
local TargetIsValid

local function HasAura(unit, auraName, harmful)
    if not auraName then return false end
    local wanted = SpellKey(auraName)
    local index
    for index = 1, 40 do
        local name
        if harmful then name = UnitDebuff(unit, index) else name = UnitBuff(unit, index) end
        if not name then break end
        if SpellKey(name) == wanted then return true end
    end
    return false
end

local function HasSelfBuff(auraName)
    if HasAura("player", auraName, false) then return true end
    local key = SpellKey(auraName)
    if confirmedSelfBuffs[key] then return true end
    local assumedUntil = assumedSelfBuffs[key]
    if assumedUntil and assumedUntil > GetTime() then return true end
    assumedSelfBuffs[key] = nil
    return false
end

local function TargetDebuffTable(container, guid, create)
    if not guid then return nil end
    if create and not container[guid] then container[guid] = {} end
    return container[guid]
end

local function HasTargetDebuff(auraName)
    if not TargetIsValid or not TargetIsValid() then return false end
    if HasAura("target", auraName, true) then return true end
    local guid = UnitGUID("target")
    local key = SpellKey(auraName)
    local confirmed = TargetDebuffTable(confirmedTargetDebuffs, guid, false)
    if confirmed and confirmed[key] then return true end
    local assumed = TargetDebuffTable(assumedTargetDebuffs, guid, false)
    local assumedUntil = assumed and assumed[key]
    if assumedUntil and assumedUntil > GetTime() then return true end
    if assumed then assumed[key] = nil end
    return false
end

local function RecordPlayerCast(spellName)
    if not spellName or spellName == "" then return end
    local now = GetTime()
    local key = SpellKey(spellName)
    lastCasts[key] = now
    lastPlayerCastName = spellName
    lastPlayerCastAt = now

    -- Ascension peut confirmer le lancement avant que UnitBuff/UnitDebuff expose
    -- l'aura. Cette courte mémoire empêche l'icône de rester bloquée sur le sort.
    if trackedSelfBuffs[key] then
        assumedSelfBuffs[key] = now + ASSUMED_SELF_BUFF_SECONDS
    end
    if trackedTargetDebuffs[key] and TargetIsValid() then
        local guid = UnitGUID("target")
        local assumed = TargetDebuffTable(assumedTargetDebuffs, guid, true)
        assumed[key] = now + ASSUMED_TARGET_DEBUFF_SECONDS
    end
end

local function CurrentRunicPower()
    if not UnitPower or not UnitPowerMax then return nil, nil, nil end
    local powerTypes = { 10, 6 }
    local _, powerType
    for _, powerType in ipairs(powerTypes) do
        local maximum = tonumber(UnitPowerMax("player", powerType)) or 0
        if maximum > 0 then
            local current = tonumber(UnitPower("player", powerType)) or 0
            return Percent(current, maximum), current, maximum
        end
    end
    return nil, nil, nil
end

Percent = function(current, maximum)
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    if maximum <= 0 then return 100 end
    return current * 100 / maximum
end

TargetIsValid = function()
    if not UnitExists("target") or UnitIsDead("target") then return false end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return false end
    return true
end

local function MergeSpellStats(destination, source)
    local key, stats
    for key, stats in pairs(source or {}) do
        local merged = destination[key]
        if not merged then
            merged = { name = stats.name or key, hits = 0, damage = 0, misses = 0, immune = 0, resists = 0 }
            destination[key] = merged
        end
        merged.hits = merged.hits + (stats.hits or 0)
        merged.damage = merged.damage + (stats.damage or 0)
        merged.misses = merged.misses + (stats.misses or 0)
        merged.immune = merged.immune + (stats.immune or 0)
        merged.resists = merged.resists + (stats.resists or 0)
    end
end

local function BuildTargetProfile()
    local profile = { valid = TargetIsValid(), spells = {}, samples = 0, encounters = 0, combatTime = 0, damageDone = 0 }
    if not profile.valid then return profile end

    profile.guid = UnitGUID("target")
    profile.name = UnitName("target") or "Créature inconnue"
    profile.nameKey = Lower(profile.name)
    profile.level = UnitLevel and (UnitLevel("target") or 0) or 0
    profile.classification = UnitClassification and UnitClassification("target") or "normal"
    profile.creatureType = UnitCreatureType and UnitCreatureType("target") or "Inconnu"
    profile.healthPercent = Percent(UnitHealth("target"), UnitHealthMax("target"))
    profile.maxHealth = UnitHealthMax("target") or 0

    local _, memory
    for _, memory in pairs(CoACombatAssistantDB.mobs or {}) do
        local sameName = Lower(memory.name) == profile.nameKey
        local sameType = not memory.creatureType or memory.creatureType == profile.creatureType
        local memoryLevel = tonumber(memory.level) or 0
        local closeLevel = memoryLevel <= 0 or profile.level <= 0 or math.abs(memoryLevel - profile.level) <= 3
        local recent = not memory.lastSeen or time() - memory.lastSeen <= TARGET_EXPERIENCE_MAX_AGE
        if sameName and sameType and closeLevel and recent then
            profile.samples = profile.samples + 1
            profile.encounters = profile.encounters + (memory.encounters or 0)
            profile.combatTime = profile.combatTime + (memory.combatTime or 0)
            profile.damageDone = profile.damageDone + (memory.damageDone or 0)
            MergeSpellStats(profile.spells, memory.spellStats)
        end
    end

    profile.averageDuration = profile.encounters > 0 and profile.combatTime / profile.encounters or nil
    local playerMaxHealth = UnitHealthMax("player") or 0
    profile.averageDanger = profile.encounters > 0 and playerMaxHealth > 0 and (profile.damageDone / profile.encounters) / playerMaxHealth or 0
    local levelDifference = profile.level - (character.level or 0)
    profile.elite = profile.classification == "elite" or profile.classification == "rareelite" or profile.classification == "worldboss"
    profile.durable = profile.elite or levelDifference >= 2 or profile.averageDuration and profile.averageDuration >= 12
    profile.shortLived = profile.encounters >= 2 and profile.averageDuration and profile.averageDuration < 7
    profile.dangerous = profile.elite or profile.averageDanger >= 0.45
    return profile
end

local function SpellExperience(profile, spellName)
    if not profile or not profile.spells or not spellName then return nil end
    local wanted = Lower(spellName)
    if wanted ~= Lower("Command: Undead") then return profile.spells[wanted] end
    local aggregate = { name = spellName, hits = 0, damage = 0, misses = 0, immune = 0, resists = 0 }
    local found = false
    local key, stats
    for key, stats in pairs(profile.spells) do
        if string.find(key, "command:", 1, true) == 1 then
            found = true
            aggregate.hits = aggregate.hits + (stats.hits or 0)
            aggregate.damage = aggregate.damage + (stats.damage or 0)
            aggregate.misses = aggregate.misses + (stats.misses or 0)
            aggregate.immune = aggregate.immune + (stats.immune or 0)
            aggregate.resists = aggregate.resists + (stats.resists or 0)
        end
    end
    return found and aggregate or nil
end

local Reject
local Explain

local function AdaptCandidateToTarget(candidate, profile, targetHealth)
    local rule = candidate.rule
    if not rule.requiresTarget or not profile or not profile.valid then return end

    if rule.minTargetHealth and targetHealth < rule.minTargetHealth then
        Reject(candidate, "cible trop proche de mourir pour cette préparation")
    end
    if rule.longSetup then
        if profile.shortLived and currentMode == "ST" then
            Reject(candidate, "mémoire : ce type de créature meurt trop vite pour ce sort")
        elseif profile.shortLived then
            candidate.score = candidate.score - 18
            Explain(candidate, "cibles habituellement courtes : préparation dépriorisée")
        elseif profile.durable then
            candidate.score = candidate.score + 12
            Explain(candidate, "cible durable : effet prolongé rentabilisé")
        end
    end
    if rule.directDamage and targetHealth <= 35 then
        candidate.score = candidate.score + 18
        Explain(candidate, "cible affaiblie : dégâts immédiats favorisés")
    end
    if rule.execute and targetHealth <= 35 then
        candidate.score = candidate.score + 28
        Explain(candidate, "phase d'exécution")
    end
    if rule.channel and targetHealth <= 20 then
        candidate.score = candidate.score - 20
        Explain(candidate, "cible presque morte : canalisation dépriorisée")
    end

    local stats = SpellExperience(profile, candidate.name)
    if not stats then return end
    local attempts = (stats.hits or 0) + (stats.misses or 0)
    if attempts >= 2 and (stats.immune or 0) >= 2 and stats.immune / attempts >= 0.5 then
        Reject(candidate, "mémoire : sort souvent immunisé sur cette créature")
    elseif attempts >= 3 and (stats.resists or 0) >= 2 and stats.resists / attempts >= 0.5 then
        candidate.score = candidate.score - 45
        Explain(candidate, "mémoire : sort souvent résisté, priorité réduite")
    elseif (stats.hits or 0) >= 3 and profile.maxHealth > 0 then
        local averageHit = (stats.damage or 0) / stats.hits
        local effectiveness = math.min(12, math.floor(averageHit * 100 / profile.maxHealth))
        candidate.score = candidate.score + effectiveness
        Explain(candidate, "mémoire : efficacité observée sur ce type de créature")
    end
end

local function CurrentPhase()
    if not startedAt then return "idle" end
    if GetTime() - startedAt < 6 and combatDamageEvents < 4 then return "opening" end
    return "established"
end

local function SpellState(spell, requiresTarget)
    local state = { ready = true, usable = true, noMana = false, inRange = nil, start = 0, duration = 0 }
    if not spell then
        state.ready = false
        state.usable = false
        return state
    end
    if GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spell.name)
        state.start = tonumber(start) or 0
        state.duration = tonumber(duration) or 0
        -- Les cooldowns très courts correspondent généralement au GCD 3.3.5 :
        -- l'icône suivante reste visible pendant ce délai.
        if enabled == 0 or state.duration > 1.6 and state.start + state.duration > GetTime() + 0.05 then
            state.ready = false
        end
    end
    if IsUsableSpell then
        local usable, noMana = IsUsableSpell(spell.name)
        state.usable = usable and true or false
        state.noMana = noMana and true or false
    end
    if requiresTarget and IsSpellInRange then
        local result = IsSpellInRange(spell.name, "target")
        if result ~= nil then state.inRange = result == 1 end
    end
    return state
end

Reject = function(candidate, reason)
    table.insert(candidate.rejected, reason)
end

Explain = function(candidate, reason)
    table.insert(candidate.reasons, reason)
end

local function EvaluateRule(rule, summonCount, phase, targetHealth, playerHealth, playerMana, runicPercent, targetProfile)
    local spell = LearnedSpell(rule.name)
    local candidate = {
        name = rule.name,
        rule = rule,
        spell = spell,
        score = rule.score or 0,
        reasons = {},
        rejected = {}
    }

    if not spell then
        Reject(candidate, "sort non appris")
        return candidate
    end
    if spell.passive then Reject(candidate, "sort passif") end
    if rule.minLevel and character.level < rule.minLevel then Reject(candidate, "niveau insuffisant") end
    if rule.requiresCombat and not startedAt then Reject(candidate, "réservé au combat") end
    local combatActive = startedAt ~= nil or (UnitAffectingCombat and UnitAffectingCombat("player"))
    if rule.preparationOnly and (combatActive or TargetIsValid()) then
        Reject(candidate, "préparation uniquement hors combat et sans cible hostile")
    end
    if rule.mode and rule.mode ~= currentMode then Reject(candidate, "réservé au mode " .. rule.mode) end
    if rule.minEnemies and currentEnemyCount < rule.minEnemies then Reject(candidate, "pas assez de cibles") end
    if rule.requiresTarget and not TargetIsValid() then Reject(candidate, "aucune cible hostile valide") end
    if rule.eliteOrBoss then
        local classification = TargetIsValid() and UnitClassification and UnitClassification("target") or nil
        if classification ~= "elite" and classification ~= "rareelite" and classification ~= "worldboss" then
            Reject(candidate, "réservé aux cibles élites ou boss")
        end
    end
    if rule.requiresSummon and summonCount < rule.requiresSummon then Reject(candidate, "invocation requise") end
    if rule.onlyWithoutSummon and summonCount > 0 then Reject(candidate, "une invocation est déjà active") end
    if rule.desiredSummons then
        local matching = CountMatchingSummons(rule)
        candidate.matchingSummons = matching
        if matching >= rule.desiredSummons then
            Reject(candidate, rule.desiredSummons .. " invocation(s) de ce type déjà active(s)")
        else
            Explain(candidate, matching .. "/" .. rule.desiredSummons .. " invocation(s) de ce type")
        end
        local maxArmySize = tonumber(CoACombatAssistantDB.settings.maxArmySize) or DEFAULT_MAX_ARMY_SIZE
        if summonCount >= maxArmySize then Reject(candidate, "armée complète (" .. summonCount .. "/" .. maxArmySize .. ")") end
    end
    if rule.openingOnly and phase == "established" then Reject(candidate, "réservé à l'ouverture") end
    if rule.phase and rule.phase ~= phase then Reject(candidate, "réservé à la phase " .. rule.phase) end
    if rule.maxTargetHealth and targetHealth > rule.maxTargetHealth then Reject(candidate, "santé de la cible trop élevée") end
    if rule.maxPlayerHealth and playerHealth > rule.maxPlayerHealth then Reject(candidate, "santé du joueur suffisante") end
    if rule.maxMana and playerMana > rule.maxMana then Reject(candidate, "ressource suffisante") end
    if rule.maxRunic and runicPercent and runicPercent > rule.maxRunic then Reject(candidate, "puissance runique proche du maximum") end
    if rule.minRunic and runicPercent and runicPercent < rule.minRunic then Reject(candidate, "puissance runique insuffisante") end
    if rule.selfBuffMissing and HasSelfBuff(rule.selfBuffMissing) then Reject(candidate, "buff déjà actif") end
    if rule.targetDebuffMissing and TargetIsValid() and HasTargetDebuff(rule.targetDebuffMissing) then Reject(candidate, "debuff déjà actif") end
    if rule.targetDebuffPresentAny and TargetIsValid() then
        local found = false
        local _, aura
        for _, aura in ipairs(rule.targetDebuffPresentAny) do
            if HasTargetDebuff(aura) then found = true break end
        end
        if not found then Reject(candidate, "maladie préalable absente") end
    end
    local recentLock = rule.recentLock or GLOBAL_RECENT_CAST_LOCK
    local last = lastCasts[SpellKey(rule.name)]
    if last and GetTime() - last < recentLock then Reject(candidate, "lancé récemment : proposer l'action suivante") end

    AdaptCandidateToTarget(candidate, targetProfile, targetHealth)

    candidate.state = SpellState(spell, rule.requiresTarget)
    if candidate.state.inRange == false then Reject(candidate, "cible hors de portée") end
    if candidate.state.noMana then Explain(candidate, "ressource insuffisante") end
    if not candidate.state.usable and not candidate.state.noMana then Explain(candidate, "sort momentanément inutilisable") end
    if not candidate.state.ready then Explain(candidate, "recharge en cours") end
    Explain(candidate, rule.reason or "priorité Animation")
    candidate.available = #candidate.rejected == 0
    candidate.ready = candidate.available and candidate.state.ready and candidate.state.usable and candidate.state.inRange ~= false
    if candidate.ready then candidate.score = candidate.score + 1000 else candidate.score = candidate.score - 100 end
    if rule.mode == currentMode then candidate.score = candidate.score + 15 end
    if phase == "opening" and not rule.phase then candidate.score = candidate.score + 2 end
    return candidate
end

local function BuildRecommendationQueue()
    local summonCount = CountOwnedSummons()
    local phase = CurrentPhase()
    local targetHealth = Percent(UnitHealth("target"), UnitHealthMax("target"))
    local playerHealth = Percent(UnitHealth("player"), UnitHealthMax("player"))
    local playerMana = Percent(UnitMana("player"), UnitManaMax("player"))
    local runicPercent, runicCurrent, runicMaximum = CurrentRunicPower()
    local targetProfile = BuildTargetProfile()
    local candidates = {}
    local rejected = {}
    local _, rule

    for _, rule in ipairs(animationPriority) do
        local candidate = EvaluateRule(rule, summonCount, phase, targetHealth, playerHealth, playerMana, runicPercent, targetProfile)
        if candidate.available then
            table.insert(candidates, candidate)
        else
            table.insert(rejected, candidate)
        end
    end

    table.sort(candidates, function(a, b)
        if a.score == b.score then return a.name < b.name end
        return a.score > b.score
    end)
    table.sort(rejected, function(a, b) return (a.rule.score or 0) > (b.rule.score or 0) end)

    currentQueue = {}
    local index
    for index = 1, math.min(3, #candidates) do currentQueue[index] = candidates[index] end
    currentRecommendation = currentQueue[1] and currentQueue[1].ready and currentQueue[1] or nil
    lastDecision = {
        mode = currentMode,
        enemyCount = currentEnemyCount,
        summonCount = summonCount,
        runicPercent = runicPercent,
        runicCurrent = runicCurrent,
        runicMaximum = runicMaximum,
        targetProfile = targetProfile,
        phase = phase,
        candidates = candidates,
        rejected = rejected,
        at = GetTime()
    }
end

local function ApplyCooldown(visual, state)
    if state and state.duration and state.duration > 0 then
        if visual.cooldown.SetCooldown then
            visual.cooldown:SetCooldown(state.start or 0, state.duration)
        elseif CooldownFrame_SetTimer then
            CooldownFrame_SetTimer(visual.cooldown, state.start or 0, state.duration, 1)
        end
        visual.cooldown:Show()
    else
        visual.cooldown:Hide()
    end
end

local function UpdateSpellVisual(visual, candidate)
    if not candidate or not candidate.spell then
        visual.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        visual.icon:SetVertexColor(0.45, 0.45, 0.45, 0.50)
        visual.key:SetText("")
        visual.glow:Hide()
        visual.cooldown:Hide()
        return
    end

    local texture = candidate.spell.texture
    if not texture and GetSpellTexture then texture = GetSpellTexture(candidate.spell.name) end
    visual.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    visual.key:SetText(candidate.spell.key or "")
    ApplyCooldown(visual, candidate.state)
    if candidate.ready then
        visual.icon:SetVertexColor(1, 1, 1, 1)
        visual.glow:Show()
    else
        visual.icon:SetVertexColor(0.45, 0.45, 0.45, 0.58)
        visual.glow:Hide()
    end
end

local function CandidateLabel(candidate)
    if not candidate or not candidate.spell then return "—" end
    local key = candidate.spell.key and " [" .. candidate.spell.key .. "]" or ""
    return candidate.spell.name .. key
end

local function RefreshEnemyMode()
    local now = GetTime()
    local count = 0
    local guid, seenAt
    for guid, seenAt in pairs(activeEnemies) do
        if now - seenAt > ENEMY_TIMEOUT then
            activeEnemies[guid] = nil
        else
            count = count + 1
        end
    end
    currentEnemyCount = count
    local threshold = tonumber(CoACombatAssistantDB.settings.aoeThreshold) or DEFAULT_AOE_THRESHOLD
    currentMode = count >= threshold and "AOE" or "ST"
    BuildRecommendationQueue()

    local summonCount = lastDecision.summonCount or 0
    modeText:SetText(currentMode .. " • " .. count .. " cible" .. (count > 1 and "s" or "") .. " • " .. summonCount .. " invocation" .. (summonCount > 1 and "s" or ""))
    UpdateSpellVisual(mainVisual, currentRecommendation)
    recommendationText:SetText(CandidateLabel(currentRecommendation))
    recommendationReasonText:SetText(currentRecommendation and Join(currentRecommendation.reasons, " • ") or "Aucune action utile")

    if unlocked then
        frame:EnableMouse(true)
        frame:Show()
    elseif CoACombatAssistantDB.visible and currentRecommendation then
        frame:EnableMouse(false)
        frame:Show()
    else
        frame:EnableMouse(false)
        frame:Hide()
    end

    if startedAt and count == 0 and lastCombatInteraction and now - lastCombatInteraction > ENEMY_TIMEOUT then
        if not UnitAffectingCombat or not UnitAffectingCombat("player") then EndCombat() end
    end
end

local function StartCombat()
    if startedAt then
        CaptureHostileTarget()
        return
    end
    startedAt = GetTime()
    activeEnemies = {}
    currentMobs = {}
    combatDamageEvents = 0
    lastCombatInteraction = GetTime()
    stateText:SetText("Combat en cours — recommandations uniquement")
    CaptureHostileTarget()
end

EndCombat = function()
    if not startedAt then return end
    local now = GetTime()
    local duration = math.floor(now - startedAt)
    local mobCount = 0
    local guid, encounter
    for guid, encounter in pairs(currentMobs) do
        mobCount = mobCount + 1
        local memory = CoACombatAssistantDB.mobs[guid]
        if memory then
            local observedDuration = math.max(0, now - (encounter.firstAt or startedAt))
            memory.encounters = (memory.encounters or 0) + 1
            memory.combatTime = (memory.combatTime or 0) + observedDuration
            memory.lastEncounter = time()
        end
    end
    table.insert(CoACombatAssistantDB.history, 1, { duration = duration, mobs = mobCount, mode = currentMode, at = time() })
    while #CoACombatAssistantDB.history > 30 do table.remove(CoACombatAssistantDB.history) end
    startedAt = nil
    activeEnemies = {}
    currentMobs = {}
    combatDamageEvents = 0
    lastCombatInteraction = nil
    timerText:SetText("00:00")
    stateText:SetText("Combat terminé • " .. mobCount .. " créature(s) mémorisée(s)")
end

local function RefreshDisplay()
    if startedAt then
        CaptureHostileTarget()
        local elapsed = math.floor(GetTime() - startedAt)
        timerText:SetText(string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60))
    end
    playerGUID = UnitGUID("player") or playerGUID
    RefreshPetGUID()
    RefreshEnemyMode()
    memoryText:SetText("Mémoire : " .. CountMemory() .. " créature(s) • Spellbook : " .. #spellOrder .. " sorts • AOE ≥ " .. CoACombatAssistantDB.settings.aoeThreshold)
end

engineFrame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < UPDATE_INTERVAL then return end
    lastUpdate = 0
    RefreshDisplay()
end)

local function DamageAmount(subevent, ...)
    if subevent == "SWING_DAMAGE" then
        local amount = select(1, ...)
        return tonumber(amount) or 0
    end
    if subevent == "ENVIRONMENTAL_DAMAGE" then
        local amount = select(2, ...)
        return tonumber(amount) or 0
    end
    if string.find(subevent, "_DAMAGE", 1, true) then
        local amount = select(4, ...)
        return tonumber(amount) or 0
    end
    return 0
end

local function IsCombatInteraction(subevent)
    return string.find(subevent, "_DAMAGE", 1, true)
        or string.find(subevent, "_MISSED", 1, true)
        or string.find(subevent, "_AURA_", 1, true)
        or subevent == "SPELL_INTERRUPT"
        or subevent == "SPELL_DISPEL"
        or subevent == "SPELL_STOLEN"
end

local function TrackCombatAura(subevent, sourceOwned, destGUID, spellName, auraType)
    if not spellName then return end
    local key = SpellKey(spellName)
    local applied = subevent == "SPELL_AURA_APPLIED"
        or subevent == "SPELL_AURA_REFRESH"
        or subevent == "SPELL_AURA_APPLIED_DOSE"
    local removed = subevent == "SPELL_AURA_REMOVED"
        or subevent == "SPELL_AURA_REMOVED_DOSE"

    if destGUID == playerGUID and trackedSelfBuffs[key] and (not auraType or auraType == "BUFF") then
        if applied then
            confirmedSelfBuffs[key] = true
            assumedSelfBuffs[key] = nil
        elseif removed then
            confirmedSelfBuffs[key] = nil
            assumedSelfBuffs[key] = nil
        end
    end

    if trackedTargetDebuffs[key] and destGUID then
        local confirmed = TargetDebuffTable(confirmedTargetDebuffs, destGUID, applied)
        local assumed = TargetDebuffTable(assumedTargetDebuffs, destGUID, false)
        if applied and sourceOwned and (not auraType or auraType == "DEBUFF") then
            confirmed[key] = true
            if assumed then assumed[key] = nil end
        elseif removed then
            if confirmed then confirmed[key] = nil end
            if assumed then assumed[key] = nil end
        end
    end
end

local function HandleCombatLog(...)
    local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
    if not subevent then return end
    local sourceOwned = IsOwnedActor(sourceGUID, sourceFlags, sourceName)
    local destOwned = IsOwnedActor(destGUID, destFlags, destName)

    if subevent == "SPELL_SUMMON" or subevent == "SPELL_CREATE" then
        if sourceOwned and destGUID then
            local spellId, spellName = select(9, ...), select(10, ...)
            RegisterOwnedSummon(destGUID, destName, destFlags, spellId, spellName)
        end
        return
    end

    if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
        if ownedSummons[destGUID] then
            ownedSummons[destGUID].dead = true
            ownedSummons[destGUID].lastSeen = GetTime()
        else
            MarkMobDeath(destGUID, destName)
        end
        return
    end

    if subevent == "PARTY_KILL" or subevent == "SPELL_INSTAKILL" then
        if sourceOwned then MarkMobDeath(destGUID, destName) end
        return
    end

    if subevent == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID then
        local spellName = select(10, ...)
        RecordPlayerCast(spellName)
    end

    if string.find(subevent, "SPELL_AURA_", 1, true) then
        TrackCombatAura(subevent, sourceOwned, destGUID, select(10, ...), select(12, ...))
    end

    if not IsCombatInteraction(subevent) then return end
    lastCombatInteraction = GetTime()
    local amount = DamageAmount(subevent, select(9, ...))
    local isSpellOutcome = (string.find(subevent, "SPELL_", 1, true) == 1 or string.find(subevent, "RANGE_", 1, true) == 1)
        and (string.find(subevent, "_DAMAGE", 1, true) or string.find(subevent, "_MISSED", 1, true))
    local outcomeSpellName = isSpellOutcome and select(10, ...) or nil
    local missType = string.find(subevent, "_MISSED", 1, true) and select(12, ...) or nil
    if string.find(subevent, "_DAMAGE", 1, true) then combatDamageEvents = combatDamageEvents + 1 end

    if sourceOwned and destGUID and not destOwned and IsHostile(destFlags) then
        if not startedAt then StartCombat() end
        local memory = RememberMob(destGUID, destName, subevent, "TAKEN", amount)
        if isSpellOutcome then
            RecordSpellOutcome(memory, outcomeSpellName, subevent, amount, missType)
            local commandAt = lastCasts[SpellKey("Command: Undead")]
            if sourceGUID ~= playerGUID and commandAt and GetTime() - commandAt <= 3 then
                RecordSpellOutcome(memory, "Command: Undead", subevent, amount, missType)
            end
        end
    elseif destOwned and sourceGUID and not sourceOwned and IsHostile(sourceFlags) then
        if not startedAt then StartCombat() end
        RememberMob(sourceGUID, sourceName, subevent, "DONE", amount)
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        EnsureDatabase()
        initialized = true
        unlocked = not CoACombatAssistantDB.locked
        playerGUID = UnitGUID("player")
        RefreshPetGUID()
        if CoACombatAssistantDB.position then
            self:ClearAllPoints()
            self:SetPoint(CoACombatAssistantDB.position[1], UIParent, CoACombatAssistantDB.position[2], CoACombatAssistantDB.position[3], CoACombatAssistantDB.position[4])
        end
        if unlocked then
            self:EnableMouse(true)
            self:Show()
        else
            self:EnableMouse(false)
            self:Hide()
        end
    elseif not initialized then
        return
    elseif event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player") or playerGUID
        RefreshPetGUID()
        ScanSpellbook(true)
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        ScanActionBindings()
    elseif event == "PLAYER_LEVEL_UP" then
        ScanCharacter()
    elseif event == "PLAYER_REGEN_DISABLED" then
        StartCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        EndCombat()
    elseif event == "PLAYER_TARGET_CHANGED" then
        CaptureHostileTarget()
        RefreshDisplay()
    elseif event == "UNIT_PET" then
        local unit = ...
        if unit == "player" then RefreshPetGUID() end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or unit == "target" then RefreshDisplay() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName = ...
        if unit == "player" then
            if type(spellName) == "number" and GetSpellInfo then spellName = GetSpellInfo(spellName) end
            RecordPlayerCast(spellName)
            RefreshDisplay()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLog(...)
    end
end)

local function PrintStatus()
    RefreshDisplay()
    Chat("Niveau " .. character.level .. ", " .. character.className .. ", spé " .. character.spec)
    Chat(#spellOrder .. " sorts connus, " .. currentMode .. " avec " .. currentEnemyCount .. " cible(s), " .. CountOwnedSummons() .. " invocation(s)")
    Chat("Prochain sort : " .. (currentRecommendation and CandidateLabel(currentRecommendation) or "aucun"))
end

local function PrintMemory(filter)
    local entries = {}
    local guid, data
    filter = Lower(Trim(filter))
    for guid, data in pairs(CoACombatAssistantDB.mobs) do
        if filter == "" or string.find(Lower(data.name), filter, 1, true) or string.find(Lower(guid), filter, 1, true) then
            table.insert(entries, data)
        end
    end
    table.sort(entries, function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end)
    Chat(#entries .. " créature(s) mémorisée(s)" .. (filter ~= "" and " pour « " .. filter .. " »" or "") .. ".")
    local index
    for index = 1, math.min(12, #entries) do
        local data = entries[index]
        Chat(index .. ". " .. (data.name or "Inconnue")
            .. " | GUID " .. (data.guid or "?")
            .. " | " .. (data.creatureType or "type inconnu") .. " niv. " .. (data.level or "?")
            .. " | rencontres " .. (data.encounters or 0)
            .. " | morts " .. (data.deaths or 0)
            .. " | temps " .. Round(data.combatTime) .. "s"
            .. " | reçus " .. Round(data.damageTaken)
            .. " | infligés " .. Round(data.damageDone)
            .. " | " .. (data.zone or "zone inconnue"))
    end
end

local function PrintDebug()
    RefreshDisplay()
    Chat("Décision : " .. currentMode .. ", " .. currentEnemyCount .. " cible(s), " .. (lastDecision.summonCount or 0) .. " invocation(s), phase " .. (lastDecision.phase or "?") .. ".")
    local profile = lastDecision.targetProfile
    if profile and profile.valid then
        local duration = profile.averageDuration and string.format("%.1fs", profile.averageDuration) or "inconnue"
        Chat("Cible : " .. profile.name .. ", " .. (profile.creatureType or "type inconnu")
            .. ", niveau " .. (profile.level or "?") .. ", " .. (profile.classification or "normal")
            .. ", vie " .. Round(profile.healthPercent) .. "%, durée moyenne " .. duration
            .. ", " .. (profile.encounters or 0) .. " combat(s) appris.")
    else
        Chat("Cible : aucune créature hostile valide.")
    end
    if lastDecision.runicMaximum then
        Chat("Puissance runique : " .. Round(lastDecision.runicCurrent) .. "/" .. Round(lastDecision.runicMaximum) .. ".")
    else
        Chat("Puissance runique : API non exposée, IsUsableSpell décide.")
    end
    if lastPlayerCastName and lastPlayerCastAt then
        Chat("Dernier sort confirmé : " .. lastPlayerCastName .. " (il y a " .. string.format("%.1f", GetTime() - lastPlayerCastAt) .. "s).")
    end
    if currentRecommendation then
        Chat("CHOISI " .. currentRecommendation.name .. " : " .. Join(currentRecommendation.reasons, ", "))
    else
        Chat("Aucun candidat disponible.")
    end
    local index
    for index = 1, math.min(8, #(lastDecision.rejected or {})) do
        local candidate = lastDecision.rejected[index]
        Chat("REJETÉ " .. candidate.name .. " : " .. Join(candidate.rejected, ", "))
    end
    for index = 1, math.min(3, #(lastDecision.candidates or {})) do
        local candidate = lastDecision.candidates[index]
        if candidate ~= currentRecommendation then
            Chat("FILE " .. candidate.name .. " : " .. Join(candidate.reasons, ", "))
        end
    end
end

local function SetUnlocked(value)
    unlocked = value and true or false
    CoACombatAssistantDB.locked = not unlocked
    if unlocked then
        frame:EnableMouse(true)
        frame:Show()
        CoACombatAssistantDB.visible = true
        stateText:SetText("Déverrouillé — glissez la fenêtre puis /cca lock")
        Chat("Fenêtre déverrouillée.")
    else
        SavePosition()
        frame:EnableMouse(false)
        stateText:SetText("Verrouillé — recommandations uniquement")
        Chat("Fenêtre verrouillée et position enregistrée.")
        RefreshDisplay()
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
            PrintMemory(arguments)
        end
    elseif command == "debug" then
        PrintDebug()
    elseif command == "aoe" then
        local threshold = tonumber(Trim(arguments))
        if threshold and threshold >= 1 and threshold <= 20 then
            CoACombatAssistantDB.settings.aoeThreshold = math.floor(threshold)
            Chat("Seuil AOE réglé à " .. CoACombatAssistantDB.settings.aoeThreshold .. " cible(s).")
            RefreshDisplay()
        else
            Chat("Seuil AOE actuel : " .. CoACombatAssistantDB.settings.aoeThreshold .. ". Utilisation : /cca aoe 3")
        end
    elseif command == "reset" then
        CoACombatAssistantDB.position = nil
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
        Chat("Position réinitialisée.")
    elseif command == "show" then
        CoACombatAssistantDB.visible = true
        RefreshDisplay()
    elseif command == "hide" then
        frame:Hide()
        CoACombatAssistantDB.visible = false
    elseif command == "" then
        if CoACombatAssistantDB.visible then
            frame:Hide()
            CoACombatAssistantDB.visible = false
        else
            CoACombatAssistantDB.visible = true
            RefreshDisplay()
        end
    else
        Chat("/cca status | scan | unlock | lock | memory [filtre|clear] | debug | aoe [seuil] | show | hide | reset")
    end
end

SLASH_COACOMBATASSISTANT1 = "/cca"
SLASH_COACOMBATASSISTANT2 = "/coacombat"
SlashCmdList.COACOMBATASSISTANT = SlashHandler
