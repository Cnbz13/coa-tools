local addonName = ...

-- CoA Stormbringer Helper 1.0.0
-- Project Ascension / Conquest of Azeroth, client WoW 3.3.5a, Lua 5.1.
-- Recommendations only: this addon never casts, targets or clicks a spell.

local VERSION = "1.0.0"
local SOURCE_DATE = "2026-08-26"
local BOOK = BOOKTYPE_SPELL or "spell"
local lower = string.lower
local floor = math.floor
local max = math.max
local min = math.min

local db
local spellbook = {}
local spellList = {}
local talents = {}
local talentList = {}
local playerLevel = 0
local playerGUID = nil
local activeSpec = "Initiation"
local specSource = "niveau 1-9"
local classActive = false
local currentAction = nil
local currentProc = nil
local lastDecision = nil
local lastActionKey = nil
local lastSoundAt = 0
local scanPendingAt = 0
local refreshElapsed = 0
local testUntil = 0
local toastUntil = 0
local hubManaged = false
local activeEnemies = {}
local ownedSummons = {}
local assumedServantUntil = 0
local assumedOrbUntil = 0
local assumedOrbCount = 0
local lastCombatAt = 0

local hud, icon, cooldown, glow, keyText, actionText, metaText, reasonText, staticBar, staticFill, editOverlay
local menu, menuStatus, menuDetail, minimapButton, toast, toastTitle, toastText
local scannerTooltip = CreateFrame("GameTooltip", "CoAStormbringerScannerTooltip", UIParent, "GameTooltipTemplate")
scannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function Normalize(value)
    value = lower(tostring(value or ""))
    value = string.gsub(value, "|c%x%x%x%x%x%x%x%x", "")
    value = string.gsub(value, "|r", "")
    value = string.gsub(value, "[^%w]", "")
    return value
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff62d7ffStormbringer Helper:|r " .. tostring(message))
    end
end

local function CharacterKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return tostring(realm) .. "-" .. tostring(name)
end

local function EnsureDB()
    CoAStormbringerHelperDB = CoAStormbringerHelperDB or {}
    db = CoAStormbringerHelperDB
    if db.enabled == nil then db.enabled = true end
    if db.locked == nil then db.locked = true end
    if db.sound == nil then db.sound = true end
    if db.showText == nil then db.showText = true end
    if db.showBurst == nil then db.showBurst = true end
    if db.buttonHidden == nil then db.buttonHidden = false end
    if type(db.scale) ~= "number" then db.scale = 1.0 end
    if type(db.x) ~= "number" then db.x = 0 end
    if type(db.y) ~= "number" then db.y = -115 end
    if type(db.buttonAngle) ~= "number" then db.buttonAngle = 3.65 end
    if type(db.characters) ~= "table" then db.characters = {} end
    if type(db.updateSeen) ~= "table" then db.updateSeen = {} end
    return db
end

local ALIASES = {
    shock = { "Shock", "Voltaic Burst", "Brine" },
    brine = { "Brine", "Shock", "Voltaic Burst" },
    discharge = { "Discharge" },
    lightningRod = { "Lightning Rod", "Binding Shock" },
    tempest = { "Tempest", "Gale Guard" },
    invigoratingSurge = { "Invigorating Surge" },
    callLightning = { "Call Lightning" },
    bodyLightning = { "Body of Lightning" },
    conjureStorm = { "Conjure Storm" },
    stormAscendance = { "Storm Ascendance" },
    armThorim = { "Arm of Thorim" },
    forkedLightning = { "Forked Lightning" },
    volt = { "Volt", "Stormfuse" },
    electrocute = { "Electrocute" },
    lightningCage = { "Lightning Cage" },
    charge = { "Charge", "Stormcharge" },
    torrential = { "Torrential Wrath", "Thunderstrike" },
    deluge = { "Deluge", "Expulsion" },
    drown = { "Drown", "Empower Orbs" },
    summonOrb = { "Summon: Thunder Orb", "Summon Thunder Orb" },
    orbDetonation = { "Flow of Wrath", "Orb Detonation" },
    fistLeiShen = { "Fist of Lei Shen", "Eye of the Storm" },
    thunderKing = { "Thunder King" },
    summonAir = { "Summon: Air Elemental", "Summon Air Elemental", "Air Elemental", "Wind Servant" },
    gale = { "Gale", "Gale Winds" },
    aeroblast = { "Aeroblast", "Choking Cloud" },
    slicingWind = { "Slicing Wind", "Razorwind" },
    cloudburst = { "Cloudburst" },
    windride = { "Windride" }
}

local SPEC_MARKERS = {
    Lightning = { "Electrocutioner", "Arm of Thorim", "Forked Lightning", "Volt", "Titanstorm", "Lightning Cage" },
    Maelstrom = { "Conductive", "Tempest Sovereign", "Brine", "Torrential Rage", "Drown", "Stormcloud", "Hydromatic" },
    Wind = { "Air Elemental", "Wind Stormbringer", "Clear Skies", "Gale", "Child of the Storm", "Kiss of the Clouds" }
}

local PROC_RULES = {
    Lightning = {
        { auras = { "Never Strikes Twice?", "Born From Thunder", "Thorim's Gift" }, action = "armThorim", text = "Bras de Thorim renforcé" },
        { auras = { "Storm Chaser" }, action = "callLightning", text = "incantation accélérée" },
        { auras = { "Charge", "Stormcharge" }, action = "armThorim", text = "Static chargée" },
        { auras = { "Storm Ascendance", "Lord of Lightning" }, action = nil, text = "fenêtre de foudre active" }
    },
    Maelstrom = {
        { auras = { "Predictable Weather" }, action = "torrential", text = "Torrential instantané" },
        { auras = { "Bursting", "Charge Orb" }, action = "orbDetonation", text = "orbes prêtes à éclater" },
        { auras = { "Hydromatic", "Thunderous Blast" }, action = "torrential", text = "décharge renforcée" },
        { auras = { "Amped Flow", "Amplified Orbs" }, action = "orbDetonation", text = "orbes amplifiées" }
    },
    Wind = {
        { auras = { "Child of the Storm", "Unbound", "Typhoon" }, action = "gale", text = "serviteur déchaîné" },
        { auras = { "Quickdraft", "Master Elementalist" }, action = "aeroblast", text = "rafale accélérée" },
        { auras = { "Tailwind", "Hastening Winds" }, action = "aeroblast", text = "fenêtre de hâte" }
    }
}

