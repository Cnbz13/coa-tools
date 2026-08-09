local addonName = ...

local UPDATE_INTERVAL = 0.08
local MEMORY_LIMIT = 250
local ENEMY_TIMEOUT = 8
local SUMMON_TIMEOUT = 300
local DEFAULT_AOE_THRESHOLD = 3
local DEFAULT_DESIRED_SUMMONS = 3

local function Lower(value)
    return string.lower(value or "")
end

local function Trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
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
frame:SetWidth(430)
frame:SetHeight(235)
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
frame:SetBackdropColor(0.03, 0.04, 0.07, 0.95)
frame:SetBackdropBorderColor(0.75, 0.55, 0.25, 0.9)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -10)
title:SetText("CoA Combat Assistant")

local characterText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
characterText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -35)
characterText:SetWidth(320)
characterText:SetJustifyH("LEFT")

local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
timerText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -34)
timerText:SetText("00:00")

local modeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
modeText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -55)
modeText:SetWidth(400)
modeText:SetJustifyH("LEFT")
modeText:SetText("ST • 0 cible • 0 invocation")

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

local mainVisual = CreateSpellVisual(frame, 54, "TOPLEFT", frame, "TOPLEFT", 16, -79)

local recommendationText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
recommendationText:SetPoint("TOPLEFT", frame, "TOPLEFT", 82, -78)
recommendationText:SetWidth(330)
recommendationText:SetJustifyH("LEFT")
recommendationText:SetText("Analyse du spellbook…")

local recommendationReasonText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
recommendationReasonText:SetPoint("TOPLEFT", frame, "TOPLEFT", 82, -102)
recommendationReasonText:SetWidth(330)
recommendationReasonText:SetHeight(30)
recommendationReasonText:SetJustifyH("LEFT")
recommendationReasonText:SetJustifyV("TOP")

local queueLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
queueLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 82, -134)
queueLabel:SetText("Ensuite")

local secondVisual = CreateSpellVisual(frame, 32, "TOPLEFT", frame, "TOPLEFT", 82, -150)
local secondText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secondText:SetPoint("LEFT", secondVisual, "RIGHT", 6, 0)
secondText:SetWidth(105)
secondText:SetJustifyH("LEFT")

local thirdVisual = CreateSpellVisual(frame, 32, "TOPLEFT", frame, "TOPLEFT", 237, -150)
local thirdText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
thirdText:SetPoint("LEFT", thirdVisual, "RIGHT", 6, 0)
thirdText:SetWidth(105)
thirdText:SetJustifyH("LEFT")

local memoryText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
memoryText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 31)
memoryText:SetWidth(400)
memoryText:SetJustifyH("LEFT")

local stateText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stateText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 13)
stateText:SetWidth(400)
stateText:SetJustifyH("LEFT")
stateText:SetText("Prêt — /cca status")

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
local currentMode = "ST"
local currentEnemyCount = 0
local currentRecommendation = nil
local currentQueue = {}
local lastDecision = { candidates = {}, rejected = {} }
local combatDamageEvents = 0
local lastCombatInteraction = nil
local EndCombat
local character = { level = 0, className = "Inconnue", classToken = "UNKNOWN", spec = "Inconnue" }

