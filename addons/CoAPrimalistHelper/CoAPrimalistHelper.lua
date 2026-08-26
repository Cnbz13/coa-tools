local addonName = ...

-- CoA Primalist Helper 1.0.0
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
local spellbook, spellList, talents, talentList = {}, {}, {}, {}
local playerLevel, playerGUID = 0, nil
local activeSpec, specSource = "Initiation", "niveau 1-9"
local classActive, currentAction, currentProc, lastDecision = false, nil, nil, nil
local lastActionKey, lastSoundAt, scanPendingAt, refreshElapsed = nil, 0, 0, 0
local testUntil, toastUntil, hubManaged, assumedPetUntil = 0, 0, false, 0
local activeEnemies, ownedSummons = {}, {}

local hud, icon, cooldown, glow, keyText, actionText, metaText, reasonText, rageBar, rageFill, editOverlay
local menu, menuStatus, menuDetail, minimapButton, toast, toastTitle, toastText
local scannerTooltip = CreateFrame("GameTooltip", "CoAPrimalistScannerTooltip", UIParent, "GameTooltipTemplate")
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
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff83df73Primalist Helper:|r " .. tostring(message)) end
end

local function CharacterKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return tostring(realm) .. "-" .. tostring(name)
end

local function EnsureDB()
    CoAPrimalistHelperDB = CoAPrimalistHelperDB or {}
    db = CoAPrimalistHelperDB
    if db.enabled == nil then db.enabled = true end
    if db.locked == nil then db.locked = true end
    if db.sound == nil then db.sound = true end
    if db.showText == nil then db.showText = true end
    if db.showBurst == nil then db.showBurst = true end
    if db.buttonHidden == nil then db.buttonHidden = false end
    if type(db.scale) ~= "number" then db.scale = 1.0 end
    if type(db.x) ~= "number" then db.x = 0 end
    if type(db.y) ~= "number" then db.y = -115 end
    if type(db.buttonAngle) ~= "number" then db.buttonAngle = 3.25 end
    if type(db.characters) ~= "table" then db.characters = {} end
    if type(db.updateSeen) ~= "table" then db.updateSeen = {} end
end

local ALIASES = {
    wildclaw = { "Wildclaw", "Bearclaw" },
    handEarthmother = { "Hand of the Earthmother", "Wildmend" },
    primalRush = { "Primal Rush", "Primal Charge" },
    callPet = { "Call Pet", "Call Spirit Beast", "Revive Pet" },
    primalShred = { "Primal Shred" },
    totemicSmash = { "Totemic Smash" },
    rylaksBite = { "Rylak's Bite", "Rylaks Bite", "Bear's Maw" },
    wildaxe = { "Wildaxe" },
    throatClamp = { "Throat Clamp" },
    frenziedRoar = { "Frenzied Roar" },
    savageFrenzy = { "Savage Frenzy" },
    seismicCrash = { "Seismic Crash", "Stonefall" },
    seismicSpike = { "Seismic Spike", "Earthspine" },
    seismicWave = { "Seismic Wave", "Primal Wave" },
    seismicSmash = { "Seismic Smash" },
    seismicTremor = { "Seismic Tremor" },
    earthquake = { "Earthquake" },
    geodeBarrage = { "Geode Barrage" },
    lithicLance = { "Lithic Lance" },
    terrasurge = { "Terrasurge", "Terra Surge" },
    stoneshard = { "Stoneshard", "Stone Shard" },
    volcanicBlast = { "Volcanic Blast" },
    magmaFissure = { "Magma Fissure" },
    earthsEmbrace = { "Earth's Embrace", "Earths Embrace" },
    golemForm = { "Golem Form", "Wildshape" },
    soothingTouch = { "Soothing Touch", "Neptulon's Grace" },
    spiritCharge = { "Spirit Charge", "Spirit Rush" },
    tearsEarthmother = { "Tears of the Earthmother" },
    wildmend = { "Wildmend" },
    sacredGrove = { "Sacred Grove" },
    watersNeptulon = { "Waters of Neptulon" },
    ringLife = { "Ring of Life" },
    earthBinding = { "Earthmother's Binding", "Earthmothers Binding" },
    flourishingGrowth = { "Flourishing Growth" },
    groveGuardian = { "Grove Guardian" },
    mountainFury = { "Mountain Fury" },
    quake = { "Quake" },
    mountainHammer = { "Mountain Hammer" },
    rockBarrier = { "Rock Barrier" },
    earthenAvatar = { "Earthen Avatar", "Mountain Avatar" },
    stoneslam = { "Stoneslam", "Stone Slam" },
    primalConvergence = { "Primal Convergence" }
}

local SPEC_MARKERS = {
    Wildwalker = { "Spirit Beast Master", "Primal Shred", "Totemic Smash", "Torn to Shreds", "Rylak's Bite", "Legacy of Rexxar" },
    Geomancy = { "Earthshaping", "Terrasurge", "Seismic Tremor", "Lithic Lance", "Golem Form", "Volcanic Blast" },
    Grovekeeper = { "Grove Training", "Seismic Wave", "Spirit Charge", "Hammer of Life", "Sacred Grove", "Grovekeeper's Presence" },
    ["Mountain King"] = { "Mountain Giant", "Quake", "Mountain Fury", "Mountain Hammer", "Earthen Avatar", "King of the Mountain" }
}

local PROC_RULES = {
    Wildwalker = {
        { auras = { "Tremors", "Aftershock" }, action = "seismicSpike", text = "Seismic gratuit" },
        { auras = { "Wild Rage" }, action = "rylaksBite", text = "Rylak sans coût" },
        { auras = { "Elemental Berserker", "Spiritual Frenzy" }, action = "totemicSmash", text = "fenêtre bestiale" }
    },
    Geomancy = {
        { auras = { "Lithic Lance", "Stone Tosser" }, action = "lithicLance", text = "Lithic Lance instantanée" },
        { auras = { "Aftershock", "Tremors" }, action = "earthquake", text = "Earthquake gratuite" },
        { auras = { "Embraced By Earth!", "Earth's Embrace" }, action = "terrasurge", text = "terre renforcée" },
        { auras = { "Magmatism" }, action = "volcanicBlast", text = "magma renforcé" }
    },
    Grovekeeper = {
        { auras = { "Aftershock", "Tremors" }, action = "seismicWave", text = "vague sismique disponible" },
        { auras = { "Infusion of Neptulon" }, action = "wildclaw", text = "attaques renforcées" },
        { auras = { "Battleweaver" }, action = "wildclaw", text = "Battleweaver actif" }
    },
    ["Mountain King"] = {
        { auras = { "Aftershock", "Tremors" }, action = "earthquake", text = "Earthquake gratuite" },
        { auras = { "Mighty Mountain", "Mountain's Might" }, action = "stoneslam", text = "Stoneslam renforcé" },
        { auras = { "Hammer Time!" }, action = "mountainHammer", text = "marteau renforcé" }
    }
}