local RULES = {
    Initiation = {
        { key = "shock", score = 320, reason = "Ton attaque de base est disponible." },
        { key = "discharge", score = 300, reason = "Décharge est ton attaque directe de début de progression." },
        { key = "callLightning", score = 290, reason = "Dépense ta Static sans la laisser plafonner." }
    },
    Lightning = {
        { key = "armThorim", score = 1000, minStatic = 75, reason = "Dépense une grosse réserve de Static avec ton finisher principal." },
        { key = "electrocute", score = 930, maxTargetHealth = 35, reason = "La cible est assez basse pour ta frappe d'exécution." },
        { key = "stormAscendance", score = 850, burst = true, reason = "Une cible durable permet de rentabiliser toute la fenêtre de burst." },
        { key = "conjureStorm", score = 800, minEnemies = 3, reason = "Le pack est assez grand pour rentabiliser la tempête au sol." },
        { key = "forkedLightning", score = 750, minEnemies = 2, reason = "Plusieurs ennemis donnent davantage de Static à cette frappe." },
        { key = "lightningCage", score = 700, elite = true, reason = "La cible devrait vivre assez longtemps pour la canalisation." },
        { key = "volt", score = 640, debuffMissing = { "Volt", "Stormfuse" }, reason = "Pose Volt tôt pour profiter de ses ticks de dégâts et de Static." },
        { key = "callLightning", score = 430, maxStatic = 74, reason = "Convertis une partie de la Static pendant que ton finisher attend." },
        { key = "shock", score = 330, reason = "Continue à générer de la pression et de la Static." },
        { key = "discharge", score = 300, reason = "Remplissage direct pendant le retour des priorités." }
    },
    Maelstrom = {
        { key = "orbDetonation", score = 1050, minOrbs = 2, reason = "Tes orbes installées rendent la détonation rentable." },
        { key = "orbDetonation", score = 1030, minConductive = 3, reason = "La cible porte assez de Conductive pour chercher le payoff." },
        { key = "drown", score = 900, minOrbs = 1, reason = "Renforce les orbes déjà installées avant de les faire partir." },
        { key = "deluge", score = 850, minEnemies = 3, reason = "Le pack est assez regroupé pour Deluge." },
        { key = "conjureStorm", score = 820, minEnemies = 3, reason = "La zone continuera à travailler pendant ta boucle principale." },
        { key = "summonOrb", score = 760, maxOrbs = 2, reason = "Installe une Thunder Orb avant de préparer sa détonation." },
        { key = "torrential", score = 700, reason = "C'est ta frappe prioritaire quand l'installation est en place." },
        { key = "fistLeiShen", score = 620, elite = true, reason = "Garde la pression sur cette cible durable." },
        { key = "brine", score = 570, debuffMissing = { "Brine", "Wet", "Drenched", "Conductive" }, reason = "Mouille la cible avant d'exploiter la partie foudre." },
        { key = "callLightning", score = 430, reason = "Dépense la Static disponible sans casser la préparation." },
        { key = "discharge", score = 300, reason = "Remplissage direct pendant le retour des outils Maelstrom." }
    },
    Wind = {
        { key = "summonAir", score = 1050, servantMissing = true, reason = "Ton Air Elemental est le cœur de la spécialisation Wind." },
        { key = "gale", score = 980, servantRequired = true, reason = "Gale renforce ton serviteur et fait monter sa mécanique Typhoon." },
        { key = "aeroblast", score = 820, reason = "Ta rafale principale est prête sur la cible actuelle." },
        { key = "conjureStorm", score = 790, minEnemies = 3, reason = "Le pack restera sous la tempête pendant que ton serviteur frappe." },
        { key = "slicingWind", score = 730, minEnemies = 2, reason = "La rafale prend sa valeur avec plusieurs ennemis alignés." },
        { key = "callLightning", score = 430, reason = "Utilise la Static disponible entre deux rafales Wind." },
        { key = "shock", score = 340, reason = "Continue la pression pendant le retour des sorts Wind." },
        { key = "discharge", score = 300, reason = "Remplissage direct disponible." }
    }
}

local function TooltipText(index)
    if not scannerTooltip or not index then return "" end
    scannerTooltip:ClearLines()
    local ok = pcall(scannerTooltip.SetSpellBookItem, scannerTooltip, index, BOOK)
    if not ok then return "" end
    local parts = {}
    local line
    for line = 1, 20 do
        local left = _G["CoAStormbringerScannerTooltipTextLeft" .. line]
        local right = _G["CoAStormbringerScannerTooltipTextRight" .. line]
        if left and left:GetText() then table.insert(parts, left:GetText()) end
        if right and right:GetText() then table.insert(parts, right:GetText()) end
    end
    return table.concat(parts, " ")
end

local function ScanSpellbook()
    spellbook = {}
    spellList = {}
    if not GetNumSpellTabs or not GetSpellTabInfo then return end
    local tab
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        offset = tonumber(offset) or 0
        count = tonumber(count) or 0
        local index
        for index = offset + 1, offset + count do
            local name, rank
            if GetSpellBookItemName then name, rank = GetSpellBookItemName(index, BOOK)
            elseif GetSpellName then name, rank = GetSpellName(index, BOOK) end
            if name then
                local texture = GetSpellTexture and GetSpellTexture(index, BOOK) or nil
                local infoName, _, infoTexture = GetSpellInfo and GetSpellInfo(index, BOOK)
                if infoName then name = infoName end
                if infoTexture then texture = infoTexture end
                local passive = false
                if IsPassiveSpell then
                    local ok, result = pcall(IsPassiveSpell, index, BOOK)
                    passive = ok and result and true or false
                end
                local link = GetSpellLink and GetSpellLink(index, BOOK) or nil
                local spellID = link and tonumber(string.match(link, "spell:(%d+)")) or nil
                local rankNumber = tonumber(string.match(tostring(rank or ""), "(%d+)")) or 0
                local entry = { name = name, rank = rank, rankNumber = rankNumber, index = index, texture = texture,
                    passive = passive, spellID = spellID, tooltip = TooltipText(index) }
                local key = Normalize(name)
                if not spellbook[key] or rankNumber >= (spellbook[key].rankNumber or 0) then spellbook[key] = entry end
            end
        end
    end
    local _, entry
    for _, entry in pairs(spellbook) do table.insert(spellList, entry) end
    table.sort(spellList, function(a, b) return tostring(a.name) < tostring(b.name) end)
end

local function ScanTalents()
    talents = {}
    talentList = {}
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        local tab
        for tab = 1, GetNumTalentTabs() do
            local count = tonumber(GetNumTalents(tab)) or 0
            local index
            for index = 1, count do
                local ok, name, iconTexture, tier, column, rank = pcall(GetTalentInfo, tab, index)
                rank = ok and tonumber(rank) or 0
                if ok and name and rank > 0 then
                    local entry = { name = name, rank = rank, icon = iconTexture, tier = tier, column = column, source = "classic" }
                    talents[Normalize(name)] = entry
                    table.insert(talentList, entry)
                end
            end
        end
    end
    if type(CoALootDeciderAPI) == "table" and type(CoALootDeciderAPI.GetAdaptiveBuild) == "function" then
        local ok, adaptive = pcall(CoALootDeciderAPI.GetAdaptiveBuild)
        if ok and type(adaptive) == "table" then
            local _, name
            for _, name in ipairs(adaptive.selectedNames or {}) do
                local key = Normalize(name)
                if key ~= "" and not talents[key] then
                    local entry = { name = name, rank = 1, source = "coa" }
                    talents[key] = entry
                    table.insert(talentList, entry)
                end
            end
        end
    end