-- Priorités strictement construites à partir du spellbook Animation observé en jeu.
-- Aucun motif générique "Command:" ou "Animate:" n'est utilisé comme fallback.
local animationPriority = {
    { name = "Bone Ward", score = 118, selfBuffMissing = "Bone Ward", reason = "protection personnelle absente" },
    { name = "Sacrifice Undead", score = 116, maxPlayerHealth = 32, requiresSummon = 1, reason = "survie critique" },
    { name = "Call of The Scourge", score = 112, mode = "AOE", minEnemies = 4, reason = "groupe important d'ennemis" },
    { name = "March of the Dead", score = 110, mode = "AOE", minEnemies = 3, reason = "phase AOE avec trois cibles ou plus" },
    { name = "Grave March", score = 106, mode = "AOE", minEnemies = 3, requiresSummon = 2, reason = "plusieurs invocations en AOE" },
    { name = "Crypt Swarm", score = 104, mode = "AOE", minEnemies = 3, requiresTarget = true, reason = "dégâts de zone prioritaires" },
    { name = "Corpse Explosion", score = 100, mode = "AOE", minEnemies = 3, requiresTarget = true, maxTargetHealth = 45, phase = "established", reason = "cible affaiblie dans un groupe" },
    { name = "Raise: Crypt Fiend", score = 98, maxSummons = DEFAULT_DESIRED_SUMMONS, reason = "compléter les invocations actives" },
    { name = "Raise: Greater Skeletal Warrior", score = 96, maxSummons = DEFAULT_DESIRED_SUMMONS, reason = "compléter les invocations actives" },
    { name = "Animate: Skeletal Archer", score = 94, maxSummons = DEFAULT_DESIRED_SUMMONS, reason = "compléter les invocations actives" },
    { name = "Raise: Abomination", score = 92, maxSummons = DEFAULT_DESIRED_SUMMONS, reason = "compléter les invocations actives" },
    { name = "Raise: Lesser Skeletal Warrior", score = 90, maxSummons = DEFAULT_DESIRED_SUMMONS, reason = "aucune armée active", onlyWithoutSummon = true },
    { name = "Foul Mandate", score = 88, requiresTarget = true, targetDebuffMissing = "Foul Mandate", reason = "ouvrir avec Foul Mandate" },
    { name = "Blight", score = 86, requiresTarget = true, targetDebuffMissing = "Blight", reason = "appliquer Blight" },
    { name = "Harvest Plague", score = 84, requiresTarget = true, targetDebuffPresentAny = { "Blight", "Foul Mandate" }, phase = "established", reason = "exploiter les maladies actives" },
    { name = "Command: Undead", score = 82, requiresTarget = true, requiresSummon = 1, phase = "established", recentLock = 4.5, reason = "ordonner l'attaque aux invocations actives" },
    { name = "Lichfrost", score = 78, requiresTarget = true, reason = "attaque monocible disponible" },
    { name = "Razorice", score = 76, requiresTarget = true, reason = "attaque monocible de complément" },
    { name = "Ghoulify", score = 72, requiresTarget = true, maxTargetHealth = 35, phase = "established", reason = "cible à faible santé" },
    { name = "Glacial Tap", score = 70, maxMana = 35, reason = "ressource faible" },
    { name = "Runic Harvest", score = 68, maxMana = 45, reason = "récupération de ressource" }
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
    CoACombatAssistantDB.settings.desiredSummons = tonumber(CoACombatAssistantDB.settings.desiredSummons) or DEFAULT_DESIRED_SUMMONS
    CoACombatAssistantDB.version = "1.0.6"

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

local function IsOwnedActor(guid, flags)
    if not guid then return false end
    if guid == playerGUID or guid == petGUID then return true end
    if ownedSummons[guid] then
        ownedSummons[guid].lastSeen = GetTime()
        return true
    end
    if HasMineFlag(flags) then
        RegisterOwnedSummon(guid, nil, flags, nil, "Affiliation joueur")
        return true
    end
    return false
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

local function HasAura(unit, auraName, harmful)
    if not auraName then return false end
    local wanted = Lower(auraName)
    local index
    for index = 1, 40 do
        local name
        if harmful then name = UnitDebuff(unit, index) else name = UnitBuff(unit, index) end
        if not name then break end
        if Lower(name) == wanted then return true end
    end
    return false
end

local function Percent(current, maximum)
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    if maximum <= 0 then return 100 end
    return current * 100 / maximum
end

local function TargetIsValid()
    if not UnitExists("target") or UnitIsDead("target") then return false end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return false end
    return true
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
        if enabled == 0 or state.duration > 0 and state.start + state.duration > GetTime() + 0.05 then
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

local function Reject(candidate, reason)
    table.insert(candidate.rejected, reason)
end

local function Explain(candidate, reason)
    table.insert(candidate.reasons, reason)
end

local function EvaluateRule(rule, summonCount, phase, targetHealth, playerHealth, playerMana)
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
    if rule.mode and rule.mode ~= currentMode then Reject(candidate, "réservé au mode " .. rule.mode) end
    if rule.minEnemies and currentEnemyCount < rule.minEnemies then Reject(candidate, "pas assez de cibles") end
    if rule.requiresTarget and not TargetIsValid() then Reject(candidate, "aucune cible hostile valide") end
    if rule.requiresSummon and summonCount < rule.requiresSummon then Reject(candidate, "invocation requise") end
    if rule.onlyWithoutSummon and summonCount > 0 then Reject(candidate, "une invocation est déjà active") end
    if rule.maxSummons then
        local desired = tonumber(CoACombatAssistantDB.settings.desiredSummons) or rule.maxSummons
        if summonCount >= desired then Reject(candidate, "armée déjà complète") end
    end
    if rule.phase and rule.phase ~= phase then Reject(candidate, "réservé à la phase " .. rule.phase) end
    if rule.maxTargetHealth and targetHealth > rule.maxTargetHealth then Reject(candidate, "santé de la cible trop élevée") end
    if rule.maxPlayerHealth and playerHealth > rule.maxPlayerHealth then Reject(candidate, "santé du joueur suffisante") end
    if rule.maxMana and playerMana > rule.maxMana then Reject(candidate, "ressource suffisante") end
    if rule.selfBuffMissing and HasAura("player", rule.selfBuffMissing, false) then Reject(candidate, "buff déjà actif") end
    if rule.targetDebuffMissing and TargetIsValid() and HasAura("target", rule.targetDebuffMissing, true) then Reject(candidate, "debuff déjà actif") end
    if rule.targetDebuffPresentAny and TargetIsValid() then
        local found = false
        local _, aura
        for _, aura in ipairs(rule.targetDebuffPresentAny) do
            if HasAura("target", aura, true) then found = true break end
        end
        if not found then Reject(candidate, "maladie préalable absente") end
    end
    if rule.recentLock then
        local last = lastCasts[Lower(rule.name)]
        if last and GetTime() - last < rule.recentLock then Reject(candidate, "lancé récemment") end
    end

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
    local candidates = {}
    local rejected = {}
    local _, rule

    for _, rule in ipairs(animationPriority) do
        local candidate = EvaluateRule(rule, summonCount, phase, targetHealth, playerHealth, playerMana)
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
    currentRecommendation = currentQueue[1]
    lastDecision = {
        mode = currentMode,
        enemyCount = currentEnemyCount,
        summonCount = summonCount,
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
    UpdateSpellVisual(mainVisual, currentQueue[1])
    UpdateSpellVisual(secondVisual, currentQueue[2])
    UpdateSpellVisual(thirdVisual, currentQueue[3])
    recommendationText:SetText(CandidateLabel(currentQueue[1]))
    recommendationReasonText:SetText(currentQueue[1] and Join(currentQueue[1].reasons, " • ") or "Aucun sort Animation appris et pertinent")
    secondText:SetText(CandidateLabel(currentQueue[2]))
    thirdText:SetText(CandidateLabel(currentQueue[3]))

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
    CaptureHostileTarget()
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
        timerText:SetText(string.format("%02d:%02d", math.floor(elapsed / 60), math.mod(elapsed, 60)))
    end
    playerGUID = UnitGUID("player") or playerGUID
    RefreshPetGUID()
    RefreshEnemyMode()
    memoryText:SetText("Mémoire : " .. CountMemory() .. " créature(s) • Spellbook : " .. #spellOrder .. " sorts • AOE ≥ " .. CoACombatAssistantDB.settings.aoeThreshold)
end

frame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < UPDATE_INTERVAL then return end
    lastUpdate = 0
    RefreshDisplay()
end)

local function DamageAmount(subevent, ...)
    if subevent == "SWING_DAMAGE" then return tonumber(select(1, ...)) or 0 end
    if subevent == "ENVIRONMENTAL_DAMAGE" then return tonumber(select(2, ...)) or 0 end
    if string.find(subevent, "_DAMAGE", 1, true) then return tonumber(select(4, ...)) or 0 end
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

local function HandleCombatLog(...)
    local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
    if not subevent then return end
    local sourceOwned = IsOwnedActor(sourceGUID, sourceFlags)
    local destOwned = IsOwnedActor(destGUID, destFlags)

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
        if spellName then lastCasts[Lower(spellName)] = GetTime() end
    end

    if not IsCombatInteraction(subevent) then return end
    lastCombatInteraction = GetTime()
    local amount = DamageAmount(subevent, select(9, ...))
    if string.find(subevent, "_DAMAGE", 1, true) then combatDamageEvents = combatDamageEvents + 1 end

    if sourceOwned and destGUID and not destOwned and IsHostile(destFlags) then
        if not startedAt then StartCombat() end
        RememberMob(destGUID, destName, subevent, "TAKEN", amount)
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
        if CoACombatAssistantDB.visible then self:Show() else self:Hide() end
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
        Chat("/cca status | scan | unlock | lock | memory [filtre|clear] | debug | aoe [seuil] | show | hide | reset")
    end
end

SLASH_COACOMBATASSISTANT1 = "/cca"
SLASH_COACOMBATASSISTANT2 = "/coacombat"
SlashCmdList.COACOMBATASSISTANT = SlashHandler