local RULES = {
    Initiation = {
        { key = "wildclaw", score = 500, reason = "Ton attaque de base est prête." },
        { key = "seismicCrash", score = 420, reason = "Frappe la cible et génère de la Rage." },
        { key = "primalRush", score = 350, outOfRange = true, reason = "Referme la distance avec la cible." }
    },
    Wildwalker = {
        { key = "throatClamp", score = 1300, targetCasting = true, reason = "Interromps cette incantation dangereuse avec ton familier." },
        { key = "callPet", score = 1150, petMissing = true, reason = "Ton familier manque : rappelle-le avant de poursuivre." },
        { key = "primalShred", score = 980, minEnemies = 2, reason = "Ton familier peut déchirer plusieurs ennemis et propager ses saignements." },
        { key = "totemicSmash", score = 930, reason = "Dépense ta Rage dans ton impact principal et son cleave." },
        { key = "savageFrenzy", score = 840, burst = true, reason = "La cible vivra assez longtemps pour rentabiliser cette frénésie." },
        { key = "frenziedRoar", score = 780, maxRage = 35, combat = true, reason = "Relance ta génération de Rage et ton rythme d'attaque." },
        { key = "rylaksBite", score = 700, reason = "Utilise une charge pour rester au contact et nourrir la boucle du familier." },
        { key = "seismicSpike", score = 670, minEnemies = 3, reason = "Le pack est assez grand pour la version de zone du sort sismique." },
        { key = "wildaxe", score = 620, reason = "Cette frappe profite directement de ton familier actif." },
        { key = "wildclaw", score = 500, reason = "Continue Wildclaw pour alimenter les critiques et saignements." },
        { key = "seismicCrash", score = 430, reason = "Génère de la Rage pendant le retour de tes attaques principales." }
    },
    Geomancy = {
        { key = "golemForm", score = 1250, selfAction = true, maxPlayerHealth = 32, combat = true, reason = "Ta vie est dangereusement basse : utilise ta forme défensive." },
        { key = "lithicLance", score = 1150, procOnly = true, reason = "Ton proc rend Lithic Lance prioritaire immédiatement." },
        { key = "terrasurge", score = 1000, minEarthshaping = 5, minRage = 45, reason = "Tes charges d'Earthshaping et ta Rage rendent Terrasurge rentable." },
        { key = "stoneshard", score = 940, minRage = 80, reason = "Dépense la Rage avant de la plafonner." },
        { key = "seismicTremor", score = 900, debuffMissing = { "Seismic Tremor" }, reason = "Pose le tremblement : il entretient Earthshaping et prépare tes dépenses." },
        { key = "earthquake", score = 850, minEnemies = 3, procOnly = true, reason = "Profite du proc gratuit sur ce groupe." },
        { key = "magmaFissure", score = 800, minEnemies = 3, reason = "Installe la fissure sous ce groupe avant de reprendre le barrage." },
        { key = "seismicSpike", score = 760, minEnemies = 3, reason = "Génère de la Rage et maintiens la pression sur le pack." },
        { key = "volcanicBlast", score = 700, reason = "Ta frappe volcanique est disponible dans la fenêtre actuelle." },
        { key = "geodeBarrage", score = 580, reason = "Construis Earthshaping et la Rage avec ton barrage principal." },
        { key = "seismicCrash", score = 520, reason = "Utilise le sort sismique monocible pendant le retour du barrage." },
        { key = "wildclaw", score = 320, reason = "Reste actif pendant le retour de tes outils de géomancie." }
    },
    Grovekeeper = {
        { key = "soothingTouch", score = 1500, friendly = true, dispel = true, reason = "Retire ce poison ou cette maladie immédiatement." },
        { key = "sacredGrove", score = 1400, friendly = true, minLowAllies = 3, maxAllyHealth = 45, reason = "Plusieurs alliés sont en danger : stabilise tout le groupe." },
        { key = "spiritCharge", score = 1250, friendly = true, maxAllyHealth = 45, reason = "Rejoins et relève rapidement l'allié le plus bas." },
        { key = "earthBinding", score = 1180, friendly = true, maxAllyHealth = 38, reason = "Protège cet allié avant le prochain impact." },
        { key = "seismicWave", score = 1100, friendly = true, minLowAllies = 2, maxAllyHealth = 75, reason = "Plusieurs membres ont besoin du soin de zone maintenant." },
        { key = "watersNeptulon", score = 1040, friendly = true, minLowAllies = 3, maxAllyHealth = 82, reason = "Le groupe entier profite de cette vague de soins." },
        { key = "tearsEarthmother", score = 950, friendly = true, maxAllyHealth = 72, hotMissing = { "Tears of the Earthmother" }, reason = "Pose ton soin durable sur l'allié blessé." },
        { key = "handEarthmother", score = 900, friendly = true, maxAllyHealth = 68, hotMissing = { "Hand of the Earthmother", "Wildmend" }, reason = "Remonte l'allié prioritaire avec ton soin direct." },
        { key = "wildmend", score = 860, friendly = true, maxAllyHealth = 70, reason = "Complète les soins sur l'allié le plus fragile." },
        { key = "ringLife", score = 820, friendly = true, maxAllyHealth = 52, reason = "Augmente les soins reçus par cette cible en difficulté." },
        { key = "totemicSmash", score = 560, offensive = true, reason = "Le groupe est stable : contribue aux dégâts avec ta dépense principale." },
        { key = "seismicCrash", score = 520, offensive = true, reason = "Génère de la Rage pour tes prochains soins sismiques." },
        { key = "wildclaw", score = 450, offensive = true, reason = "Le groupe est stable : continue à frapper pour alimenter ton soin de mêlée." }
    },
    ["Mountain King"] = {
        { key = "rockBarrier", score = 1350, selfAction = true, maxPlayerHealth = 65, combat = true, buffMissing = { "Rock Barrier" }, reason = "Les dégâts reçus justifient ta barrière maintenant." },
        { key = "earthenAvatar", score = 1220, selfAction = true, maxPlayerHealth = 48, combat = true, burst = true, reason = "Ce pull devient dangereux : active ta grosse mitigation." },
        { key = "mountainHammer", score = 1150, targetCasting = true, reason = "Contrôle cette incantation avec ton marteau." },
        { key = "mountainFury", score = 1050, minEnemies = 2, reason = "Regroupe le pack devant toi et gagne de la réduction de dégâts." },
        { key = "earthquake", score = 980, minEnemies = 2, procOnly = true, reason = "Aftershock rend la zone gratuite : pose-la sous le pack." },
        { key = "quake", score = 900, reason = "Utilise une charge pour la menace immédiate et le ralentissement du pack." },
        { key = "seismicSmash", score = 750, reason = "Entretiens ta génération de Rage et les effets sismiques." },
        { key = "mountainHammer", score = 700, outOfRange = true, reason = "Ouvre à distance avec le marteau avant de réceptionner la cible." },
        { key = "stoneslam", score = 620, reason = "Ton coup direct est disponible entre deux Quake." },
        { key = "wildclaw", score = 500, reason = "Continue à frapper pour générer de la Rage et chercher Aftershock." },
        { key = "seismicCrash", score = 430, reason = "Maintiens ta ressource pendant le retour de Quake." }
    }
}