end

local function SpellByAliases(list)
    local _, name
    for _, name in ipairs(list or {}) do
        local exact = spellbook[Normalize(name)]
        if exact and not exact.passive then return exact end
    end
    return nil
end

local function SpellFor(key)
    return SpellByAliases(ALIASES[key])
end

local function HasMarker(name)
    local key = Normalize(name)
    return spellbook[key] ~= nil or talents[key] ~= nil
end

local function SpecName(value)
    local key = Normalize(value)
    if string.find(key, "lightning", 1, true) or string.find(key, "foudre", 1, true) then return "Lightning" end
    if string.find(key, "maelstrom", 1, true) then return "Maelstrom" end
    if key == "wind" or key == "vent" or string.find(key, "wind", 1, true) then return "Wind" end
    return nil
end

local function DetectClassAndSpec()
    local className, classToken = UnitClass and UnitClass("player")
    local classKey = Normalize(tostring(className or "") .. tostring(classToken or ""))
    classActive = string.find(classKey, "stormbringer", 1, true) ~= nil
        or string.find(classKey, "portetempete", 1, true) ~= nil
    if not classActive then
        classActive = SpellFor("discharge") ~= nil and (SpellFor("shock") ~= nil or SpellFor("tempest") ~= nil)
    end
    playerLevel = UnitLevel and tonumber(UnitLevel("player")) or 0
    if not classActive then activeSpec = "Inactif"; specSource = "autre classe"; return end

    if type(C_ClassInfo) == "table" and type(C_ClassInfo.GetAllSpecs) == "function"
        and type(C_ClassInfo.GetSpecInfo) == "function" and type(GetSpecialization) == "function" then
        local activeOK, activeIndex = pcall(GetSpecialization)
        activeIndex = activeOK and tonumber(activeIndex) or nil
        local activeID = activeIndex
        local activeName = nil
        if activeIndex and type(GetSpecializationInfo) == "function" then
            local ok, infoID, infoName = pcall(GetSpecializationInfo, activeIndex)
            if ok and tonumber(infoID) and tonumber(infoID) ~= 0 then activeID = tonumber(infoID) end
            if ok and type(infoName) == "string" then activeName = infoName end
        end
        local catalogOK, catalog = pcall(C_ClassInfo.GetAllSpecs, classToken)
        if activeIndex and catalogOK and type(catalog) == "table" then
            local index, specKey
            for index, specKey in ipairs(catalog) do
                local ok, info = pcall(C_ClassInfo.GetSpecInfo, classToken, specKey)
                local id = ok and info and tonumber(info.ID) or nil
                local name = ok and info and info.Name or nil
                local matches = id and (id == activeID or id == activeIndex)
                    or tonumber(specKey) and (tonumber(specKey) == activeID or tonumber(specKey) == activeIndex)
                    or activeName and name and Normalize(activeName) == Normalize(name)
                    or not activeName and activeID == activeIndex and index == activeIndex
                local resolved = matches and SpecName(name or activeName)
                if resolved then activeSpec = resolved; specSource = "catalogue CoA actif"; return end
            end
        end
    end

    local scores = { Lightning = 0, Maelstrom = 0, Wind = 0 }
    local spec, markers, _, marker
    for spec, markers in pairs(SPEC_MARKERS) do
        for _, marker in ipairs(markers) do if HasMarker(marker) then scores[spec] = scores[spec] + 1 end end
    end
    local best, bestScore = nil, 0
    for spec, _ in pairs(scores) do if scores[spec] > bestScore then best, bestScore = spec, scores[spec] end end
    if best then activeSpec = best; specSource = "talents et spellbook"
    elseif playerLevel < 10 then activeSpec = "Initiation"; specSource = "niveau 1-9"
    else activeSpec = "Initiation"; specSource = "spécialisation non encore visible" end
end

local function UnitAuraByAliases(unit, aliases, harmful)
    if not UnitExists or not UnitExists(unit) then return nil end
    local wanted = {}
    local _, value
    for _, value in ipairs(aliases or {}) do wanted[Normalize(value)] = true end
    local getter = harmful and UnitDebuff or UnitBuff
    if not getter then return nil end
    local index
    for index = 1, 40 do
        local name, rank, texture, count, debuffType, duration, expirationTime, unitCaster = getter(unit, index)
        if not name then break end
        if wanted[Normalize(name)] then
            return { name = name, rank = rank, texture = texture, count = tonumber(count) or 0,
                debuffType = debuffType, duration = tonumber(duration) or 0, expiration = tonumber(expirationTime) or 0,
                caster = unitCaster }
        end
    end
    return nil
end

local function AnyAura(unit, aliases, harmful)
    return UnitAuraByAliases(unit, aliases, harmful)
end

local function DetectProc()
    local rules = PROC_RULES[activeSpec] or {}
    local _, rule
    for _, rule in ipairs(rules) do
        local aura = AnyAura("player", rule.auras, false)
        if aura then return { action = rule.action, text = rule.text, aura = aura } end
    end
    return nil
end

local function IsTargetValid()
    if not UnitExists or not UnitExists("target") then return false end
    if UnitIsDead and UnitIsDead("target") then return false end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return false end
    return true
end

local function TargetHealthPercent()
    if not IsTargetValid() or not UnitHealth or not UnitHealthMax then return 100 end
    local maximum = tonumber(UnitHealthMax("target")) or 0
    if maximum <= 0 then return 100 end
    return (tonumber(UnitHealth("target")) or maximum) * 100 / maximum
end

local function TargetIsDurable()
    if not IsTargetValid() then return false end
    local classification = UnitClassification and UnitClassification("target") or "normal"
    return classification == "elite" or classification == "rareelite" or classification == "worldboss"
        or TargetHealthPercent() >= 80
end

local function PruneCombatActors()
    local now = GetTime()
    local guid, seen
    for guid, seen in pairs(activeEnemies) do if now - (tonumber(seen) or 0) > 8 then activeEnemies[guid] = nil end end
end

local function EnemyCount()
    PruneCombatActors()
    local count = 0
    for _ in pairs(activeEnemies) do count = count + 1 end
    if IsTargetValid() then
        local guid = UnitGUID and UnitGUID("target")
        if not guid or not activeEnemies[guid] then count = count + 1 end
    end
    return count