local function TooltipText(index)
    if not scannerTooltip or not index then return "" end
    scannerTooltip:ClearLines()
    if not pcall(scannerTooltip.SetSpellBookItem, scannerTooltip, index, BOOK) then return "" end
    local parts, line = {}, nil
    for line = 1, 20 do
        local left = _G["CoAPrimalistScannerTooltipTextLeft" .. line]
        local right = _G["CoAPrimalistScannerTooltipTextRight" .. line]
        if left and left:GetText() then table.insert(parts, left:GetText()) end
        if right and right:GetText() then table.insert(parts, right:GetText()) end
    end
    return table.concat(parts, " ")
end

local function ScanSpellbook()
    spellbook, spellList = {}, {}
    if not GetNumSpellTabs or not GetSpellTabInfo then return end
    local tab
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        offset, count = tonumber(offset) or 0, tonumber(count) or 0
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
                if IsPassiveSpell then local ok, result = pcall(IsPassiveSpell, index, BOOK); passive = ok and result and true or false end
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
    talents, talentList = {}, {}
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
                    talents[Normalize(name)] = entry; table.insert(talentList, entry)
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
                    talents[key] = entry; table.insert(talentList, entry)
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

local function SpellFor(key) return SpellByAliases(ALIASES[key]) end
local function HasMarker(name) local key = Normalize(name); return spellbook[key] ~= nil or talents[key] ~= nil end

local function SpecName(value)
    local key = Normalize(value)
    if key == "primal" or string.find(key, "wildwalker", 1, true) then return "Wildwalker" end
    if string.find(key, "geomancy", 1, true) or string.find(key, "geomanc", 1, true) then return "Geomancy" end
    if key == "life" or string.find(key, "grovekeeper", 1, true) then return "Grovekeeper" end
    if string.find(key, "mountainking", 1, true) or string.find(key, "roidelamontagne", 1, true) then return "Mountain King" end
    return nil
end

local function DetectClassAndSpec()
    local className, classToken = UnitClass and UnitClass("player")
    local classKey = Normalize(tostring(className or "") .. tostring(classToken or ""))
    classActive = string.find(classKey, "primalist", 1, true) ~= nil
    if not classActive then classActive = SpellFor("wildclaw") ~= nil and (SpellFor("handEarthmother") ~= nil or SpellFor("primalRush") ~= nil) end
    playerLevel = UnitLevel and tonumber(UnitLevel("player")) or 0
    if not classActive then activeSpec = "Inactif"; specSource = "autre classe"; return end

    if type(C_ClassInfo) == "table" and type(C_ClassInfo.GetAllSpecs) == "function"
        and type(C_ClassInfo.GetSpecInfo) == "function" and type(GetSpecialization) == "function" then
        local activeOK, activeIndex = pcall(GetSpecialization)
        activeIndex = activeOK and tonumber(activeIndex) or nil
        local activeID, activeName = activeIndex, nil
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
                local id, name = ok and info and tonumber(info.ID) or nil, ok and info and info.Name or nil
                local matches = id and (id == activeID or id == activeIndex)
                    or tonumber(specKey) and (tonumber(specKey) == activeID or tonumber(specKey) == activeIndex)
                    or activeName and name and Normalize(activeName) == Normalize(name)
                    or not activeName and activeID == activeIndex and index == activeIndex
                local resolved = matches and SpecName(name or activeName)
                if resolved then activeSpec = resolved; specSource = "catalogue CoA actif"; return end
            end
        end
    end

    local scores = { Wildwalker = 0, Geomancy = 0, Grovekeeper = 0, ["Mountain King"] = 0 }
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
    local wanted, _, value = {}, nil, nil
    for _, value in ipairs(aliases or {}) do wanted[Normalize(value)] = true end
    local getter = harmful and UnitDebuff or UnitBuff
    if not getter then return nil end
    local index
    for index = 1, 40 do
        local name, rank, texture, count, debuffType, duration, expirationTime, unitCaster = getter(unit, index)
        if not name then break end
        if wanted[Normalize(name)] then return { name = name, rank = rank, texture = texture, count = tonumber(count) or 0,
            debuffType = debuffType, duration = tonumber(duration) or 0, expiration = tonumber(expirationTime) or 0, caster = unitCaster } end
    end
    return nil
end

local function DetectProc()
    local rules, _, rule = PROC_RULES[activeSpec] or {}, nil, nil
    for _, rule in ipairs(rules) do
        local aura = UnitAuraByAliases("player", rule.auras, false)
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

local function UnitHealthPercent(unit)
    if not UnitExists or not UnitExists(unit) or not UnitHealth or not UnitHealthMax then return 100 end
    local maximum = tonumber(UnitHealthMax(unit)) or 0
    if maximum <= 0 then return 100 end
    return (tonumber(UnitHealth(unit)) or maximum) * 100 / maximum
end

local function TargetIsDurable()
    if not IsTargetValid() then return false end
    local classification = UnitClassification and UnitClassification("target") or "normal"
    return classification == "elite" or classification == "rareelite" or classification == "worldboss" or UnitHealthPercent("target") >= 80
end

local function TargetCasting()
    if not IsTargetValid() then return false end
    local name = UnitCastingInfo and UnitCastingInfo("target") or nil
    if not name and UnitChannelInfo then name = UnitChannelInfo("target") end
    return name and true or false
end

local function PruneCombatActors()
    local now, guid, seen = GetTime(), nil, nil
    for guid, seen in pairs(activeEnemies) do if now - (tonumber(seen) or 0) > 8 then activeEnemies[guid] = nil end end
end

local function EnemyCount()
    PruneCombatActors()
    local count = 0
    for _ in pairs(activeEnemies) do count = count + 1 end
    if IsTargetValid() then local guid = UnitGUID and UnitGUID("target"); if not guid or not activeEnemies[guid] then count = count + 1 end end
    return count
end

local function PetPresent()
    if UnitExists and UnitExists("pet") and not (UnitIsDead and UnitIsDead("pet")) then return true end
    if assumedPetUntil > GetTime() then return true end
    local guid, info
    for guid, info in pairs(ownedSummons) do
        if GetTime() - (info.seen or 0) > 900 then ownedSummons[guid] = nil
        elseif string.find(Normalize(info.name), "beast", 1, true) or string.find(Normalize(info.name), "spirit", 1, true) then return true end
    end
    return false
end

local function ReadRage()
    if UnitPower and UnitPowerMax then
        local okMax, maximum = pcall(UnitPowerMax, "player", 1)
        maximum = okMax and tonumber(maximum) or 0
        if maximum and maximum > 0 then
            local okCurrent, current = pcall(UnitPower, "player", 1)
            return okCurrent and tonumber(current) or 0, maximum, "API Rage"
        end
    end
    if UnitManaType and UnitMana and UnitManaMax then
        local ok, powerType = pcall(UnitManaType, "player")
        local maximum = tonumber(UnitManaMax("player")) or 0
        if ok and tonumber(powerType) == 1 and maximum > 0 then return tonumber(UnitMana("player")) or 0, maximum, "API 3.3.5" end
    end
    local aura = UnitAuraByAliases("player", { "Rage", "Primal Rage" }, false)
    if aura and aura.count and aura.count > 0 then return aura.count, 100, "aura Rage" end
    return nil, nil, "non exposée"
end

local function EarthshapingStacks()
    local aura = UnitAuraByAliases("player", { "Earthshaping", "Cragforming", "Earth Shaping" }, false)
    return aura and max(1, aura.count or 0) or 0
end

local function DispellableDebuff(unit)
    if not UnitDebuff or not UnitExists or not UnitExists(unit) then return nil end
    local index
    for index = 1, 40 do
        local name, _, texture, count, debuffType = UnitDebuff(unit, index)
        if not name then break end
        if debuffType == "Poison" or debuffType == "Disease" then return { name = name, texture = texture, count = count, kind = debuffType } end
    end
    return nil
end

local function HealingContext()
    local units = { "player" }
    local index
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for index = 1, min(40, GetNumRaidMembers()) do table.insert(units, "raid" .. index) end
    else
        local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
        for index = 1, min(4, partyCount) do table.insert(units, "party" .. index) end
    end
    local lowestUnit, lowestHealth, lowAllies, dispelUnit, dispel = "player", UnitHealthPercent("player"), 0, nil, nil
    local _, unit
    for _, unit in ipairs(units) do
        if UnitExists(unit) and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) then
            local health = UnitHealthPercent(unit)
            if health < lowestHealth then lowestUnit, lowestHealth = unit, health end
            if health < 80 then lowAllies = lowAllies + 1 end
            local bad = DispellableDebuff(unit)
            if bad and not dispelUnit then dispelUnit, dispel = unit, bad end
        end
    end
    return { unit = lowestUnit, health = lowestHealth, lowAllies = lowAllies, dispelUnit = dispelUnit, dispel = dispel }
end

local function SpellState(spell, unit)
    local state = { ready = true, usable = true, noMana = false, inRange = nil, start = 0, duration = 0 }
    if GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spell.name)
        state.start, state.duration = tonumber(start) or 0, tonumber(duration) or 0
        state.ready = enabled ~= 0 and (state.start == 0 or state.duration <= 1.5)
    end
    if IsUsableSpell then local usable, noMana = IsUsableSpell(spell.name); state.usable = usable and true or false; state.noMana = noMana and true or false end
    if IsSpellInRange and unit and UnitExists and UnitExists(unit) then
        local inRange = IsSpellInRange(spell.name, unit)
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
            if type(macroSpell) == "number" and GetSpellInfo then name = GetSpellInfo(macroSpell) elseif type(macroSpell) == "string" then name = macroSpell end
        end
        if name and Normalize(name) == Normalize(spellName) then
            local command
            if slot <= 12 then command = "ACTIONBUTTON" .. slot
            elseif slot <= 24 then command = "MULTIACTIONBAR1BUTTON" .. (slot - 12)
            elseif slot <= 36 then command = "MULTIACTIONBAR2BUTTON" .. (slot - 24)
            elseif slot <= 48 then command = "MULTIACTIONBAR3BUTTON" .. (slot - 36)
            elseif slot <= 60 then command = "MULTIACTIONBAR4BUTTON" .. (slot - 48) end
            if command and GetBindingKey then local key = GetBindingKey(command); if key then return string.gsub(string.gsub(key, "CTRL%-", "C-"), "SHIFT%-", "S-") end end
        end
    end
    return ""
end

local function EvaluateRule(rule, context)
    local spell = SpellFor(rule.key)
    local candidate = { rule = rule, spell = spell, score = rule.score or 0, rejected = {}, reason = rule.reason, targetUnit = nil }
    if not spell then table.insert(candidate.rejected, "sort non appris"); return candidate end
    local unit = "target"
    if rule.selfAction then unit = "player"
    elseif rule.friendly then unit = rule.dispel and context.healing.dispelUnit or context.healing.unit; candidate.targetUnit = unit end
    if (rule.offensive or not rule.friendly and not rule.selfAction) and not context.target then table.insert(candidate.rejected, "aucune cible hostile") end
    if rule.friendly and not unit then table.insert(candidate.rejected, "aucune cible alliée") end
    if rule.dispel and not context.healing.dispelUnit then table.insert(candidate.rejected, "aucun poison ou maladie") end
    if rule.maxAllyHealth and context.healing.health > rule.maxAllyHealth then table.insert(candidate.rejected, "alliés suffisamment hauts") end
    if rule.minLowAllies and context.healing.lowAllies < rule.minLowAllies then table.insert(candidate.rejected, "pas assez d'alliés blessés") end
    if rule.hotMissing and unit and UnitAuraByAliases(unit, rule.hotMissing, false) then table.insert(candidate.rejected, "soin déjà présent") end
    if rule.buffMissing and UnitAuraByAliases("player", rule.buffMissing, false) then table.insert(candidate.rejected, "effet déjà présent") end
    if rule.minEnemies and context.enemies < rule.minEnemies then table.insert(candidate.rejected, "pas assez de cibles") end
    if rule.maxPlayerHealth and context.playerHealth > rule.maxPlayerHealth then table.insert(candidate.rejected, "défensif conservé") end
    if rule.targetCasting and not context.targetCasting then table.insert(candidate.rejected, "cible sans incantation") end
    if rule.combat and not context.combat then table.insert(candidate.rejected, "hors combat") end
    if rule.burst and (not db.showBurst or not context.durable and not rule.selfAction) then table.insert(candidate.rejected, "cooldown conservé") end
    if rule.petMissing and context.pet then table.insert(candidate.rejected, "familier déjà actif") end
    if rule.minRage then
        if context.rage == nil then candidate.score = candidate.score - 700 elseif context.rage < rule.minRage then table.insert(candidate.rejected, "Rage insuffisante") end
    end
    if rule.maxRage and context.rage and context.rage > rule.maxRage then table.insert(candidate.rejected, "Rage déjà suffisante") end
    if rule.minEarthshaping and context.earthshaping < rule.minEarthshaping then table.insert(candidate.rejected, "Earthshaping insuffisant") end
    if rule.debuffMissing and UnitAuraByAliases("target", rule.debuffMissing, true) then table.insert(candidate.rejected, "effet déjà présent") end
    if rule.procOnly and not (currentProc and currentProc.action == rule.key) then table.insert(candidate.rejected, "proc absent") end
    candidate.state = SpellState(spell, unit)
    if rule.outOfRange and candidate.state.inRange ~= false then table.insert(candidate.rejected, "cible déjà à portée") end
    if not candidate.state.ready then table.insert(candidate.rejected, "recharge") end
    if not candidate.state.usable then table.insert(candidate.rejected, candidate.state.noMana and "mana/ressource insuffisante" or "inutilisable") end
    if candidate.state.inRange == false and not rule.outOfRange then table.insert(candidate.rejected, "hors de portée") end
    if currentProc and currentProc.action == rule.key then candidate.score = candidate.score + 2200; candidate.reason = currentProc.text .. " : profite du proc maintenant." end
    candidate.available = #candidate.rejected == 0
    return candidate