end

local function SummonCounts()
    local servant, orbs = 0, 0
    local now = GetTime()
    local guid, info
    for guid, info in pairs(ownedSummons) do
        if now - (info.seen or now) > 900 then ownedSummons[guid] = nil
        else
            local key = Normalize(info.name)
            if string.find(key, "airelemental", 1, true) or string.find(key, "windservant", 1, true) then servant = servant + 1 end
            if string.find(key, "thunderorb", 1, true) then orbs = orbs + 1 end
        end
    end
    if UnitExists and UnitExists("pet") then
        local petName = Normalize(UnitName and UnitName("pet") or "")
        if string.find(petName, "elemental", 1, true) or string.find(petName, "servant", 1, true) then servant = max(servant, 1) end
    end
    if assumedServantUntil > now then servant = max(servant, 1) end
    if assumedOrbUntil > now then orbs = max(orbs, assumedOrbCount) end
    return servant, orbs
end

local function ConductiveStacks()
    local aura = AnyAura("target", { "Conductive", "Brine", "Wet", "Drenched" }, true)
    return aura and max(1, aura.count or 0) or 0, aura
end

local function ReadStatic()
    if UnitPower and UnitPowerMax then
        local _, powerType
        for _, powerType in ipairs({ 10, 6, 9, 8, 7 }) do
            local okMax, maximum = pcall(UnitPowerMax, "player", powerType)
            maximum = okMax and tonumber(maximum) or 0
            if maximum and maximum > 0 then
                local okCurrent, current = pcall(UnitPower, "player", powerType)
                current = okCurrent and tonumber(current) or 0
                return current, maximum, "API puissance " .. tostring(powerType)
            end
        end
    end
    local aura = AnyAura("player", { "Static", "Statique", "Static Charge" }, false)
    if aura and aura.count and aura.count > 0 then return aura.count, 100, "aura Static" end
    return nil, nil, "non exposée par le client"
end

local function SpellState(spell)
    local state = { ready = true, usable = true, noMana = false, inRange = nil, start = 0, duration = 0 }
    if GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spell.name)
        state.start = tonumber(start) or 0
        state.duration = tonumber(duration) or 0
        state.ready = enabled ~= 0 and (state.start == 0 or state.duration <= 1.5)
    end
    if IsUsableSpell then
        local usable, noMana = IsUsableSpell(spell.name)
        state.usable = usable and true or false
        state.noMana = noMana and true or false
    end
    if IsSpellInRange and IsTargetValid() then
        local inRange = IsSpellInRange(spell.name, "target")
        if inRange == 0 then state.inRange = false elseif inRange == 1 then state.inRange = true end
    end
    return state
end

local function ActionKeybind(spellName)
    if not GetActionInfo then return "" end
    local slot
    for slot = 1, 120 do
        local kind, id = GetActionInfo(slot)
        local name = nil
        if kind == "spell" and id and GetSpellInfo then name = GetSpellInfo(id)
        elseif kind == "macro" and id and GetMacroSpell then
            local macroSpell = GetMacroSpell(id)
            if type(macroSpell) == "number" and GetSpellInfo then name = GetSpellInfo(macroSpell)
            elseif type(macroSpell) == "string" then name = macroSpell end
        end
        if name and Normalize(name) == Normalize(spellName) then
            local command
            if slot <= 12 then command = "ACTIONBUTTON" .. slot
            elseif slot <= 24 then command = "MULTIACTIONBAR1BUTTON" .. (slot - 12)
            elseif slot <= 36 then command = "MULTIACTIONBAR2BUTTON" .. (slot - 24)
            elseif slot <= 48 then command = "MULTIACTIONBAR3BUTTON" .. (slot - 36)
            elseif slot <= 60 then command = "MULTIACTIONBAR4BUTTON" .. (slot - 48) end
            if command and GetBindingKey then
                local key = GetBindingKey(command)
                if key then return string.gsub(string.gsub(key, "CTRL%-", "C-"), "SHIFT%-", "S-") end
            end
        end
    end
    return ""
end

local function EvaluateRule(rule, context)
    local spell = SpellFor(rule.key)
    local candidate = { rule = rule, spell = spell, score = rule.score or 0, rejected = {}, reason = rule.reason }
    if not spell then table.insert(candidate.rejected, "sort non appris"); return candidate end
    if not context.target then table.insert(candidate.rejected, "aucune cible hostile") end
    if rule.minEnemies and context.enemies < rule.minEnemies then table.insert(candidate.rejected, "pas assez de cibles") end
    if rule.maxTargetHealth and context.targetHealth > rule.maxTargetHealth then table.insert(candidate.rejected, "cible trop haute en vie") end
    if rule.elite and not context.durable then table.insert(candidate.rejected, "cible trop courte") end
    if rule.burst and (not db.showBurst or not context.durable or not context.combat) then table.insert(candidate.rejected, "burst conservé") end
    if rule.minStatic then
        if context.static == nil then candidate.score = candidate.score - 900
        elseif context.static < rule.minStatic then table.insert(candidate.rejected, "Static insuffisante") end
    end
    if rule.maxStatic and context.static and context.static > rule.maxStatic then table.insert(candidate.rejected, "garde la Static pour le finisher") end
    if rule.minConductive and context.conductive < rule.minConductive then table.insert(candidate.rejected, "Conductive insuffisant") end
    if rule.minOrbs and context.orbs < rule.minOrbs then table.insert(candidate.rejected, "pas assez de Thunder Orbs") end
    if rule.maxOrbs and context.orbs > rule.maxOrbs then table.insert(candidate.rejected, "assez d'orbes déjà actives") end
    if rule.servantRequired and context.servant < 1 then table.insert(candidate.rejected, "Air Elemental absent") end
    if rule.servantMissing and context.servant > 0 then table.insert(candidate.rejected, "Air Elemental déjà actif") end
    if rule.debuffMissing and AnyAura("target", rule.debuffMissing, true) then table.insert(candidate.rejected, "effet déjà présent") end
    candidate.state = SpellState(spell)
    if not candidate.state.ready then table.insert(candidate.rejected, "recharge") end
    if not candidate.state.usable then table.insert(candidate.rejected, candidate.state.noMana and "mana/ressource insuffisante" or "inutilisable") end
    if candidate.state.inRange == false then table.insert(candidate.rejected, "hors de portée") end
    if currentProc and currentProc.action == rule.key then
        candidate.score = candidate.score + 2200
        candidate.reason = currentProc.text .. " : profite du proc maintenant."
    end
    candidate.available = #candidate.rejected == 0
    return candidate
end

local function BuildDecision()
    local static, staticMax, staticSource = ReadStatic()
    local servant, orbs = SummonCounts()
    local conductive = ConductiveStacks()
    local enemies = EnemyCount()
    local context = {
        target = IsTargetValid(), combat = UnitAffectingCombat and UnitAffectingCombat("player") or false,
        targetHealth = TargetHealthPercent(), durable = TargetIsDurable(), enemies = enemies,
        static = static, staticMax = staticMax, staticSource = staticSource,
        servant = servant, orbs = orbs, conductive = conductive
    }
    currentProc = DetectProc()
    local candidates = {}
    local rejected = {}
    local rules = RULES[activeSpec] or RULES.Initiation
    local _, rule
    for _, rule in ipairs(rules) do
        local candidate = EvaluateRule(rule, context)
        if candidate.available then table.insert(candidates, candidate) else table.insert(rejected, candidate) end
    end
    table.sort(candidates, function(a, b)
        if a.score == b.score then return tostring(a.spell.name) < tostring(b.spell.name) end
        return a.score > b.score
    end)
    currentAction = candidates[1]
    if not context.target and not currentProc then currentAction = nil end
    lastDecision = { context = context, candidates = candidates, rejected = rejected, proc = currentProc }
end

local function ShowToast(titleValue, textValue, seconds)
    if not toast then return end
    toastTitle:SetText(titleValue or "Stormbringer")
    toastText:SetText(textValue or "")
    toastUntil = GetTime() + (seconds or 7)
    toast:Show()
end

local function UpdateSearchText(item)
    local parts = { item.title or "", item.friendly or "", item.officialNote or "", item.kind or "" }
    local _, tag
    for _, tag in ipairs(type(item.tags) == "table" and item.tags or {}) do table.insert(parts, tag) end
    return lower(table.concat(parts, " "))
end

local function PromptStormUpdates()
    if not classActive or type(CoARotationUpdateFeed) ~= "table" or type(CoARotationUpdateFeed.items) ~= "table" then return end
    local _, item
    for _, item in ipairs(CoARotationUpdateFeed.items) do
        local identity = tostring(item.id or item.updatedAt or item.title or "update")
        local text = UpdateSearchText(item)
        local relevant = string.find(text, "stormbringer", 1, true) ~= nil
            or string.find(text, lower(activeSpec), 1, true) ~= nil
        if not relevant then
            local _, spell
            for _, spell in ipairs(spellList) do
                local name = lower(tostring(spell.name or ""))
                if string.len(name) >= 5 and string.find(text, name, 1, true) then relevant = true; break end
            end
        end
        if relevant and not db.updateSeen[identity] then
            db.updateSeen[identity] = true
            local message = tostring(item.friendly or item.officialNote or "Une note officielle Ascension concerne Stormbringer.")
            ShowToast("MISE À JOUR ASCENSION", message, 12)
            Chat("une nouvelle note Ascension peut concerner " .. activeSpec .. ". Ouvre le Manager pour les détails avant de changer tes habitudes.")
            if CoAMessageCenter and type(CoAMessageCenter.AddMessage) == "function" then
                CoAMessageCenter:AddMessage("Stormbringer Helper", message, "warning")
            end
            return
        end
    end
end

local function ImportantAction(action)
    if not action then return false end
    return currentProc and currentProc.action == action.rule.key or action.rule.burst or action.score >= 900
end

local function NotifyAction(action)
    if not action or not action.spell then return end
    local key = Normalize(action.spell.name) .. ":" .. tostring(currentProc and currentProc.text or "")
    if key == lastActionKey then return end
    lastActionKey = key
    if ImportantAction(action) and db.sound and GetTime() - lastSoundAt > 2.5 then
        lastSoundAt = GetTime()
        if PlaySound then pcall(PlaySound, "RaidWarning") end
    end
end

local function PositionHUD()
    if not hud then return end
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -115)
    hud:SetScale(Clamp(db.scale, 0.65, 1.8))
end

local function PositionMinimapButton()
    if not minimapButton or not Minimap then return end
    local radius = 80
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(db.buttonAngle or 3.65) * radius, math.sin(db.buttonAngle or 3.65) * radius)
end

local function UpdateMinimapVisibility()
    if not minimapButton then return end
    if hubManaged or db.buttonHidden or not classActive then minimapButton:Hide() else minimapButton:Show() end
end

local function UpdateHUD()
    if not hud then return end
    local now = GetTime()
    local action = currentAction
    if testUntil > now and not action then
        local testSpell = SpellFor("shock") or SpellFor("discharge") or spellList[1]
        if testSpell then action = { spell = testSpell, rule = { key = "test" }, score = 999, reason = "Test visuel : l'addon ne lance rien." , state = SpellState(testSpell) } end
    end
    local visible = db.enabled and classActive and (action ~= nil or not db.locked or testUntil > now)
    if not visible then hud:Hide(); return end
    hud:Show()
    if action and action.spell then
        icon:SetTexture(action.spell.texture or "Interface/Icons/Spell_Nature_Lightning")
        local state = action.state or SpellState(action.spell)
        if cooldown and cooldown.SetCooldown then cooldown:SetCooldown(state.start or 0, state.duration or 0) end
        if state.usable and state.ready then icon:SetVertexColor(1, 1, 1, 1) else icon:SetVertexColor(0.45, 0.45, 0.45, 0.7) end
        if ImportantAction(action) or state.usable and state.ready then glow:Show() else glow:Hide() end
        keyText:SetText(ActionKeybind(action.spell.name))
        actionText:SetText(action.spell.name)
        reasonText:SetText(action.reason or "")
        NotifyAction(action)
    else
        icon:SetTexture("Interface/Icons/Spell_Nature_Lightning")
        icon:SetVertexColor(0.5, 0.7, 0.9, 0.8)
        glow:Hide(); keyText:SetText(""); actionText:SetText("Déplacer le HUD"); reasonText:SetText("Aucun sort n'est lancé automatiquement.")
    end
    local context = lastDecision and lastDecision.context or {}
    local staticLabel = context.static ~= nil and (tostring(floor(context.static + 0.5)) .. " Static") or "Static ?"
    local procLabel = currentProc and ("  •  " .. currentProc.text) or ""
    metaText:SetText(activeSpec .. "  •  niv. " .. tostring(playerLevel) .. "  •  " .. staticLabel .. procLabel)
    if context.static ~= nil and context.staticMax and context.staticMax > 0 then
        staticFill:SetWidth(max(1, 86 * context.static / context.staticMax))
        staticFill:SetVertexColor(context.static / context.staticMax >= 0.75 and 0.98 or 0.24, 0.72, 1.00, 0.95)
    else staticFill:SetWidth(1); staticFill:SetVertexColor(0.30, 0.45, 0.55, 0.7) end
    if db.showText then actionText:Show(); metaText:Show(); reasonText:Show(); hud:SetWidth(280)
    else actionText:Hide(); metaText:Hide(); reasonText:Hide(); hud:SetWidth(104) end
    if not db.locked then editOverlay:Show(); hud:EnableMouse(true) else editOverlay:Hide(); hud:EnableMouse(true) end