end

local function BuildDecision()
    local rage, rageMax, rageSource = ReadRage()
    local healing = HealingContext()
    local context = {
        target = IsTargetValid(), combat = UnitAffectingCombat and UnitAffectingCombat("player") or false,
        targetHealth = UnitHealthPercent("target"), playerHealth = UnitHealthPercent("player"), durable = TargetIsDurable(),
        targetCasting = TargetCasting(), enemies = EnemyCount(), rage = rage, rageMax = rageMax, rageSource = rageSource,
        earthshaping = EarthshapingStacks(), pet = PetPresent(), healing = healing
    }
    currentProc = DetectProc()
    local candidates, rejected, rules = {}, {}, RULES[activeSpec] or RULES.Initiation
    local _, rule
    for _, rule in ipairs(rules) do
        local candidate = EvaluateRule(rule, context)
        if candidate.available then table.insert(candidates, candidate) else table.insert(rejected, candidate) end
    end
    table.sort(candidates, function(a, b) if a.score == b.score then return tostring(a.spell.name) < tostring(b.spell.name) end return a.score > b.score end)
    currentAction = candidates[1]
    if not context.target and activeSpec ~= "Grovekeeper" and not (currentAction and currentAction.rule.selfAction) then currentAction = nil end
    if activeSpec == "Grovekeeper" and not context.target and healing.health >= 99 and not healing.dispelUnit then currentAction = nil end
    lastDecision = { context = context, candidates = candidates, rejected = rejected, proc = currentProc }
end

local function ShowToast(titleValue, textValue, seconds)
    if not toast then return end
    toastTitle:SetText(titleValue or "Primalist"); toastText:SetText(textValue or ""); toastUntil = GetTime() + (seconds or 7); toast:Show()
end

local function UpdateSearchText(item)
    local parts = { item.title or "", item.friendly or "", item.officialNote or "", item.kind or "" }
    local _, tag
    for _, tag in ipairs(type(item.tags) == "table" and item.tags or {}) do table.insert(parts, tag) end
    return lower(table.concat(parts, " "))
end

local function PromptPrimalistUpdates()
    if not classActive or type(CoARotationUpdateFeed) ~= "table" or type(CoARotationUpdateFeed.items) ~= "table" then return end
    local _, item
    for _, item in ipairs(CoARotationUpdateFeed.items) do
        local identity = tostring(item.id or item.updatedAt or item.title or "update")
        local text = UpdateSearchText(item)
        local relevant = string.find(text, "primalist", 1, true) ~= nil or string.find(text, lower(activeSpec), 1, true) ~= nil
            or string.find(text, activeSpec == "Wildwalker" and "primal" or activeSpec == "Grovekeeper" and "life" or "__none__", 1, true) ~= nil
        if not relevant then
            local _, spell
            for _, spell in ipairs(spellList) do local name = lower(tostring(spell.name or "")); if string.len(name) >= 5 and string.find(text, name, 1, true) then relevant = true; break end end
        end
        if relevant and not db.updateSeen[identity] then
            db.updateSeen[identity] = true
            local message = tostring(item.friendly or item.officialNote or "Une note officielle Ascension concerne Primalist.")
            ShowToast("MISE À JOUR ASCENSION", message, 12)
            Chat("une nouvelle note Ascension peut concerner " .. activeSpec .. ". Ouvre le Manager pour les détails.")
            if CoAMessageCenter and type(CoAMessageCenter.AddMessage) == "function" then CoAMessageCenter:AddMessage("Primalist Helper", message, "warning") end
            return
        end
    end
end

local function ImportantAction(action)
    return action and (currentProc and currentProc.action == action.rule.key or action.rule.dispel or action.rule.burst or action.score >= 1100)
end

local function NotifyAction(action)
    if not action or not action.spell then return end
    local key = Normalize(action.spell.name) .. ":" .. tostring(action.targetUnit or "") .. ":" .. tostring(currentProc and currentProc.text or "")
    if key == lastActionKey then return end
    lastActionKey = key
    if ImportantAction(action) and db.sound and GetTime() - lastSoundAt > 2.5 then lastSoundAt = GetTime(); if PlaySound then pcall(PlaySound, "RaidWarning") end end
end

local function PositionHUD()
    if not hud then return end
    hud:ClearAllPoints(); hud:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -115); hud:SetScale(Clamp(db.scale, 0.65, 1.8))
end

local function PositionMinimapButton()
    if not minimapButton or not Minimap then return end
    local radius = 80
    minimapButton:ClearAllPoints(); minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(db.buttonAngle or 3.25) * radius, math.sin(db.buttonAngle or 3.25) * radius)
end

local function UpdateMinimapVisibility()
    if not minimapButton then return end
    if hubManaged or db.buttonHidden or not classActive then minimapButton:Hide() else minimapButton:Show() end
end

local function TargetLabel(action)
    if not action or not action.targetUnit then return "" end
    local name = UnitName and UnitName(action.targetUnit) or action.targetUnit
    local health = UnitHealthPercent(action.targetUnit)
    return " → " .. tostring(name or action.targetUnit) .. " (" .. tostring(floor(health + 0.5)) .. "%)"
end