end

local function UpdateMenu()
    if not menu then return end
    local context = lastDecision and lastDecision.context or {}
    local staticText = context.static ~= nil and (tostring(floor(context.static + 0.5)) .. "/" .. tostring(context.staticMax or "?")) or "non exposée"
    menuStatus:SetText("Stormbringer • niveau " .. tostring(playerLevel or "?") .. " • " .. tostring(activeSpec)
        .. "\nDétection : " .. tostring(specSource) .. " • " .. tostring(#spellList) .. " sorts • " .. tostring(#talentList) .. " talents")
    local action = currentAction and currentAction.spell and currentAction.spell.name or "aucune action urgente"
    local reason = currentAction and currentAction.reason or "Le HUD se cache quand il n'y a rien d'utile à signaler."
    menuDetail:SetText("Conseil : " .. tostring(action) .. "\n" .. tostring(reason)
        .. "\nStatic : " .. staticText .. " (" .. tostring(context.staticSource or "?") .. ")"
        .. " • ennemis : " .. tostring(context.enemies or 0) .. " • Conductive : " .. tostring(context.conductive or 0)
        .. " • orbes : " .. tostring(context.orbs or 0) .. "\nSources recoupées le " .. SOURCE_DATE .. ". Recommandations uniquement.")
end

local function FullScan(reason, announce)
    local oldNames = {}
    local _, spell
    for _, spell in ipairs(spellList) do oldNames[Normalize(spell.name)] = true end
    ScanSpellbook()
    ScanTalents()
    DetectClassAndSpec()
    local newNames = {}
    for _, spell in ipairs(spellList) do if not oldNames[Normalize(spell.name)] then table.insert(newNames, spell.name) end end
    local character = db.characters[CharacterKey()] or {}
    local oldLevel = tonumber(character.level) or 0
    local oldSpec = character.spec
    character.level = playerLevel
    character.spec = activeSpec
    character.spellCount = #spellList
    character.updatedAt = time and time() or 0
    db.characters[CharacterKey()] = character
    if classActive and announce then
        if oldLevel > 0 and playerLevel > oldLevel then
            local message = "Niveau " .. tostring(playerLevel) .. " détecté. Le HUD a rescanné tes sorts et tes talents."
            if playerLevel == 10 then message = message .. " Choisis Lightning, Maelstrom ou Wind : l'addon basculera automatiquement." end
            ShowToast("NOUVEAU NIVEAU", message, 9)
        elseif oldSpec and oldSpec ~= activeSpec then
            ShowToast("SPÉCIALISATION DÉTECTÉE", tostring(activeSpec) .. " est maintenant active. Les priorités viennent d'être remplacées.", 9)
        elseif #newNames > 0 and oldLevel > 0 then
            ShowToast("NOUVEAU SORT", table.concat(newNames, ", ") .. "\nLa priorité a été recalculée.", 8)
        end
    end
    BuildDecision(); UpdateHUD(); UpdateMenu(); UpdateMinimapVisibility(); PromptStormUpdates()
    if announce and classActive then Chat("scan " .. tostring(reason or "manuel") .. " : niveau " .. tostring(playerLevel) .. ", " .. activeSpec .. ", " .. tostring(#spellList) .. " sorts.") end
end

local function MakeButton(parent, text, x, y, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 132); button:SetHeight(22); button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); button:SetText(text)
    return button
end

hud = CreateFrame("Frame", "CoAStormbringerHUD", UIParent)
hud:SetWidth(280); hud:SetHeight(112); hud:SetFrameStrata("HIGH"); hud:SetMovable(true); hud:SetClampedToScreen(true)
hud:RegisterForDrag("LeftButton"); hud:EnableMouse(true)
hud:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
hud:SetBackdropColor(0.012, 0.035, 0.065, 0.94); hud:SetBackdropBorderColor(0.20, 0.75, 1.00, 0.95)
hud:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter(); local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then db.x = cx - ux; db.y = cy - uy end
end)
hud:SetScript("OnMouseUp", function(_, button) if button == "RightButton" and menu then if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end end end)
hud:Hide()

local iconFrame = CreateFrame("Frame", nil, hud)
iconFrame:SetWidth(68); iconFrame:SetHeight(68); iconFrame:SetPoint("LEFT", hud, "LEFT", 11, 6)
iconFrame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Buttons/UI-Quickslot2", edgeSize = 11 })
iconFrame:SetBackdropColor(0.01, 0.02, 0.04, 0.9)
icon = iconFrame:CreateTexture(nil, "ARTWORK"); icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 6, -6); icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -6, 6)
cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate"); cooldown:SetAllPoints(icon)
glow = iconFrame:CreateTexture(nil, "OVERLAY"); glow:SetTexture("Interface/Buttons/UI-ActionButton-Border"); glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", iconFrame, "CENTER", 0, 0); glow:SetWidth(92); glow:SetHeight(92); glow:SetVertexColor(0.15, 0.85, 1.00, 1); glow:Hide()
keyText = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); keyText:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", -5, -4); keyText:SetTextColor(1, 0.88, 0.35)

actionText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal"); actionText:SetPoint("TOPLEFT", hud, "TOPLEFT", 88, -15); actionText:SetWidth(180); actionText:SetJustifyH("LEFT"); actionText:SetTextColor(0.45, 0.90, 1.00)
metaText = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); metaText:SetPoint("TOPLEFT", actionText, "BOTTOMLEFT", 0, -5); metaText:SetWidth(180); metaText:SetJustifyH("LEFT")
reasonText = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); reasonText:SetPoint("TOPLEFT", metaText, "BOTTOMLEFT", 0, -6); reasonText:SetWidth(180); reasonText:SetJustifyH("LEFT"); reasonText:SetHeight(34)
staticBar = CreateFrame("Frame", nil, hud); staticBar:SetWidth(88); staticBar:SetHeight(7); staticBar:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 7, 7)
staticBar:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8" }); staticBar:SetBackdropColor(0.04, 0.10, 0.16, 0.9)
staticFill = staticBar:CreateTexture(nil, "ARTWORK"); staticFill:SetTexture("Interface/Buttons/WHITE8X8"); staticFill:SetPoint("LEFT", staticBar, "LEFT", 1, 0); staticFill:SetWidth(1); staticFill:SetHeight(5)
editOverlay = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); editOverlay:SetPoint("TOP", hud, "TOP", 0, 16); editOverlay:SetText("STORMBRINGER • GLISSER POUR DÉPLACER"); editOverlay:SetTextColor(0.35, 0.9, 1)

hud:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("CoA Stormbringer Helper " .. VERSION, 0.35, 0.88, 1)
    if currentAction and currentAction.spell then
        GameTooltip:AddDoubleLine("Prochain conseil", currentAction.spell.name, 1, 1, 1, 0.35, 1, 0.75)
        GameTooltip:AddLine(currentAction.reason or "", 0.85, 0.85, 0.85, true)
    else GameTooltip:AddLine("Aucune action urgente.", 0.65, 0.75, 0.82) end
    if currentProc then GameTooltip:AddDoubleLine("Proc", currentProc.text, 1, 1, 1, 1, 0.75, 0.2) end
    GameTooltip:AddLine("Clic droit : réglages", 0.55, 0.75, 0.9)
    GameTooltip:Show()
end)
hud:SetScript("OnLeave", function() GameTooltip:Hide() end)

toast = CreateFrame("Frame", "CoAStormbringerLevelToast", UIParent)
toast:SetWidth(430); toast:SetHeight(82); toast:SetPoint("TOP", UIParent, "TOP", 0, -115); toast:SetFrameStrata("DIALOG")
toast:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12 })
toast:SetBackdropColor(0.02, 0.05, 0.09, 0.97); toast:SetBackdropBorderColor(0.20, 0.78, 1.00, 0.95)
toastTitle = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); toastTitle:SetPoint("TOP", toast, "TOP", 0, -12); toastTitle:SetTextColor(0.35, 0.9, 1)
toastText = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); toastText:SetPoint("TOP", toastTitle, "BOTTOM", 0, -8); toastText:SetWidth(390); toastText:SetJustifyH("CENTER")
toast:Hide()

menu = CreateFrame("Frame", "CoAStormbringerMenu", UIParent)
menu:SetWidth(340); menu:SetHeight(330); menu:SetPoint("CENTER", UIParent, "CENTER", 260, 25); menu:SetFrameStrata("DIALOG"); menu:SetMovable(true); menu:EnableMouse(true); menu:RegisterForDrag("LeftButton")
menu:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12 })
menu:SetBackdropColor(0.018, 0.035, 0.065, 0.985); menu:SetBackdropBorderColor(0.20, 0.75, 1.00, 0.95)
menu:SetScript("OnDragStart", function(self) self:StartMoving() end); menu:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end); menu:Hide()
local menuTitle = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); menuTitle:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -15); menuTitle:SetText("STORMBRINGER • ASSISTANT"); menuTitle:SetTextColor(0.35, 0.9, 1)
local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -3)
menuStatus = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); menuStatus:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -48); menuStatus:SetWidth(306); menuStatus:SetJustifyH("LEFT")
menuDetail = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); menuDetail:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -88); menuDetail:SetWidth(306); menuDetail:SetHeight(82); menuDetail:SetJustifyH("LEFT"); menuDetail:SetJustifyV("TOP")

local bTest = MakeButton(menu, "TEST 8 S", 16, -182, 146)
local bLock = MakeButton(menu, "DÉVERROUILLER", 174, -182, 150)
local bSound = MakeButton(menu, "SON : ON", 16, -210, 146)
local bText = MakeButton(menu, "TEXTE : ON", 174, -210, 150)
local bBurst = MakeButton(menu, "BURST : ON", 16, -238, 146)
local bMinimap = MakeButton(menu, "BOUTON : ON", 174, -238, 150)
local bScan = MakeButton(menu, "RESCANNER", 16, -266, 146)
local bReset = MakeButton(menu, "RESET", 174, -266, 150)
local sourceLine = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sourceLine:SetPoint("BOTTOM", menu, "BOTTOM", 0, 14); sourceLine:SetText("CoA Build Hub • Ascension • coa-datamine • spellbook réel")

minimapButton = CreateFrame("Button", "CoAStormbringerMinimapButton", Minimap)
minimapButton:SetWidth(32); minimapButton:SetHeight(32); minimapButton:SetFrameStrata("MEDIUM"); minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp"); minimapButton:RegisterForDrag("LeftButton")
local miniIcon = minimapButton:CreateTexture(nil, "BACKGROUND"); miniIcon:SetTexture("Interface/Icons/Spell_Nature_Lightning"); miniIcon:SetWidth(20); miniIcon:SetHeight(20); miniIcon:SetPoint("CENTER", 0, 0); miniIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local miniBorder = minimapButton:CreateTexture(nil, "OVERLAY"); miniBorder:SetTexture("Interface/Minimap/MiniMap-TrackingBorder"); miniBorder:SetWidth(52); miniBorder:SetHeight(52); miniBorder:SetPoint("TOPLEFT", 0, 0)
minimapButton:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then db.locked = not db.locked; UpdateHUD(); UpdateMenu()
    else if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end end
end)
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine("Stormbringer Helper", 0.35, 0.9, 1); GameTooltip:AddLine("Clic : réglages • clic droit : verrouiller", 1, 1, 1); GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(button)
        if not Minimap then return end
        local mx, my = Minimap:GetCenter(); local px, py = GetCursorPosition(); local scale = UIParent:GetEffectiveScale()
        px, py = px / scale, py / scale
        db.buttonAngle = math.atan2(py - my, px - mx)
        PositionMinimapButton()
    end)
end)
minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil); PositionMinimapButton() end)