local function UpdateHUD()
    if not hud then return end
    local now, action = GetTime(), currentAction
    if testUntil > now and not action then
        local testSpell = SpellFor("wildclaw") or SpellFor("handEarthmother") or spellList[1]
        if testSpell then action = { spell = testSpell, rule = { key = "test" }, score = 999, reason = "Test visuel : l'addon ne lance rien.", state = SpellState(testSpell, "target") } end
    end
    local visible = db.enabled and classActive and (action ~= nil or not db.locked or testUntil > now)
    if not visible then hud:Hide(); return end
    hud:Show()
    if action and action.spell then
        icon:SetTexture(action.spell.texture or "Interface/Icons/Spell_Nature_Earthquake")
        local state = action.state or SpellState(action.spell, action.targetUnit or "target")
        if cooldown and cooldown.SetCooldown then cooldown:SetCooldown(state.start or 0, state.duration or 0) end
        if state.usable and state.ready then icon:SetVertexColor(1, 1, 1, 1) else icon:SetVertexColor(0.45, 0.45, 0.45, 0.7) end
        if ImportantAction(action) or state.usable and state.ready then glow:Show() else glow:Hide() end
        keyText:SetText(ActionKeybind(action.spell.name)); actionText:SetText(action.spell.name .. TargetLabel(action)); reasonText:SetText(action.reason or ""); NotifyAction(action)
    else
        icon:SetTexture("Interface/Icons/Spell_Nature_Earthquake"); icon:SetVertexColor(0.55, 0.75, 0.45, 0.8)
        glow:Hide(); keyText:SetText(""); actionText:SetText("Déplacer le HUD"); reasonText:SetText("Aucun sort n'est lancé automatiquement.")
    end
    local context = lastDecision and lastDecision.context or {}
    local rageLabel = context.rage ~= nil and (tostring(floor(context.rage + 0.5)) .. " Rage") or "Rage ?"
    local procLabel = currentProc and (" • " .. currentProc.text) or ""
    metaText:SetText(activeSpec .. " • niv. " .. tostring(playerLevel) .. " • " .. rageLabel .. procLabel)
    if context.rage ~= nil and context.rageMax and context.rageMax > 0 then
        rageFill:SetWidth(max(1, 86 * context.rage / context.rageMax)); rageFill:SetVertexColor(0.88, context.rage / context.rageMax >= 0.8 and 0.30 or 0.58, 0.20, 0.95)
    else rageFill:SetWidth(1); rageFill:SetVertexColor(0.35, 0.48, 0.30, 0.7) end
    if db.showText then actionText:Show(); metaText:Show(); reasonText:Show(); hud:SetWidth(300)
    else actionText:Hide(); metaText:Hide(); reasonText:Hide(); hud:SetWidth(104) end
    if not db.locked then editOverlay:Show() else editOverlay:Hide() end
end

local function UpdateMenu()
    if not menu then return end
    local context = lastDecision and lastDecision.context or {}
    local healing = context.healing or { health = 100, lowAllies = 0 }
    local rageText = context.rage ~= nil and (tostring(floor(context.rage + 0.5)) .. "/" .. tostring(context.rageMax or "?")) or "non exposée"
    menuStatus:SetText("Primalist • niveau " .. tostring(playerLevel or "?") .. " • " .. tostring(activeSpec)
        .. "\nDétection : " .. tostring(specSource) .. " • " .. tostring(#spellList) .. " sorts • " .. tostring(#talentList) .. " talents")
    local action = currentAction and currentAction.spell and (currentAction.spell.name .. TargetLabel(currentAction)) or "aucune action urgente"
    local reason = currentAction and currentAction.reason or "Le HUD se cache quand il n'y a rien d'utile à signaler."
    menuDetail:SetText("Conseil : " .. tostring(action) .. "\n" .. tostring(reason)
        .. "\nRage : " .. rageText .. " (" .. tostring(context.rageSource or "?") .. ") • ennemis : " .. tostring(context.enemies or 0)
        .. " • Earthshaping : " .. tostring(context.earthshaping or 0) .. " • familier : " .. (context.pet and "actif" or "absent")
        .. "\nAllié le plus bas : " .. tostring(floor((healing.health or 100) + 0.5)) .. "% • blessés : " .. tostring(healing.lowAllies or 0)
        .. "\nSources recoupées le " .. SOURCE_DATE .. ". Recommandations uniquement.")
end

local function FullScan(reason, announce)
    local oldNames, _, spell = {}, nil, nil
    for _, spell in ipairs(spellList) do oldNames[Normalize(spell.name)] = true end
    ScanSpellbook(); ScanTalents(); DetectClassAndSpec()
    local newNames = {}
    for _, spell in ipairs(spellList) do if not oldNames[Normalize(spell.name)] then table.insert(newNames, spell.name) end end
    local character = db.characters[CharacterKey()] or {}
    local oldLevel, oldSpec = tonumber(character.level) or 0, character.spec
    character.level, character.spec, character.spellCount, character.updatedAt = playerLevel, activeSpec, #spellList, time and time() or 0
    db.characters[CharacterKey()] = character
    if classActive and announce then
        if oldLevel > 0 and playerLevel > oldLevel then
            local message = "Niveau " .. tostring(playerLevel) .. " détecté. Le HUD a rescanné tes sorts et tes talents."
            if playerLevel == 10 then message = message .. " Choisis Wildwalker, Geomancy, Grovekeeper ou Mountain King : l'addon basculera automatiquement." end
            ShowToast("NOUVEAU NIVEAU", message, 9)
        elseif oldSpec and oldSpec ~= activeSpec then ShowToast("SPÉCIALISATION DÉTECTÉE", tostring(activeSpec) .. " est maintenant active. Les priorités viennent d'être remplacées.", 9)
        elseif #newNames > 0 and oldLevel > 0 then ShowToast("NOUVEAU SORT", table.concat(newNames, ", ") .. "\nLa priorité a été recalculée.", 8) end
    end
    BuildDecision(); UpdateHUD(); UpdateMenu(); UpdateMinimapVisibility(); PromptPrimalistUpdates()
    if announce and classActive then Chat("scan " .. tostring(reason or "manuel") .. " : niveau " .. tostring(playerLevel) .. ", " .. activeSpec .. ", " .. tostring(#spellList) .. " sorts.") end
end

local function MakeButton(parent, textValue, x, y, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 132); button:SetHeight(22); button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); button:SetText(textValue); return button
end

hud = CreateFrame("Frame", "CoAPrimalistHUD", UIParent)
hud:SetWidth(300); hud:SetHeight(112); hud:SetFrameStrata("HIGH"); hud:SetMovable(true); hud:SetClampedToScreen(true); hud:RegisterForDrag("LeftButton"); hud:EnableMouse(true)
hud:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
hud:SetBackdropColor(0.018, 0.055, 0.025, 0.95); hud:SetBackdropBorderColor(0.42, 0.88, 0.34, 0.95)
hud:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing(); local cx, cy = self:GetCenter(); local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then db.x, db.y = cx - ux, cy - uy end
end)
hud:SetScript("OnMouseUp", function(_, button) if button == "RightButton" and menu then if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end end end)
hud:Hide()

local iconFrame = CreateFrame("Frame", nil, hud)
iconFrame:SetWidth(68); iconFrame:SetHeight(68); iconFrame:SetPoint("LEFT", hud, "LEFT", 11, 6)
iconFrame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Buttons/UI-Quickslot2", edgeSize = 11 }); iconFrame:SetBackdropColor(0.01, 0.04, 0.015, 0.9)
icon = iconFrame:CreateTexture(nil, "ARTWORK"); icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 6, -6); icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -6, 6)
cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate"); cooldown:SetAllPoints(icon)
glow = iconFrame:CreateTexture(nil, "OVERLAY"); glow:SetTexture("Interface/Buttons/UI-ActionButton-Border"); glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", iconFrame, "CENTER", 0, 0); glow:SetWidth(92); glow:SetHeight(92); glow:SetVertexColor(0.35, 1.00, 0.25, 1); glow:Hide()
keyText = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); keyText:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", -5, -4); keyText:SetTextColor(1, 0.88, 0.35)