local function HandleCommand(message)
    EnsureDB()
    local command, value = string.match(tostring(message or ""), "^(%S*)%s*(.-)%s*$")
    command = Normalize(command)
    if command == "" then if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end
    elseif command == "status" then
        local context = lastDecision and lastDecision.context or {}
        Chat("niveau=" .. tostring(playerLevel) .. " spec=" .. activeSpec .. " source=" .. specSource .. " sorts=" .. tostring(#spellList)
            .. " talents=" .. tostring(#talentList) .. " Static=" .. tostring(context.static or "?") .. " ennemis=" .. tostring(context.enemies or 0))
    elseif command == "scan" then FullScan("manuel", true)
    elseif command == "unlock" then db.locked = false; UpdateHUD(); Chat("HUD déverrouillé : glisse-le avec la souris.")
    elseif command == "lock" then db.locked = true; UpdateHUD(); Chat("HUD verrouillé.")
    elseif command == "test" then testUntil = GetTime() + 8; ShowToast("TEST STORMBRINGER", "Icône, cooldown, glow et alerte de niveau. Aucun sort ne sera lancé.", 8); UpdateHUD()
    elseif command == "sound" then db.sound = not db.sound; Chat("son des procs " .. (db.sound and "activé" or "coupé") .. ".")
    elseif command == "text" then db.showText = not db.showText; UpdateHUD()
    elseif command == "burst" then db.showBurst = not db.showBurst; BuildDecision(); UpdateHUD()
    elseif command == "minimap" or command == "button" then db.buttonHidden = not db.buttonHidden; UpdateMinimapVisibility()
    elseif command == "scale" then db.scale = Clamp(tonumber(value), 0.65, 1.8); PositionHUD()
    elseif command == "debug" then
        if currentAction then Chat("conseil=" .. currentAction.spell.name .. " score=" .. tostring(currentAction.score) .. " raison=" .. tostring(currentAction.reason))
        else Chat("aucune action. Vérifie la cible, la portée, le cooldown et la ressource avec /storm status.") end
        local rejected = lastDecision and lastDecision.rejected or {}
        local index
        for index = 1, min(5, #rejected) do Chat("rejet " .. tostring(rejected[index].spell and rejected[index].spell.name or rejected[index].rule.key) .. " : " .. table.concat(rejected[index].rejected, ", ")) end
    elseif command == "reset" then
        db.x = 0; db.y = -115; db.scale = 1.0; db.locked = true; db.sound = true; db.showText = true; db.showBurst = true; db.buttonHidden = false; db.buttonAngle = 3.65
        PositionHUD(); PositionMinimapButton(); UpdateMinimapVisibility(); Chat("réglages Stormbringer réinitialisés.")
    else Chat("/storm status | scan | unlock | lock | test | sound | text | burst | minimap | scale 1 | debug | reset") end
    UpdateMenu()
end

bTest:SetScript("OnClick", function() HandleCommand("test") end)
bLock:SetScript("OnClick", function() HandleCommand(db.locked and "unlock" or "lock") end)
bSound:SetScript("OnClick", function() HandleCommand("sound") end)
bText:SetScript("OnClick", function() HandleCommand("text") end)
bBurst:SetScript("OnClick", function() HandleCommand("burst") end)
bMinimap:SetScript("OnClick", function() HandleCommand("minimap") end)
bScan:SetScript("OnClick", function() HandleCommand("scan") end)
bReset:SetScript("OnClick", function() HandleCommand("reset") end)
menu:SetScript("OnShow", function()
    UpdateMenu()
    bLock:SetText(db.locked and "DÉVERROUILLER" or "VERROUILLER")
    bSound:SetText("SON : " .. (db.sound and "ON" or "OFF")); bText:SetText("TEXTE : " .. (db.showText and "ON" or "OFF"))
    bBurst:SetText("BURST : " .. (db.showBurst and "ON" or "OFF")); bMinimap:SetText("BOUTON : " .. (db.buttonHidden and "OFF" or "ON"))
end)

CoAStormbringerHelperAPI = CoAStormbringerHelperAPI or {}
function CoAStormbringerHelperAPI:Toggle() if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end end
function CoAStormbringerHelperAPI:Show() menu:Show(); UpdateMenu() end
function CoAStormbringerHelperAPI:SetHubManaged(value) hubManaged = value and true or false; UpdateMinimapVisibility() end
function CoAStormbringerHelperAPI:Refresh() FullScan("API", true) end
function CoAStormbringerHelperAPI:GetStatus()
    return { active = classActive, level = playerLevel, spec = activeSpec, source = specSource,
        spellCount = #spellList, talentCount = #talentList, action = currentAction and currentAction.spell.name or nil }
end

SLASH_COASTORMBRINGER1 = "/storm"
SLASH_COASTORMBRINGER2 = "/sbh"
SlashCmdList.COASTORMBRINGER = HandleCommand

local function IsOwnedGUID(guid, flags)
    if not guid then return false end
    if guid == playerGUID or ownedSummons[guid] then return true end
    if bit and bit.band and flags and COMBATLOG_OBJECT_AFFILIATION_MINE then
        return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
    end
    return false
end

local function HandleCombatLog(...)
    local _, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName = ...
    local now = GetTime()
    local sourceOwned = IsOwnedGUID(sourceGUID, sourceFlags)
    if eventType == "SPELL_SUMMON" and sourceOwned and destGUID then
        ownedSummons[destGUID] = { name = destName or spellName or "invocation", seen = now }
    elseif eventType == "UNIT_DIED" or eventType == "UNIT_DESTROYED" then
        if destGUID then ownedSummons[destGUID] = nil; activeEnemies[destGUID] = nil end
    end
    if sourceOwned and destGUID and not IsOwnedGUID(destGUID, destFlags) then
        if string.find(tostring(eventType), "DAMAGE", 1, true) or eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_CAST_SUCCESS" then activeEnemies[destGUID] = now end
    elseif IsOwnedGUID(destGUID, destFlags) and sourceGUID and not sourceOwned then
        if string.find(tostring(eventType), "DAMAGE", 1, true) or eventType == "SPELL_AURA_APPLIED" then activeEnemies[sourceGUID] = now end
    end
    if sourceOwned and eventType == "SPELL_CAST_SUCCESS" and spellName then
        local key = Normalize(spellName)
        local _, alias
        for _, alias in ipairs(ALIASES.summonAir) do if key == Normalize(alias) then assumedServantUntil = now + 180 end end
        for _, alias in ipairs(ALIASES.summonOrb) do
            if key == Normalize(alias) then assumedOrbCount = min(3, assumedOrbCount + 1); assumedOrbUntil = now + 90 end
        end
        if SpellFor("orbDetonation") and key == Normalize(SpellFor("orbDetonation").name) then assumedOrbCount = 0; assumedOrbUntil = 0 end
    end
end

local events = CreateFrame("Frame")
local eventNames = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
    "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "UNIT_POWER", "UNIT_MANA",
    "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN", "COMBAT_LOG_EVENT_UNFILTERED"
}
local _, eventName
for _, eventName in ipairs(eventNames) do pcall(events.RegisterEvent, events, eventName) end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName and loaded ~= "CoAStormbringerHelper" then return end
        EnsureDB(); playerGUID = UnitGUID and UnitGUID("player") or nil; PositionHUD(); PositionMinimapButton(); FullScan("chargement", false)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID and UnitGUID("player") or playerGUID; scanPendingAt = GetTime() + 1.0
    elseif event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        scanPendingAt = GetTime() + 0.65
    elseif event == "PLAYER_REGEN_DISABLED" then
        lastCombatAt = GetTime(); if IsTargetValid() and UnitGUID then activeEnemies[UnitGUID("target") or "target"] = GetTime() end
    elseif event == "PLAYER_REGEN_ENABLED" then activeEnemies = {}
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then HandleCombatLog(...)
    end
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then BuildDecision(); UpdateHUD(); UpdateMenu() end
end)

events:SetScript("OnUpdate", function(_, elapsed)
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < 0.12 then return end
    refreshElapsed = 0
    if scanPendingAt > 0 and GetTime() >= scanPendingAt then scanPendingAt = 0; FullScan("évolution détectée automatiquement", true) end
    BuildDecision(); UpdateHUD()
    if toast and toast:IsShown() and GetTime() >= toastUntil then toast:Hide() end
end)