actionText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal"); actionText:SetPoint("TOPLEFT", hud, "TOPLEFT", 88, -15); actionText:SetWidth(200); actionText:SetJustifyH("LEFT"); actionText:SetTextColor(0.55, 0.95, 0.45)
metaText = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); metaText:SetPoint("TOPLEFT", actionText, "BOTTOMLEFT", 0, -5); metaText:SetWidth(200); metaText:SetJustifyH("LEFT")
reasonText = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); reasonText:SetPoint("TOPLEFT", metaText, "BOTTOMLEFT", 0, -6); reasonText:SetWidth(200); reasonText:SetJustifyH("LEFT"); reasonText:SetHeight(34)
rageBar = CreateFrame("Frame", nil, hud); rageBar:SetWidth(88); rageBar:SetHeight(7); rageBar:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 7, 7)
rageBar:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8" }); rageBar:SetBackdropColor(0.08, 0.12, 0.06, 0.9)
rageFill = rageBar:CreateTexture(nil, "ARTWORK"); rageFill:SetTexture("Interface/Buttons/WHITE8X8"); rageFill:SetPoint("LEFT", rageBar, "LEFT", 1, 0); rageFill:SetWidth(1); rageFill:SetHeight(5)
editOverlay = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); editOverlay:SetPoint("TOP", hud, "TOP", 0, 16); editOverlay:SetText("PRIMALIST • GLISSER POUR DÉPLACER"); editOverlay:SetTextColor(0.50, 1.0, 0.4)

hud:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("CoA Primalist Helper " .. VERSION, 0.5, 0.95, 0.4)
    if currentAction and currentAction.spell then GameTooltip:AddDoubleLine("Prochain conseil", currentAction.spell.name .. TargetLabel(currentAction), 1, 1, 1, 0.45, 1, 0.35); GameTooltip:AddLine(currentAction.reason or "", 0.85, 0.85, 0.85, true)
    else GameTooltip:AddLine("Aucune action urgente.", 0.65, 0.75, 0.62) end
    if currentProc then GameTooltip:AddDoubleLine("Proc", currentProc.text, 1, 1, 1, 1, 0.75, 0.2) end
    GameTooltip:AddLine("Clic droit : réglages", 0.55, 0.8, 0.5); GameTooltip:Show()
end)
hud:SetScript("OnLeave", function() GameTooltip:Hide() end)

toast = CreateFrame("Frame", "CoAPrimalistLevelToast", UIParent)
toast:SetWidth(440); toast:SetHeight(82); toast:SetPoint("TOP", UIParent, "TOP", 0, -115); toast:SetFrameStrata("DIALOG")
toast:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12 })
toast:SetBackdropColor(0.025, 0.07, 0.03, 0.97); toast:SetBackdropBorderColor(0.42, 0.88, 0.34, 0.95)
toastTitle = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); toastTitle:SetPoint("TOP", toast, "TOP", 0, -12); toastTitle:SetTextColor(0.55, 0.95, 0.45)
toastText = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); toastText:SetPoint("TOP", toastTitle, "BOTTOM", 0, -8); toastText:SetWidth(400); toastText:SetJustifyH("CENTER"); toast:Hide()

menu = CreateFrame("Frame", "CoAPrimalistMenu", UIParent)
menu:SetWidth(350); menu:SetHeight(350); menu:SetPoint("CENTER", UIParent, "CENTER", 260, 25); menu:SetFrameStrata("DIALOG"); menu:SetMovable(true); menu:EnableMouse(true); menu:RegisterForDrag("LeftButton")
menu:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12 })
menu:SetBackdropColor(0.02, 0.055, 0.025, 0.985); menu:SetBackdropBorderColor(0.42, 0.88, 0.34, 0.95)
menu:SetScript("OnDragStart", function(self) self:StartMoving() end); menu:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end); menu:Hide()
local menuTitle = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); menuTitle:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -15); menuTitle:SetText("PRIMALIST • ASSISTANT"); menuTitle:SetTextColor(0.55, 0.95, 0.45)
local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -3)
menuStatus = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); menuStatus:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -48); menuStatus:SetWidth(316); menuStatus:SetJustifyH("LEFT")
menuDetail = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); menuDetail:SetPoint("TOPLEFT", menu, "TOPLEFT", 16, -88); menuDetail:SetWidth(316); menuDetail:SetHeight(104); menuDetail:SetJustifyH("LEFT"); menuDetail:SetJustifyV("TOP")

local bTest = MakeButton(menu, "TEST 8 S", 16, -202, 151)
local bLock = MakeButton(menu, "DÉVERROUILLER", 181, -202, 151)
local bSound = MakeButton(menu, "SON : ON", 16, -230, 151)
local bText = MakeButton(menu, "TEXTE : ON", 181, -230, 151)
local bBurst = MakeButton(menu, "BURST : ON", 16, -258, 151)
local bMinimap = MakeButton(menu, "BOUTON : ON", 181, -258, 151)
local bScan = MakeButton(menu, "RESCANNER", 16, -286, 151)
local bReset = MakeButton(menu, "RESET", 181, -286, 151)
local sourceLine = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sourceLine:SetPoint("BOTTOM", menu, "BOTTOM", 0, 14); sourceLine:SetText("Build Hub • Sidekick • coa-datamine • personnage réel")

minimapButton = CreateFrame("Button", "CoAPrimalistMinimapButton", Minimap)
minimapButton:SetWidth(32); minimapButton:SetHeight(32); minimapButton:SetFrameStrata("MEDIUM"); minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp"); minimapButton:RegisterForDrag("LeftButton")
local miniIcon = minimapButton:CreateTexture(nil, "BACKGROUND"); miniIcon:SetTexture("Interface/Icons/Spell_Nature_Earthquake"); miniIcon:SetWidth(20); miniIcon:SetHeight(20); miniIcon:SetPoint("CENTER", 0, 0); miniIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local miniBorder = minimapButton:CreateTexture(nil, "OVERLAY"); miniBorder:SetTexture("Interface/Minimap/MiniMap-TrackingBorder"); miniBorder:SetWidth(52); miniBorder:SetHeight(52); miniBorder:SetPoint("TOPLEFT", 0, 0)
minimapButton:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then db.locked = not db.locked; UpdateHUD(); UpdateMenu() else if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end end
end)
minimapButton:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine("Primalist Helper", 0.55, 0.95, 0.45); GameTooltip:AddLine("Clic : réglages • clic droit : verrouiller", 1, 1, 1); GameTooltip:Show() end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        if not Minimap then return end
        local mx, my = Minimap:GetCenter(); local px, py = GetCursorPosition(); local scale = UIParent:GetEffectiveScale(); px, py = px / scale, py / scale
        db.buttonAngle = math.atan2(py - my, px - mx); PositionMinimapButton()
    end)
end)
minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil); PositionMinimapButton() end)

local function HandleCommand(message)
    EnsureDB()
    local command, value = string.match(tostring(message or ""), "^(%S*)%s*(.-)%s*$"); command = Normalize(command)
    if command == "" then if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end
    elseif command == "status" then
        local context = lastDecision and lastDecision.context or {}; local healing = context.healing or {}
        Chat("niveau=" .. tostring(playerLevel) .. " spec=" .. activeSpec .. " source=" .. specSource .. " sorts=" .. tostring(#spellList)
            .. " talents=" .. tostring(#talentList) .. " Rage=" .. tostring(context.rage or "?") .. " ennemis=" .. tostring(context.enemies or 0)
            .. " alliéBas=" .. tostring(floor((healing.health or 100) + 0.5)))
    elseif command == "scan" then FullScan("manuel", true)
    elseif command == "unlock" then db.locked = false; UpdateHUD(); Chat("HUD déverrouillé : glisse-le avec la souris.")
    elseif command == "lock" then db.locked = true; UpdateHUD(); Chat("HUD verrouillé.")
    elseif command == "test" then testUntil = GetTime() + 8; ShowToast("TEST PRIMALIST", "Icône, cooldown, glow et alerte de niveau. Aucun sort ne sera lancé.", 8); UpdateHUD()
    elseif command == "sound" then db.sound = not db.sound; Chat("son des procs " .. (db.sound and "activé" or "coupé") .. ".")
    elseif command == "text" then db.showText = not db.showText; UpdateHUD()
    elseif command == "burst" then db.showBurst = not db.showBurst; BuildDecision(); UpdateHUD()
    elseif command == "minimap" or command == "button" then db.buttonHidden = not db.buttonHidden; UpdateMinimapVisibility()
    elseif command == "scale" then db.scale = Clamp(tonumber(value), 0.65, 1.8); PositionHUD()
    elseif command == "debug" then
        if currentAction then Chat("conseil=" .. currentAction.spell.name .. TargetLabel(currentAction) .. " score=" .. tostring(currentAction.score) .. " raison=" .. tostring(currentAction.reason))
        else Chat("aucune action. Vérifie cible, portée, cooldown, Rage ou alliés avec /primal status.") end
        local rejected = lastDecision and lastDecision.rejected or {}; local index
        for index = 1, min(6, #rejected) do Chat("rejet " .. tostring(rejected[index].spell and rejected[index].spell.name or rejected[index].rule.key) .. " : " .. table.concat(rejected[index].rejected, ", ")) end
    elseif command == "reset" then
        db.x, db.y, db.scale, db.locked, db.sound, db.showText, db.showBurst, db.buttonHidden, db.buttonAngle = 0, -115, 1.0, true, true, true, true, false, 3.25
        PositionHUD(); PositionMinimapButton(); UpdateMinimapVisibility(); Chat("réglages Primalist réinitialisés.")
    else Chat("/primal status | scan | unlock | lock | test | sound | text | burst | minimap | scale 1 | debug | reset") end
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
    UpdateMenu(); bLock:SetText(db.locked and "DÉVERROUILLER" or "VERROUILLER"); bSound:SetText("SON : " .. (db.sound and "ON" or "OFF")); bText:SetText("TEXTE : " .. (db.showText and "ON" or "OFF")); bBurst:SetText("BURST : " .. (db.showBurst and "ON" or "OFF")); bMinimap:SetText("BOUTON : " .. (db.buttonHidden and "OFF" or "ON"))
end)

CoAPrimalistHelperAPI = CoAPrimalistHelperAPI or {}
function CoAPrimalistHelperAPI:Toggle() if menu:IsShown() then menu:Hide() else menu:Show(); UpdateMenu() end end
function CoAPrimalistHelperAPI:Show() menu:Show(); UpdateMenu() end
function CoAPrimalistHelperAPI:SetHubManaged(value) hubManaged = value and true or false; UpdateMinimapVisibility() end
function CoAPrimalistHelperAPI:Refresh() FullScan("API", true) end
function CoAPrimalistHelperAPI:GetStatus()
    return { active = classActive, level = playerLevel, spec = activeSpec, source = specSource, spellCount = #spellList,
        talentCount = #talentList, action = currentAction and currentAction.spell.name or nil, target = currentAction and currentAction.targetUnit or nil }
end

SLASH_COAPRIMALIST1 = "/primal"
SLASH_COAPRIMALIST2 = "/ph"
SlashCmdList.COAPRIMALIST = HandleCommand

local function IsOwnedGUID(guid, flags)
    if not guid then return false end
    if guid == playerGUID or ownedSummons[guid] then return true end
    if bit and bit.band and flags and COMBATLOG_OBJECT_AFFILIATION_MINE then return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 end
    return false
end

local function HandleCombatLog(...)
    local _, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName = ...
    local now, sourceOwned = GetTime(), IsOwnedGUID(sourceGUID, sourceFlags)
    if eventType == "SPELL_SUMMON" and sourceOwned and destGUID then ownedSummons[destGUID] = { name = destName or spellName or "invocation", seen = now }
    elseif eventType == "UNIT_DIED" or eventType == "UNIT_DESTROYED" then if destGUID then ownedSummons[destGUID] = nil; activeEnemies[destGUID] = nil end end
    if sourceOwned and destGUID and not IsOwnedGUID(destGUID, destFlags) then
        if string.find(tostring(eventType), "DAMAGE", 1, true) or eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_CAST_SUCCESS" then activeEnemies[destGUID] = now end
    elseif IsOwnedGUID(destGUID, destFlags) and sourceGUID and not sourceOwned then
        if string.find(tostring(eventType), "DAMAGE", 1, true) or eventType == "SPELL_AURA_APPLIED" then activeEnemies[sourceGUID] = now end
    end
    if sourceOwned and eventType == "SPELL_CAST_SUCCESS" and spellName then
        local callPet = SpellFor("callPet")
        if callPet and Normalize(spellName) == Normalize(callPet.name) then assumedPetUntil = now + 300 end
    end
end

local events = CreateFrame("Frame")
local eventNames = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
    "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "UNIT_POWER", "UNIT_MANA", "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_PET", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
    "COMBAT_LOG_EVENT_UNFILTERED"
}
local _, eventName
for _, eventName in ipairs(eventNames) do pcall(events.RegisterEvent, events, eventName) end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName and loaded ~= "CoAPrimalistHelper" then return end
        EnsureDB(); playerGUID = UnitGUID and UnitGUID("player") or nil; PositionHUD(); PositionMinimapButton(); FullScan("chargement", false)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then playerGUID = UnitGUID and UnitGUID("player") or playerGUID; scanPendingAt = GetTime() + 1.0
    elseif event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then scanPendingAt = GetTime() + 0.65
    elseif event == "PLAYER_REGEN_DISABLED" then if IsTargetValid() and UnitGUID then activeEnemies[UnitGUID("target") or "target"] = GetTime() end
    elseif event == "PLAYER_REGEN_ENABLED" then activeEnemies = {}
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then HandleCombatLog(...) end
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
