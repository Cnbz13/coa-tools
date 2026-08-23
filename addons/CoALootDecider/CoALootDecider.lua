local addonName = ...

local ROLL_PASS = 0
local ROLL_NEED = 1
local ROLL_GREED = 2
local RETRY_INTERVAL = 0.25
local ITEM_CACHE_TIMEOUT = 3
local HISTORY_LIMIT = 50

local pendingRolls = {}
local confirmations = {}
local profile = nil
local retryElapsed = 0

local STAT_ALIASES = {
    str = "ITEM_MOD_STRENGTH_SHORT",
    strength = "ITEM_MOD_STRENGTH_SHORT",
    force = "ITEM_MOD_STRENGTH_SHORT",
    agi = "ITEM_MOD_AGILITY_SHORT",
    agility = "ITEM_MOD_AGILITY_SHORT",
    agilite = "ITEM_MOD_AGILITY_SHORT",
    int = "ITEM_MOD_INTELLECT_SHORT",
    intellect = "ITEM_MOD_INTELLECT_SHORT",
    sta = "ITEM_MOD_STAMINA_SHORT",
    stamina = "ITEM_MOD_STAMINA_SHORT",
    endu = "ITEM_MOD_STAMINA_SHORT",
    spirit = "ITEM_MOD_SPIRIT_SHORT",
    esprit = "ITEM_MOD_SPIRIT_SHORT",
    spell = "ITEM_MOD_SPELL_POWER_SHORT",
    spellpower = "ITEM_MOD_SPELL_POWER_SHORT",
    sp = "ITEM_MOD_SPELL_POWER_SHORT",
    ap = "ITEM_MOD_ATTACK_POWER_SHORT",
    attackpower = "ITEM_MOD_ATTACK_POWER_SHORT",
    hit = "ITEM_MOD_HIT_RATING_SHORT",
    crit = "ITEM_MOD_CRIT_RATING_SHORT",
    haste = "ITEM_MOD_HASTE_RATING_SHORT",
    expertise = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    arp = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    defense = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    dodge = "ITEM_MOD_DODGE_RATING_SHORT",
    parry = "ITEM_MOD_PARRY_RATING_SHORT",
    block = "ITEM_MOD_BLOCK_RATING_SHORT",
    mp5 = "ITEM_MOD_MANA_REGENERATION_SHORT",
    armor = "RESISTANCE0_NAME"
}

local DISPLAY_STATS = {
    ITEM_MOD_STRENGTH_SHORT = "FOR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_STAMINA_SHORT = "END",
    ITEM_MOD_SPIRIT_SHORT = "ESPRIT",
    ITEM_MOD_SPELL_POWER_SHORT = "PS",
    ITEM_MOD_ATTACK_POWER_SHORT = "PA",
    ITEM_MOD_HIT_RATING_SHORT = "TOUCH",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HATE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERT",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARP",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
    ITEM_MOD_DODGE_RATING_SHORT = "ESQUIVE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARADE",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOC",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    RESISTANCE0_NAME = "ARMURE"
}

-- Un profil public utilise des noms stables et compacts ; le client 3.3.5
-- peut retourner soit une statistique globale, soit sa variante melee/ranged/spell.
local PROFILE_STAT_KEYS = {
    str = { "ITEM_MOD_STRENGTH_SHORT" },
    agi = { "ITEM_MOD_AGILITY_SHORT" },
    sta = { "ITEM_MOD_STAMINA_SHORT" },
    int = { "ITEM_MOD_INTELLECT_SHORT" },
    spi = { "ITEM_MOD_SPIRIT_SHORT" },
    ap = { "ITEM_MOD_ATTACK_POWER_SHORT" },
    rap = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    sp = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
    heal = { "ITEM_MOD_HEALING_DONE_SHORT" },
    crit = {
        "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT",
        "ITEM_MOD_CRIT_RANGED_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT"
    },
    hit = {
        "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT",
        "ITEM_MOD_HIT_RANGED_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"
    },
    haste = {
        "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT",
        "ITEM_MOD_HASTE_RANGED_RATING_SHORT", "ITEM_MOD_HASTE_SPELL_RATING_SHORT"
    },
    arp = { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
    spellpen = { "ITEM_MOD_SPELL_PENETRATION_SHORT" },
    expertise = { "ITEM_MOD_EXPERTISE_RATING_SHORT" },
    defense = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
    dodge = { "ITEM_MOD_DODGE_RATING_SHORT" },
    parry = { "ITEM_MOD_PARRY_RATING_SHORT" },
    block = { "ITEM_MOD_BLOCK_RATING_SHORT" },
    blockvalue = { "ITEM_MOD_BLOCK_VALUE_SHORT" },
    shieldvalue = { "ITEM_MOD_BLOCK_VALUE_SHORT" },
    armor = { "RESISTANCE0_NAME" },
    wdps = { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" },
    rdps = { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" }
}

local PRIMARY_STATS = {
    "ITEM_MOD_STRENGTH_SHORT",
    "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_INTELLECT_SHORT"
}

local PRIMARY_STAT_KEYS = {
    Strength = "ITEM_MOD_STRENGTH_SHORT",
    Agility = "ITEM_MOD_AGILITY_SHORT",
    Intellect = "ITEM_MOD_INTELLECT_SHORT",
    Spirit = "ITEM_MOD_SPIRIT_SHORT"
}

local UNIT_PRIMARY_STAT_NAMES = {
    [1] = "Strength",
    [2] = "Agility",
    [3] = "Intellect",
    [4] = "Spirit"
}

local SPELL_POWER_STATS = {
    "ITEM_MOD_SPELL_POWER_SHORT",
    "ITEM_MOD_HEALING_DONE_SHORT"
}

local PHYSICAL_POWER_STATS = {
    "ITEM_MOD_ATTACK_POWER_SHORT",
    "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    "ITEM_MOD_EXPERTISE_RATING_SHORT"
}

local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_2HWEAPON = { 16, 17 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
    INVTYPE_TABARD = { 19 }
}

-- Le Pyromancien exige un gain nettement plus visible avant de NEED.
-- Les autres classes utilisent le seuil global prudent de 5%.
local DEFAULT_CLASS_THRESHOLDS = {
    PYROMANCER = 10
}

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff67d9ffCoA Loot Decider:|r " .. tostring(message))
    end
end

local function Round(value, decimals)
    local factor = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0) * factor + 0.5) / factor
end

local function Trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
end

local function Lower(value)
    return string.lower(value or "")
end

local function PlayerLevel()
    if type(UnitLevel) == "function" then
        local ok, value = pcall(UnitLevel, "player")
        if ok and tonumber(value) then return tonumber(value) end
    end
    return 1
end

local function EnsureDatabase()
    CoALootDeciderDB = CoALootDeciderDB or {}
    if CoALootDeciderDB.autoRoll == nil then CoALootDeciderDB.autoRoll = true end
    if CoALootDeciderDB.autoConfirm == nil then CoALootDeciderDB.autoConfirm = true end
    -- Depuis 0.2, une information inconnue ne provoque jamais un PASS
    -- automatique. Ne rien choisir est plus sur qu'une mauvaise decision.
    if CoALootDeciderDB.strictSafetyVersion ~= 2 then
        CoALootDeciderDB.passUnknown = false
        CoALootDeciderDB.strictSafetyVersion = 2
    end
    -- Migration 0.2.3 : l'ancien seuil global de 1% etait trop permissif.
    -- Elle ne s'execute qu'une fois ; les reglages suivants restent conserves.
    if CoALootDeciderDB.thresholdPolicyVersion ~= 3 then
        CoALootDeciderDB.threshold = 5
        CoALootDeciderDB.thresholdPolicyVersion = 3
    else
        CoALootDeciderDB.threshold = tonumber(CoALootDeciderDB.threshold) or 5
    end
    CoALootDeciderDB.thresholdsBySpec = CoALootDeciderDB.thresholdsBySpec or {}
    -- Les profils EP publics chiffrent deja DPS d'arme, armure et statistiques.
    -- Ajouter arbitrairement l'ilvl faisait gagner des objets moins utiles.
    if CoALootDeciderDB.statProfileVersion ~= 1 then
        CoALootDeciderDB.itemLevelWeight = 0
        CoALootDeciderDB.statProfileVersion = 1
    else
        CoALootDeciderDB.itemLevelWeight = tonumber(CoALootDeciderDB.itemLevelWeight) or 0
    end
    CoALootDeciderDB.customWeights = CoALootDeciderDB.customWeights or {}
    CoALootDeciderDB.adaptiveBuilds = CoALootDeciderDB.adaptiveBuilds or {}
    CoALootDeciderDB.history = CoALootDeciderDB.history or {}
    if CoALootDeciderDB.needLockedChests == nil then CoALootDeciderDB.needLockedChests = true end
    CoALootDeciderDB.bannerPosition = CoALootDeciderDB.bannerPosition or nil
    CoALootDeciderDB.version = "1.11.1-rotation-guide-manager-fix"
end

local function ReadItemStats(itemLink)
    local stats = {}
    if not itemLink or not GetItemStats then return stats end

    local ok = pcall(GetItemStats, itemLink, stats)
    if ok and next(stats) then return stats end

    local success, result = pcall(GetItemStats, itemLink)
    if success and type(result) == "table" then return result end
    return stats
end

local weaponScanner = CreateFrame("GameTooltip", "CoALootDeciderWeaponScanner", nil, "GameTooltipTemplate")
weaponScanner:SetOwner(UIParent, "ANCHOR_NONE")

local function ReadWeaponSpeed(itemLink)
    if not itemLink then return nil end
    weaponScanner:ClearLines()
    if not pcall(weaponScanner.SetHyperlink, weaponScanner, itemLink) then return nil end
    local line
    for line = 2, math.min(weaponScanner:NumLines(), 8) do
        local left = _G["CoALootDeciderWeaponScannerTextLeft" .. line]
        local right = _G["CoALootDeciderWeaponScannerTextRight" .. line]
        local text = (left and left:GetText() or "") .. " " .. (right and right:GetText() or "")
        local value = string.match(text, "[Ss]peed%s*([0-9]+[.,][0-9]+)")
            or string.match(text, "[Vv]itesse%s*([0-9]+[.,][0-9]+)")
        if value then
            weaponScanner:Hide()
            local normalized = string.gsub(value, ",", ".")
            return tonumber(normalized)
        end
    end
    weaponScanner:Hide()
    return nil
end

local function ItemData(itemLink)
    if not itemLink or not GetItemInfo then return nil end
    local name, link, quality, itemLevel, requiredLevel, itemType, itemSubType, stackCount, equipLoc, texture = GetItemInfo(itemLink)
    if not name or not equipLoc then return nil end
    local classID, subClassID
    if type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, resolvedClassID, resolvedSubClassID = pcall(GetItemInfoInstant, link or itemLink)
        if ok then
            classID = tonumber(resolvedClassID)
            subClassID = tonumber(resolvedSubClassID)
        end
    end

    local isWeapon = equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_WEAPON"
        or equipLoc == "INVTYPE_WEAPONMAINHAND"
        or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_RANGED"
        or equipLoc == "INVTYPE_RANGEDRIGHT"

    return {
        name = name,
        link = link or itemLink,
        quality = tonumber(quality) or 0,
        itemLevel = tonumber(itemLevel) or 0,
        requiredLevel = tonumber(requiredLevel) or 0,
        itemType = itemType,
        itemSubType = itemSubType,
        classID = classID,
        subClassID = subClassID,
        stackCount = tonumber(stackCount) or 1,
        equipLoc = equipLoc,
        texture = texture,
        stats = ReadItemStats(link or itemLink),
        weaponSpeed = isWeapon and ReadWeaponSpeed(link or itemLink) or nil
    }
end

local lockedChestScanner = CreateFrame("GameTooltip", "CoALootDeciderLockedChestScanner", nil, "GameTooltipTemplate")
lockedChestScanner:SetOwner(UIParent, "ANCHOR_NONE")
local lockedChestCache = {}
local LOCKED_CHEST_CONTAINER_WORDS = {
    "chest", "coffer", "lockbox", "strongbox", "crate", "cache",
    "coffre", "coffret", "boite", "boîte", "malle", "caisse",
}
local LOCKED_CHEST_LOCK_WORDS = {
    "locked", "lockpicking", "requires a key", "requires key",
    "verrou", "crochetage", "nécessite une clé", "necessite une cle",
}

local function ContainsPlain(text, words)
    for _, word in ipairs(words) do
        if string.find(text or "", word, 1, true) then return true end
    end
    return false
end

local function IsLockedChest(data)
    if not data or not data.link then return false end
    if lockedChestCache[data.link] ~= nil then return lockedChestCache[data.link] end
    local identity = Lower((data.name or "") .. " " .. (data.itemType or "") .. " " .. (data.itemSubType or ""))
    local looksLikeContainer = ContainsPlain(identity, LOCKED_CHEST_CONTAINER_WORDS)
    local explicitlyLocked = ContainsPlain(identity, LOCKED_CHEST_LOCK_WORDS)
        or string.find(identity, "lockbox", 1, true)
    if looksLikeContainer and explicitlyLocked then
        lockedChestCache[data.link] = true
        return true
    end
    if not looksLikeContainer then
        lockedChestCache[data.link] = false
        return false
    end

    lockedChestScanner:ClearLines()
    if not pcall(lockedChestScanner.SetHyperlink, lockedChestScanner, data.link) then
        lockedChestScanner:Hide()
        return false
    end
    local tooltipText = identity
    local line
    for line = 1, lockedChestScanner:NumLines() do
        local left = _G["CoALootDeciderLockedChestScannerTextLeft" .. line]
        local right = _G["CoALootDeciderLockedChestScannerTextRight" .. line]
        tooltipText = tooltipText .. " " .. Lower(left and left:GetText() or "")
            .. " " .. Lower(right and right:GetText() or "")
    end
    lockedChestScanner:Hide()
    local result = ContainsPlain(tooltipText, LOCKED_CHEST_LOCK_WORDS)
        or string.find(tooltipText, "lockbox", 1, true) ~= nil
    lockedChestCache[data.link] = result and true or false
    return result and true or false
end

-- Ascension 3.3.5 expose les fonctions de sacs globales de WotLK. Ne pas
-- utiliser l'espace de noms Retail des conteneurs, absent de certains clients CoA.
local function ScanBagItems()
    local result = {}
    if type(GetContainerNumSlots) ~= "function" or type(GetContainerItemLink) ~= "function" then
        return result
    end
    local maxBag = tonumber(NUM_BAG_SLOTS) or 4
    local bag, slot
    for bag = 0, maxBag do
        local ok, slots = pcall(GetContainerNumSlots, bag)
        slots = ok and tonumber(slots) or 0
        for slot = 1, slots do
            local linkOk, itemLink = pcall(GetContainerItemLink, bag, slot)
            if linkOk and itemLink then
                local data = ItemData(itemLink)
                if data and EQUIP_SLOTS[data.equipLoc] then
                    data.bag = bag
                    data.bagSlot = slot
                    data.ownedSource = "sac"
                    table.insert(result, data)
                end
            end
        end
    end
    return result
end

local effectScanner = CreateFrame("GameTooltip", "CoALootDeciderEffectScanner", nil, "GameTooltipTemplate")
effectScanner:SetOwner(UIParent, "ANCHOR_NONE")
local effectCache = {}

local STANDARD_EQUIP_TEXT = {
    "attack power", "ranged attack power", "spell power", "healing done",
    "critical strike rating", "crit rating", "hit rating", "haste rating",
    "expertise rating", "armor penetration rating", "defense rating",
    "dodge rating", "parry rating", "block rating", "block value",
    "mana per 5", "mana every 5", "spell penetration",
    "puissance d'attaque", "puissance des sorts", "puissance de soin",
    "score de coup critique", "score de toucher", "score de hate",
    "score d'expertise", "penetration d'armure", "score de defense",
    "score d'esquive", "score de parade", "score de blocage",
    "mana toutes les 5"
}

local SPECIAL_EFFECT_TEXT = {
    "chance", "when you", "whenever", "each time", "on hit", "for 10 sec",
    "for 15 sec", "for 20 sec", "stack", "summon", "your attacks have",
    "your spells have", "lorsque", "chaque fois", "pendant 10 sec",
    "pendant 15 sec", "pendant 20 sec", "cumul", "invoque",
    "vos attaques ont", "vos sorts ont"
}

local function ContainsAny(text, needles)
    local _, needle
    for _, needle in ipairs(needles) do
        if string.find(text, needle, 1, true) then return true end
    end
    return false
end

local function HasUnscoredEffect(itemLink)
    if not itemLink then return false end
    if effectCache[itemLink] ~= nil then return effectCache[itemLink] end
    effectScanner:ClearLines()
    local success = pcall(effectScanner.SetHyperlink, effectScanner, itemLink)
    if not success then
        effectScanner:Hide()
        effectCache[itemLink] = true
        return true
    end

    local line
    for line = 2, effectScanner:NumLines() do
        local fontString = _G["CoALootDeciderEffectScannerTextLeft" .. line]
        local rawText = fontString and fontString:GetText() or ""
        local text = Lower(rawText)
        local isUse = string.find(text, "use:", 1, true)
            or string.find(text, "utiliser :", 1, true)
            or string.find(text, "utiliser:", 1, true)
        local isEquip = string.find(text, "equip:", 1, true)
            or string.find(text, "equipe :", 1, true)
            or string.find(text, "equipe:", 1, true)
            or string.find(rawText, "Équipé", 1, true)
            or string.find(rawText, "Équipée", 1, true)
        local isSet = string.find(text, "set:", 1, true)
            or string.find(text, "set bonus", 1, true)
            or string.find(text, "bonus d'ensemble", 1, true)
        -- Les statistiques ordinaires de WotLK sont souvent ecrites comme
        -- "Equip: +score". Elles sont deja retournees par GetItemStats et ne
        -- doivent pas rendre presque tout le stuff incertain. Seuls les procs,
        -- utilisations et effets non standards restent en choix manuel.
        if isUse or isSet or ContainsAny(text, SPECIAL_EFFECT_TEXT)
            or (isEquip and not ContainsAny(text, STANDARD_EQUIP_TEXT))
        then
            effectScanner:Hide()
            effectCache[itemLink] = true
            return true
        end
    end
    effectScanner:Hide()
    effectCache[itemLink] = false
    return false
end

local function AddStats(target, source)
    local key, value
    for key, value in pairs(source or {}) do
        target[key] = (target[key] or 0) + (tonumber(value) or 0)
    end
end

local function StatValue(stats, key)
    return tonumber(stats and stats[key]) or 0
end

local function ResolvePrimaryStats(specInfo)
    local resolved = {}
    local _, primaryName
    if type(specInfo.PrimaryStats) == "table" then
        for _, primaryName in ipairs(specInfo.PrimaryStats) do
            if PRIMARY_STAT_KEYS[primaryName] then table.insert(resolved, primaryName) end
        end
    end
    if #resolved > 0 then return resolved, "catalogue CoA" end

    -- Certains profils CoA, dont Pyromancer - Flameweaving, exposent une
    -- table PrimaryStats vide. Le client connait quand meme la statistique
    -- active via GetUnitPrimaryStat (1=FOR, 2=AGI, 3=INT, 4=ESPRIT).
    if type(GetUnitPrimaryStat) == "function" then
        local success, unitPrimary = pcall(GetUnitPrimaryStat, "player")
        local unitPrimaryName = success and UNIT_PRIMARY_STAT_NAMES[tonumber(unitPrimary)] or nil
        if not unitPrimaryName and success and type(unitPrimary) == "string"
            and PRIMARY_STAT_KEYS[unitPrimary]
        then
            unitPrimaryName = unitPrimary
        end
        if unitPrimaryName then return { unitPrimaryName }, "personnage actif" end
    end
    return {}, "indisponible"
end

local function ResolveActiveSpecialization()
    local className, classToken = UnitClass("player")
    if type(C_ClassInfo) ~= "table"
        or type(C_ClassInfo.GetAllSpecs) ~= "function"
        or type(C_ClassInfo.GetSpecInfo) ~= "function"
        or type(GetSpecialization) ~= "function"
    then
        return nil, "API de specialisation CoA indisponible"
    end

    -- Ascension suit ici l'API moderne de WoW : GetSpecialization() renvoie
    -- l'index actif (1, 2, 3...), pas necessairement l'ID du catalogue CoA.
    local success, specializationIndex = pcall(GetSpecialization)
    specializationIndex = success and tonumber(specializationIndex) or nil
    if not specializationIndex or specializationIndex == 0 then
        return nil, "specialisation CoA active introuvable"
    end

    local specializationID = specializationIndex
    local specializationName = nil
    if type(GetSpecializationInfo) == "function" then
        local infoSuccess, resolvedID, resolvedName = pcall(GetSpecializationInfo, specializationIndex)
        resolvedID = infoSuccess and tonumber(resolvedID) or nil
        if resolvedID and resolvedID ~= 0 then specializationID = resolvedID end
        if infoSuccess and type(resolvedName) == "string" and resolvedName ~= "" then
            specializationName = resolvedName
        end
    end

    local catalogSuccess, specs = pcall(C_ClassInfo.GetAllSpecs, classToken)
    if not catalogSuccess or type(specs) ~= "table" then
        return nil, "catalogue de classe CoA indisponible"
    end

    local catalogIndex, spec
    for catalogIndex, spec in ipairs(specs) do
        local infoSuccess, specInfo = pcall(C_ClassInfo.GetSpecInfo, classToken, spec)
        local catalogID = infoSuccess and specInfo and tonumber(specInfo.ID) or nil
        local catalogName = infoSuccess and specInfo and specInfo.Name or nil
        local idMatches = catalogID and (catalogID == specializationID or catalogID == specializationIndex)
        local keyMatches = tonumber(spec) and (tonumber(spec) == specializationID or tonumber(spec) == specializationIndex)
        local nameMatches = specializationName and catalogName
            and Lower(specializationName) == Lower(catalogName)
        -- Le repli par position n'est utilise que si GetSpecializationInfo n'a
        -- fourni ni ID distinct ni nom. Les clients Ascension actuels passent
        -- normalement par l'ID resolu, ce qui reste le chemin le plus sur.
        local positionMatches = not specializationName and specializationID == specializationIndex
            and catalogIndex == specializationIndex
        if infoSuccess and specInfo and (idMatches or keyMatches or nameMatches or positionMatches) then
            local primaryStats, primarySource = ResolvePrimaryStats(specInfo)
            return {
                className = className or classToken or "Classe inconnue",
                classToken = classToken,
                specializationIndex = specializationIndex,
                specializationID = catalogID or specializationID,
                specInfo = specInfo,
                specName = specInfo.Name or tostring(spec),
                primaryStats = primaryStats,
                primarySource = primarySource
            }
        end
    end
    return nil, "specialisation absente du catalogue " .. tostring(classToken)
        .. " (index=" .. tostring(specializationIndex)
        .. ", id=" .. tostring(specializationID)
        .. ", nom=" .. tostring(specializationName or "inconnu") .. ")"
end

local function SpecializationProfileKey(specialization)
    return tostring(specialization.className or "") .. ":" .. tostring(specialization.specName or "")
end

local function FindPublicPreset(specialization)
    if type(CoALootProfiles) ~= "table" or type(CoALootProfiles.weights) ~= "table" then return nil end
    local requested = SpecializationProfileKey(specialization)
    local resolved = CoALootProfiles.aliases and CoALootProfiles.aliases[requested] or requested
    if CoALootProfiles.weights[resolved] then
        return CoALootProfiles.weights[resolved],
            CoALootProfiles.weaponRules and CoALootProfiles.weaponRules[resolved] or nil,
            resolved
    end

    -- Repli insensible a la casse pour les clients localises partiellement.
    local key, value
    for key, value in pairs(CoALootProfiles.weights) do
        if Lower(key) == Lower(resolved) then
            return value, CoALootProfiles.weaponRules and CoALootProfiles.weaponRules[key] or nil, key
        end
    end
    return nil
end

local function PublicWeights(specialization)
    local preset, weaponRule, presetKey = FindPublicPreset(specialization)
    if not preset then return nil end

    local effectivePreset = {}
    local presetName, presetValue
    for presetName, presetValue in pairs(preset) do effectivePreset[presetName] = presetValue end
    -- Power of Yogg-Saron, qui justifie Crit=3, est la passive Heretic niveau 50.
    -- Avant son obtention on conserve un poids de critique standard et prudent.
    local playerLevel = UnitLevel and tonumber(UnitLevel("player")) or 60
    if presetKey == "Cultist:Heretic" and playerLevel < 50 then effectivePreset.crit = 0.8 end

    local weights = {}
    local acceptedPrimaries = {}
    local shortName, value, _, statKey
    for shortName, value in pairs(effectivePreset) do
        local statKeys = PROFILE_STAT_KEYS[shortName]
        if statKeys and tonumber(value) and tonumber(value) > 0 then
            for _, statKey in ipairs(statKeys) do
                -- wdps et rdps partagent la cle DPS ; ne jamais les additionner.
                weights[statKey] = math.max(weights[statKey] or 0, tonumber(value))
            end
        end
    end
    for _, statKey in ipairs(PRIMARY_STATS) do
        if (weights[statKey] or 0) > 0 then acceptedPrimaries[statKey] = true end
    end

    local physical = (effectivePreset.ap or 0) > 0 or (effectivePreset.rap or 0) > 0
        or (effectivePreset.wdps or 0) > 0 or (effectivePreset.rdps or 0) > 0
        or (effectivePreset.arp or 0) > 0 or (effectivePreset.expertise or 0) > 0
    local caster = (effectivePreset.sp or 0) > 0 or (effectivePreset.heal or 0) > 0
    local customKey, customValue
    for customKey, customValue in pairs(CoALootDeciderDB.customWeights or {}) do
        if weights[customKey] and weights[customKey] > 0 then
            weights[customKey] = tonumber(customValue) or weights[customKey]
        end
    end
    return weights, acceptedPrimaries, physical, caster, weaponRule, presetKey
end

local function StrictWeights(specialization)
    local specInfo = specialization.specInfo
    local acceptedPrimaries = {}
    local _, primaryName
    for _, primaryName in ipairs(specialization.primaryStats) do
        local statKey = PRIMARY_STAT_KEYS[primaryName]
        if statKey then acceptedPrimaries[statKey] = true end
    end
    if not next(acceptedPrimaries) then
        return nil, nil, nil, nil, "PrimaryStats absentes pour " .. specialization.className .. " - " .. specialization.specName
    end

    local physical = specInfo.MeleeDPS or specInfo.RangedDPS or false
    local caster = specInfo.CasterDPS or specInfo.Healer or false
    if specInfo.Tank or specInfo.Support then
        if acceptedPrimaries.ITEM_MOD_INTELLECT_SHORT then caster = true end
        if acceptedPrimaries.ITEM_MOD_STRENGTH_SHORT or acceptedPrimaries.ITEM_MOD_AGILITY_SHORT then physical = true end
    end
    if not physical and not caster then
        caster = (acceptedPrimaries.ITEM_MOD_INTELLECT_SHORT
            or acceptedPrimaries.ITEM_MOD_SPIRIT_SHORT) and true or false
        physical = (acceptedPrimaries.ITEM_MOD_STRENGTH_SHORT or acceptedPrimaries.ITEM_MOD_AGILITY_SHORT) and true or false
    end

    local weights = {
        ITEM_MOD_STRENGTH_SHORT = acceptedPrimaries.ITEM_MOD_STRENGTH_SHORT and 2.00 or 0,
        ITEM_MOD_AGILITY_SHORT = acceptedPrimaries.ITEM_MOD_AGILITY_SHORT and 2.00 or 0,
        ITEM_MOD_INTELLECT_SHORT = acceptedPrimaries.ITEM_MOD_INTELLECT_SHORT and 2.00 or 0,
        ITEM_MOD_SPIRIT_SHORT = acceptedPrimaries.ITEM_MOD_SPIRIT_SHORT and 2.00
            or (caster and 0.25 or 0),
        ITEM_MOD_STAMINA_SHORT = specInfo.Tank and 0.65 or 0.20,
        ITEM_MOD_SPELL_POWER_SHORT = caster and 1.00 or 0,
        ITEM_MOD_HEALING_DONE_SHORT = specInfo.Healer and 1.00 or (caster and 0.55 or 0),
        ITEM_MOD_ATTACK_POWER_SHORT = physical and 0.50 or 0,
        ITEM_MOD_RANGED_ATTACK_POWER_SHORT = specInfo.RangedDPS and 0.50 or 0,
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = physical and 0.50 or 0,
        ITEM_MOD_HIT_RATING_SHORT = specInfo.Healer and 0 or 0.80,
        ITEM_MOD_CRIT_RATING_SHORT = 0.80,
        ITEM_MOD_HASTE_RATING_SHORT = 0.80,
        ITEM_MOD_EXPERTISE_RATING_SHORT = physical and 0.80 or 0,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = physical and 0.80 or 0,
        ITEM_MOD_SPELL_PENETRATION_SHORT = caster and not specInfo.Healer and 0.45 or 0,
        ITEM_MOD_MANA_REGENERATION_SHORT = caster and 0.45 or 0,
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = specInfo.Tank and 0.85 or 0,
        ITEM_MOD_DODGE_RATING_SHORT = specInfo.Tank and 0.85 or 0,
        ITEM_MOD_PARRY_RATING_SHORT = specInfo.Tank and 0.85 or 0,
        ITEM_MOD_BLOCK_RATING_SHORT = specInfo.Tank and 0.75 or 0,
        ITEM_MOD_BLOCK_VALUE_SHORT = specInfo.Tank and 0.55 or 0,
        ITEM_MOD_RESILIENCE_RATING_SHORT = 0,
        ITEM_MOD_MANA_SHORT = caster and 0.03 or 0,
        ITEM_MOD_HEALTH_SHORT = 0.03,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 3.00,
        RESISTANCE0_NAME = specInfo.Tank and 0.015 or 0.005
    }
    local customKey, customValue
    for customKey, customValue in pairs(CoALootDeciderDB.customWeights or {}) do
        -- Une surcharge ne peut jamais reactiver une famille interdite par CoA.
        if weights[customKey] and weights[customKey] > 0 then
            weights[customKey] = tonumber(customValue) or weights[customKey]
        end
    end
    return weights, acceptedPrimaries, physical, caster
end

local function ScanEquipment()
    local equippedStats = {}
    local items = {}
    local slot
    for slot = 1, 19 do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil
        if link then
            local data = ItemData(link)
            if data then
                items[slot] = data
                AddStats(equippedStats, data.stats)
            end
        end
    end

    local specialization, specializationError = ResolveActiveSpecialization()
    if not specialization then
        profile = {
            valid = false,
            items = items,
            equippedStats = equippedStats,
            error = specializationError,
            specName = "Non detectee",
            scannedAt = GetTime and GetTime() or 0
        }
        return profile
    end

    local weights, acceptedPrimaries, physical, caster, weaponRule, presetKey = PublicWeights(specialization)
    local strictError = nil
    local weightSource = "BisBeard/CoA Build Hub " .. tostring(CoALootProfiles and CoALootProfiles.sourceDate or "")
    if not weights then
        weights, acceptedPrimaries, physical, caster, strictError = StrictWeights(specialization)
        weightSource = "repli catalogue CoA"
    end
    if not weights then
        profile = {
            valid = false,
            items = items,
            equippedStats = equippedStats,
            error = strictError,
            className = specialization.className,
            specName = specialization.specName,
            scannedAt = GetTime and GetTime() or 0
        }
        return profile
    end

    local adaptive = nil
    if type(CoALootAdaptation) == "table" and type(CoALootAdaptation.Scan) == "function" then
        weights, weaponRule, adaptive = CoALootAdaptation.Scan(
            specialization.className, specialization.specName, presetKey,
            weights, weaponRule
        )
        weightSource = weightSource .. " + niveau/spellbook/talents CoA"
    end

    profile = {
        valid = true,
        items = items,
        equippedStats = equippedStats,
        weights = weights,
        acceptedPrimaries = acceptedPrimaries,
        physical = physical,
        caster = caster,
        role = specialization.specInfo.Healer and "HEALER"
            or (specialization.specInfo.Tank and "TANK")
            or (specialization.specInfo.Support and "SUPPORT")
            or "DAMAGE",
        className = specialization.className,
        classToken = specialization.classToken,
        specializationID = specialization.specializationID,
        specName = specialization.specName,
        primarySource = specialization.primarySource,
        weightSource = weightSource,
        presetKey = presetKey,
        weaponRule = weaponRule,
        adaptive = adaptive,
        level = PlayerLevel(),
        isCultistHeretic = presetKey == "Cultist:Heretic",
        isBloodmageSanguine = presetKey == "Bloodmage:Sanguine",
        tuningLabel = presetKey == "Cultist:Heretic" and "Heretic CAC donjon"
            or (presetKey == "Bloodmage:Sanguine" and "Bloodmage Sanguine DPS donjon" or nil),
        scannedAt = GetTime and GetTime() or 0
    }
    profile.bagItems = ScanBagItems()
    return profile
end

local function ThresholdKey(targetProfile)
    if not targetProfile or not targetProfile.valid then return nil end
    local classPart = targetProfile.classToken or targetProfile.className
    local specPart = targetProfile.specializationID or targetProfile.specName
    if not classPart or not specPart then return nil end
    return tostring(classPart) .. ":" .. tostring(specPart)
end

local function ActiveThreshold()
    local globalThreshold = tonumber(CoALootDeciderDB.threshold) or 5
    if not profile or not profile.valid then return globalThreshold, "global" end

    local key = ThresholdKey(profile)
    local specThreshold = key and tonumber(CoALootDeciderDB.thresholdsBySpec[key]) or nil
    if specThreshold then return specThreshold, "specialisation" end

    if (profile.isCultistHeretic or profile.isBloodmageSanguine) and (profile.level or PlayerLevel()) < 60 then
        return 3, "profil leveling"
    end

    local classThreshold = DEFAULT_CLASS_THRESHOLDS[profile.classToken]
    if not classThreshold and Lower(profile.className) == "pyromancer" then classThreshold = 10 end
    if classThreshold then return classThreshold, "classe" end
    return globalThreshold, "global"
end

local FIT_STAT_KEYS = {
    "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_SPELL_POWER_SHORT",
    "ITEM_MOD_HEALING_DONE_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT",
    "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_HIT_RATING_SHORT",
    "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_EXPERTISE_RATING_SHORT", "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    "ITEM_MOD_SPELL_PENETRATION_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT",
    "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT",
    "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT",
    "ITEM_MOD_BLOCK_VALUE_SHORT", "ITEM_MOD_RESILIENCE_RATING_SHORT",
    "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
}

local function IsWeaponEquipLoc(equipLoc)
    return equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND"
        or equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
end

local function FitTier(score)
    score = tonumber(score) or 0
    if score >= 85 then return "OPTIMAL" end
    if score >= 70 then return "EXCELLENT" end
    if score >= 55 then return "BON" end
    if score >= 35 then return "TEMPORAIRE" end
    return "MAUVAIS"
end

local function FitScore(data)
    if not data or not profile or not profile.weights then return 0 end
    local weapon = IsWeaponEquipLoc(data.equipLoc)
    local maxWeight = 0
    local _, key
    for _, key in ipairs(FIT_STAT_KEYS) do
        if key ~= "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" or weapon then
            maxWeight = math.max(maxWeight, math.max(0, tonumber(profile.weights[key]) or 0))
        end
    end
    if maxWeight <= 0 then return 0 end

    local totalBudget, usefulBudget = 0, 0
    for _, key in ipairs(FIT_STAT_KEYS) do
        if key ~= "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" or weapon then
            local value = math.max(0, StatValue(data.stats, key))
            if value > 0 then
                totalBudget = totalBudget + value
                local weight = math.max(0, tonumber(profile.weights[key]) or 0)
                usefulBudget = usefulBudget + value * math.min(1, weight / maxWeight)
            end
        end
    end
    if totalBudget <= 0 then return 0 end
    local score = 100 * usefulBudget / totalBudget

    if profile.isCultistHeretic then
        if data.classID == 4 then
            if data.subClassID == 4 then score = score + 8
            elseif data.subClassID == 3 then score = score + 4
            elseif data.subClassID == 2 then score = score + 2 end
        end
        if weapon then
            if data.equipLoc == "INVTYPE_2HWEAPON" then score = score + 10 else score = score - 25 end
            if tonumber(data.weaponSpeed) and data.weaponSpeed >= 3.2 then score = score + 3 end
        end
        if StatValue(data.stats, "ITEM_MOD_CRIT_RATING_SHORT") > 0 then score = score + 8 end
        if StatValue(data.stats, "ITEM_MOD_STRENGTH_SHORT") > 0
            or StatValue(data.stats, "ITEM_MOD_ATTACK_POWER_SHORT") > 0 then score = score + 6 end
    elseif profile.isBloodmageSanguine then
        if data.classID == 4 then
            if data.subClassID == 2 then score = score + 7
            elseif data.subClassID == 1 then score = score + 1 end
        end
        if StatValue(data.stats, "ITEM_MOD_SPELL_POWER_SHORT") > 0 then score = score + 8 end
        if StatValue(data.stats, "ITEM_MOD_SPIRIT_SHORT") > 0 then score = score + 6 end
        if StatValue(data.stats, "ITEM_MOD_STAMINA_SHORT") > 0 then score = score + 5 end
    end

    return Round(math.max(0, math.min(100, score)), 0)
end

local function RequiredUpgradeForFit(fitScore)
    local baseThreshold = select(1, ActiveThreshold())
    local level = profile and profile.level or PlayerLevel()
    if level < 60 then
        if fitScore >= 70 then return baseThreshold end
        if fitScore >= 55 then return math.max(baseThreshold, 5) end
        if fitScore >= 35 then return math.max(baseThreshold, 10) end
        return math.max(baseThreshold, 20)
    end
    if fitScore >= 85 then return baseThreshold end
    if fitScore >= 70 then return math.max(baseThreshold, 8) end
    if fitScore >= 55 then return math.max(baseThreshold, 12) end
    if fitScore >= 40 then return math.max(baseThreshold, 20) end
    return 999
end

local function ScoreItem(data)
    if not data or not profile then return 0 end
    local score = data.itemLevel * CoALootDeciderDB.itemLevelWeight
    local key, value
    for key, value in pairs(data.stats or {}) do
        score = score + (tonumber(value) or 0) * (profile.weights[key] or 0)
    end
    local weaponRule = profile.weaponRule
    if weaponRule and data.weaponSpeed then
        local speedWeight = tonumber(weaponRule.speedWeight) or 0
        if weaponRule.speed == "slow" then
            score = score + data.weaponSpeed * speedWeight
        elseif weaponRule.speed == "fast" then
            score = score + math.max(0, 4 - data.weaponSpeed) * speedWeight
        end
    end
    if weaponRule and weaponRule.preferTwoHand and data.equipLoc == "INVTYPE_2HWEAPON" then
        score = score + 30
    end
    if weaponRule and weaponRule.preferDualWield
        and (data.equipLoc == "INVTYPE_WEAPON" or data.equipLoc == "INVTYPE_WEAPONMAINHAND"
            or data.equipLoc == "INVTYPE_WEAPONOFFHAND")
    then
        score = score + 12
    end
    if weaponRule and weaponRule.preferShield and data.equipLoc == "INVTYPE_SHIELD" then
        score = score + 24
    end
    -- Les bonus d'armure restent de simples departageurs. Les poids EP publics
    -- conservent toute la priorite dans le score principal.
    if profile.isCultistHeretic and data.classID == 4 then
        local armorBonus = { [1] = 0, [2] = 0.35, [3] = 0.70, [4] = 1.10 }
        score = score + (armorBonus[data.subClassID] or 0)
    elseif profile.isBloodmageSanguine and data.classID == 4 then
        local armorBonus = { [1] = 0, [2] = 0.80 }
        score = score + (armorBonus[data.subClassID] or 0)
    end
    return score
end

local function CompatibilityProblem(data)
    if not profile or not profile.valid then
        return profile and profile.error or "profil CoA non detecte"
    end

    if profile.isCultistHeretic then
        if data.equipLoc == "INVTYPE_WEAPON"
            or data.equipLoc == "INVTYPE_WEAPONMAINHAND"
            or data.equipLoc == "INVTYPE_WEAPONOFFHAND"
            or data.equipLoc == "INVTYPE_SHIELD"
            or data.equipLoc == "INVTYPE_HOLDABLE"
        then
            return "Heretic CAC : arme 2 mains requise par le build"
        end
        local useful = StatValue(data.stats, "ITEM_MOD_STRENGTH_SHORT")
            + StatValue(data.stats, "ITEM_MOD_INTELLECT_SHORT")
            + StatValue(data.stats, "ITEM_MOD_CRIT_RATING_SHORT")
            + StatValue(data.stats, "ITEM_MOD_ATTACK_POWER_SHORT")
            + StatValue(data.stats, "ITEM_MOD_SPELL_POWER_SHORT")
            + StatValue(data.stats, "ITEM_MOD_HASTE_RATING_SHORT")
            + StatValue(data.stats, "ITEM_MOD_DAMAGE_PER_SECOND_SHORT")
        if useful <= 0 and StatValue(data.stats, "ITEM_MOD_AGILITY_SHORT") > 0 then
            return "objet AGI sans stat utile au Heretic CAC"
        end
        return nil
    end

    if profile.isBloodmageSanguine then
        if data.classID == 4 and (data.subClassID == 3 or data.subClassID == 4) then
            return "Bloodmage Sanguine : cuir/tissu uniquement, pas maille/plaque"
        end
        if data.equipLoc == "INVTYPE_SHIELD" then
            return "Bloodmage Sanguine : bouclier non adapte au profil DPS caster"
        end
        local useful = StatValue(data.stats, "ITEM_MOD_SPELL_POWER_SHORT")
            + StatValue(data.stats, "ITEM_MOD_STAMINA_SHORT")
            + StatValue(data.stats, "ITEM_MOD_SPIRIT_SHORT")
            + StatValue(data.stats, "ITEM_MOD_CRIT_RATING_SHORT")
            + StatValue(data.stats, "ITEM_MOD_HASTE_RATING_SHORT")
            + StatValue(data.stats, "ITEM_MOD_HIT_RATING_SHORT")
        local physicalOnly = StatValue(data.stats, "ITEM_MOD_STRENGTH_SHORT")
            + StatValue(data.stats, "ITEM_MOD_AGILITY_SHORT")
            + StatValue(data.stats, "ITEM_MOD_ATTACK_POWER_SHORT")
        if useful <= 0 and physicalOnly > 0 then
            return "objet physique sans stats utiles au Sanguine"
        end
        return nil
    end

    local _, key
    for _, key in ipairs(PRIMARY_STATS) do
        if StatValue(data.stats, key) > 0 and (profile.weights[key] or 0) <= 0 then
            return (DISPLAY_STATS[key] or key) .. " interdite pour " .. profile.className .. " - " .. profile.specName
        end
    end

    if not profile.caster then
        for _, key in ipairs(SPELL_POWER_STATS) do
            if StatValue(data.stats, key) > 0 then
                return "puissance des sorts interdite pour cette specialisation non-caster"
            end
        end
    end
    if not profile.physical then
        for _, key in ipairs(PHYSICAL_POWER_STATS) do
            if StatValue(data.stats, key) > 0 then
                return "puissance physique interdite pour cette specialisation caster"
            end
        end
    end
    return nil
end

local function EquipFamily(equipLoc)
    if equipLoc == "INVTYPE_CHEST" or equipLoc == "INVTYPE_ROBE" then return "CHEST" end
    if equipLoc == "INVTYPE_FINGER" then return "FINGER" end
    if equipLoc == "INVTYPE_TRINKET" then return "TRINKET" end
    if equipLoc == "INVTYPE_2HWEAPON" then return "2HWEAPON" end
    if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then return "MAINWEAPON" end
    if equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_HOLDABLE"
        or equipLoc == "INVTYPE_SHIELD" then return "OFFHAND" end
    return equipLoc
end

local function SameOwnedSlot(candidate, owned)
    return candidate and owned and EquipFamily(candidate.equipLoc) == EquipFamily(owned.equipLoc)
end

local function OwnedBaselineFor(candidate, equippedScore, equippedLevel, equippedLink, equippedData, excludeOwnedCopy)
    local pool = {}
    local function AddOwned(data, source)
        if not data or not SameOwnedSlot(candidate, data) then return end
        if excludeOwnedCopy and data.link == candidate.link and source == "sac" then return end
        table.insert(pool, { data = data, score = ScoreItem(data), source = source })
    end

    local slot
    for slot = 1, 19 do AddOwned(profile.items[slot], "equipe") end
    local _, bagItem
    for _, bagItem in ipairs(profile.bagItems or {}) do AddOwned(bagItem, "sac") end
    table.sort(pool, function(a, b) return (a.score or 0) > (b.score or 0) end)

    -- Deux bagues/bijoux peuvent être équipés : la référence est le second
    -- meilleur objet déjà possédé, donc celui que le candidat remplacerait.
    local baselineIndex = (candidate.equipLoc == "INVTYPE_FINGER"
        or candidate.equipLoc == "INVTYPE_TRINKET") and 2 or 1
    local baseline = pool[baselineIndex] or pool[1]
    if baseline then
        -- Une 2M doit aussi battre le duo 1M + main gauche actuellement
        -- équipe, même si ce duo n'appartient pas à la famille 2M du pool.
        if (tonumber(equippedScore) or 0) > (baseline.score or 0) then
            return equippedScore, equippedLevel, equippedLink, equippedData,
                equippedData and "equipe" or nil
        end
        return baseline.score or 0, baseline.data.itemLevel or 0, baseline.data.link,
            baseline.data, baseline.source
    end
    return tonumber(equippedScore) or 0, tonumber(equippedLevel) or 0,
        equippedLink, equippedData, equippedData and "equipe" or nil
end

local function ComparisonFor(data)
    local slots = EQUIP_SLOTS[data.equipLoc]
    if not slots then return nil, nil, "type d'objet non equipable" end

    if data.equipLoc == "INVTYPE_2HWEAPON" then
        local main = profile.items[16]
        local off = profile.items[17]
        local combined = ScoreItem(main) + ScoreItem(off)
        local currentLevel = math.max(main and main.itemLevel or 0, off and off.itemLevel or 0)
        local combinedStats = {}
        AddStats(combinedStats, main and main.stats)
        AddStats(combinedStats, off and off.stats)
        local warning = (main and HasUnscoredEffect(main.link)) or (off and HasUnscoredEffect(off.link))
        return combined, currentLevel, main and main.link or nil, combinedStats,
            warning and "l'equipement remplace contient un effet non chiffrable" or nil, main
    end

    -- Une arme a une main ne remplit pas gratuitement la main gauche lorsqu'une
    -- arme 2M est equipee. Elle doit d'abord battre la configuration 2M active.
    if data.equipLoc == "INVTYPE_WEAPON"
        and profile.items[16]
        and profile.items[16].equipLoc == "INVTYPE_2HWEAPON"
    then
        local main = profile.items[16]
        return ScoreItem(main), main.itemLevel or 0, main.link, main.stats or {},
            HasUnscoredEffect(main.link) and "l'arme 2M equipee contient un effet non chiffrable" or nil, main
    end

    if (data.equipLoc == "INVTYPE_WEAPONOFFHAND"
        or data.equipLoc == "INVTYPE_SHIELD"
        or data.equipLoc == "INVTYPE_HOLDABLE")
        and profile.items[16]
        and profile.items[16].equipLoc == "INVTYPE_2HWEAPON"
    then
        local main = profile.items[16]
        return ScoreItem(main), main.itemLevel or 0, main.link, main.stats or {},
            "necessite aussi une arme a une main compatible", main
    end

    if data.equipLoc == "INVTYPE_WEAPON" and not profile.items[17] then
        local main = profile.items[16]
        return ScoreItem(main), main and main.itemLevel or 0, main and main.link or nil,
            main and main.stats or {}, main and HasUnscoredEffect(main.link)
                and "l'equipement remplace contient un effet non chiffrable" or nil, main
    end

    local lowestScore, lowestLevel, lowestLink = nil, nil, nil
    local _, slot
    for _, slot in ipairs(slots) do
        local current = profile.items[slot]
        local score = ScoreItem(current)
        if lowestScore == nil or score < lowestScore then
            lowestScore = score
            lowestLevel = current and current.itemLevel or 0
            lowestLink = current and current.link or nil
        end
    end
    local currentData = lowestLink and ItemData(lowestLink) or nil
    return lowestScore or 0, lowestLevel or 0, lowestLink, currentData and currentData.stats or {},
        lowestLink and HasUnscoredEffect(lowestLink)
            and "l'equipement remplace contient un effet non chiffrable" or nil, currentData
end

local function AnalyzeItem(itemLink, refreshEquipment, excludeOwnedCopy)
    if refreshEquipment ~= false or not profile then profile = ScanEquipment() end
    if not profile.valid then return nil, profile.error end
    local candidate = ItemData(itemLink)
    if not candidate then return nil, "informations d'objet indisponibles" end
    if IsLockedChest(candidate) then
        local wanted = CoALootDeciderDB.needLockedChests ~= false
        return {
            need = wanted,
            candidate = candidate,
            reason = wanted
                and "coffre verrouillé : NEED, ou CUPIDITÉ si NEED est indisponible"
                or "coffre verrouillé : règle de récupération désactivée",
            confidence = "haute",
            nonEquipable = true,
            lockedChest = true,
        }
    end
    if not EQUIP_SLOTS[candidate.equipLoc] then
        return {
            need = false,
            candidate = candidate,
            reason = "objet non equipable",
            confidence = "haute",
            nonEquipable = true
        }
    end
    local compatibilityProblem = CompatibilityProblem(candidate)
    if compatibilityProblem then
        return { need = false, candidate = candidate, reason = compatibilityProblem, confidence = "haute" }
    end

    local currentScore, currentLevel, currentLinkOrReason, currentStats, comparisonWarning, currentData = ComparisonFor(candidate)
    if currentScore == nil then
        return { need = false, candidate = candidate, reason = currentLinkOrReason or "comparaison impossible", confidence = "basse" }
    end

    local currentSource
    currentScore, currentLevel, currentLinkOrReason, currentData, currentSource = OwnedBaselineFor(
        candidate, currentScore, currentLevel, currentLinkOrReason, currentData, excludeOwnedCopy
    )
    currentStats = currentData and currentData.stats or currentStats or {}
    if currentData and HasUnscoredEffect(currentData.link) then
        comparisonWarning = "le meilleur objet possede contient un effet non chiffrable"
    end

    local candidateScore = ScoreItem(candidate)
    local delta = candidateScore - currentScore
    local percent = currentScore > 0 and delta / currentScore * 100 or (candidateScore > 0 and 100 or 0)
    local threshold, thresholdSource = ActiveThreshold()
    local fitScore = FitScore(candidate)
    local currentFitScore = currentData and FitScore(currentData) or 0
    local effectiveThreshold = RequiredUpgradeForFit(fitScore)
    local minimum = math.max(1, currentScore * (effectiveThreshold / 100))
    local need = currentScore <= 0 and candidateScore > 0 or delta >= minimum
    local manualReason = comparisonWarning
    if not manualReason and candidate.equipLoc == "INVTYPE_TRINKET" then
        manualReason = "bijou : effet non chiffrable"
    elseif not manualReason and HasUnscoredEffect(candidate.link) then
        manualReason = "effet Equipe/Utiliser non chiffrable"
    elseif not manualReason and not next(candidate.stats or {}) then
        manualReason = "aucune statistique chiffrable"
    end
    local reason
    if manualReason then
        reason = manualReason .. " : verification manuelle recommandee"
    elseif currentScore <= 0 and candidateScore > 0 then
        reason = "aucun meilleur objet possede ; adequation " .. fitScore .. "/100"
    elseif need then
        reason = "+" .. Round(percent, 1) .. "% vs " .. (currentSource == "sac" and "meilleur en sac" or "equipe")
            .. " ; adequation " .. fitScore .. "/100 " .. FitTier(fitScore)
            .. " ; seuil " .. effectiveThreshold .. "%"
    else
        reason = Round(percent, 1) .. "% vs " .. (currentSource == "sac" and "meilleur en sac" or "equipe")
            .. " ; adequation " .. fitScore .. "/100 " .. FitTier(fitScore)
            .. " ; seuil " .. effectiveThreshold .. "%"
    end

    return {
        need = need,
        candidate = candidate,
        candidateScore = candidateScore,
        currentScore = currentScore,
        currentLevel = currentLevel,
        currentLink = currentLinkOrReason,
        currentSource = currentSource,
        currentStats = currentStats or {},
        percent = percent,
        threshold = threshold,
        effectiveThreshold = effectiveThreshold,
        thresholdSource = thresholdSource,
        fitScore = fitScore,
        currentFitScore = currentFitScore,
        fitTier = FitTier(fitScore),
        reason = reason,
        manual = manualReason and true or false,
        confidence = manualReason and "moyenne" or "haute"
    }
end

local function EvaluateItem(itemLink)
    local analysis, errorMessage = AnalyzeItem(itemLink, true)
    if analysis and analysis.manual then return nil, analysis.reason end
    return analysis, errorMessage
end

-- API interne stable pour la couche universelle (sacs, marchands, quetes,
-- butin, liens de chat et fenetres tierces). Aucune dependance externe.
CoALootDeciderAPI = {
    AnalyzeItem = AnalyzeItem,
    RefreshProfile = ScanEquipment,
    GetProfile = function() return profile end,
    GetAdaptiveBuild = function() return profile and profile.adaptive or nil end,
    GetDisplayStats = function() return DISPLAY_STATS end,
    ScoreItem = ScoreItem,
    Round = Round
}

local banner = CreateFrame("Frame", "CoALootDeciderBanner", UIParent)
banner:SetWidth(400)
banner:SetHeight(70)
banner:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -170)
banner:SetFrameStrata("DIALOG")
banner:SetMovable(true)
banner:EnableMouse(true)
banner:RegisterForDrag("LeftButton")
if banner.SetClampedToScreen then banner:SetClampedToScreen(true) end
banner:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
banner:SetBackdropColor(0.01, 0.025, 0.045, 0.94)
banner:SetBackdropBorderColor(0.18, 0.45, 0.62, 0.92)
banner:Hide()

local function ApplyBannerPosition()
    local saved = CoALootDeciderDB and CoALootDeciderDB.bannerPosition or nil
    if not saved then return end
    banner:ClearAllPoints()
    banner:SetPoint(saved.point or "TOPRIGHT", UIParent,
        saved.relativePoint or saved.point or "TOPRIGHT",
        tonumber(saved.x) or -24, tonumber(saved.y) or -170)
end

banner:SetScript("OnDragStart", function(self) self:StartMoving() end)
banner:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not CoALootDeciderDB then return end
    local point, _, relativePoint, x, y = self:GetPoint()
    CoALootDeciderDB.bannerPosition = {
        point = point, relativePoint = relativePoint, x = x, y = y
    }
end)

banner.background = banner:CreateTexture(nil, "BACKGROUND")
banner.background:SetAllPoints(banner)
banner.background:SetTexture(0.01, 0.025, 0.045, 0.78)

banner.accent = banner:CreateTexture(nil, "BORDER")
banner.accent:SetWidth(4)
banner.accent:SetPoint("TOPLEFT", banner, "TOPLEFT", 4, -5)
banner.accent:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 4, 5)
banner.accent:SetTexture("Interface\\Buttons\\WHITE8X8")

banner.icon = banner:CreateTexture(nil, "ARTWORK")
banner.icon:SetWidth(44)
banner.icon:SetHeight(44)
banner.icon:SetPoint("LEFT", banner, "LEFT", 14, 0)
banner.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

banner.verdict = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
banner.verdict:SetPoint("TOPLEFT", banner.icon, "TOPRIGHT", 12, -2)
banner.verdict:SetWidth(320)
banner.verdict:SetJustifyH("LEFT")

banner.detail = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
banner.detail:SetPoint("TOPLEFT", banner.verdict, "BOTTOMLEFT", 0, -5)
banner.detail:SetWidth(320)
banner.detail:SetJustifyH("LEFT")

banner.expires = 0
banner:SetScript("OnUpdate", function(self)
    if self.expires > 0 and GetTime() >= self.expires then self:Hide() end
end)

local function ShowDecision(decision, automatic)
    local candidate = decision.candidate or {}
    banner.icon:SetTexture(candidate.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if decision.lockedChest and decision.rollDecision == "GREED" then
        banner.accent:SetVertexColor(0.25, 0.65, 1.00, 1)
        banner.verdict:SetText("|cff55aaff+ CUPIDITÉ COFFRE|r  " .. (candidate.link or candidate.name or "Coffre"))
    elseif decision.lockedChest and decision.need then
        banner.accent:SetVertexColor(0.15, 1.00, 0.25, 1)
        banner.verdict:SetText("|cff3cff52+ NEED COFFRE|r  " .. (candidate.link or candidate.name or "Coffre"))
    elseif decision.need then
        local percent = decision.percent and ((decision.percent > 0 and "+" or "") .. Round(decision.percent, 0) .. "%") or ""
        banner.accent:SetVertexColor(0.15, 1.00, 0.25, 1)
        banner.verdict:SetText("|cff3cff52+ AMELIORATION " .. percent .. "|r  " .. (candidate.link or candidate.name or "Objet"))
    else
        local percent = decision.percent and (Round(decision.percent, 0) .. "%") or ""
        banner.accent:SetVertexColor(1.00, 0.24, 0.24, 1)
        banner.verdict:SetText("|cffff5b5b- PASS " .. percent .. "|r  " .. (candidate.link or candidate.name or "Objet"))
    end
    banner.detail:SetText((automatic and "Jet automatique - " or "Conseil - ") .. (decision.reason or "raison inconnue"))
    banner.expires = GetTime() + 6
    banner:Show()
end

local function ShowManual(itemLink, itemName, reason)
    local data = ItemData(itemLink)
    banner.icon:SetTexture(data and data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    banner.accent:SetVertexColor(1.00, 0.75, 0.10, 1)
    banner.verdict:SetText("|cffffcc33? CHOIX MANUEL|r  " .. (itemLink or itemName or "Objet"))
    banner.detail:SetText(reason or "evaluation stricte impossible")
    banner.expires = GetTime() + 10
    banner:Show()
end

local function AddHistory(rollID, decision, automatic)
    local history = CoALootDeciderDB.history
    table.insert(history, 1, {
        at = time and time() or 0,
        rollID = rollID,
        itemLink = decision.candidate and decision.candidate.link or nil,
        itemName = decision.candidate and decision.candidate.name or "Objet inconnu",
        decision = decision.rollDecision or (decision.need and "NEED" or "PASS"),
        reason = decision.reason,
        percent = decision.percent,
        confidence = decision.confidence,
        fitScore = decision.fitScore,
        automatic = automatic and true or false
    })
    while #history > HISTORY_LIMIT do table.remove(history) end
end

local function AddManualHistory(rollID, itemLink, itemName, reason)
    local history = CoALootDeciderDB.history
    table.insert(history, 1, {
        at = time and time() or 0,
        rollID = rollID,
        itemLink = itemLink,
        itemName = itemName or "Objet inconnu",
        decision = "MANUEL",
        reason = reason,
        confidence = "basse",
        automatic = false,
    })
    while #history > HISTORY_LIMIT do table.remove(history) end
end

local function ApplyRoll(rollID, decision, canNeed, canGreed)
    local rollType
    if decision.lockedChest and decision.need and not canNeed and canGreed then
        rollType = ROLL_GREED
        decision.rollDecision = "GREED"
        decision.reason = "coffre verrouillé : NEED indisponible, jet CUPIDITÉ effectué"
    elseif decision.lockedChest and decision.need and not canNeed then
        decision.need = false
        decision.reason = "coffre verrouillé : NEED et CUPIDITÉ indisponibles pour ce jet"
    elseif decision.need and not canNeed then
        decision.need = false
        decision.reason = "NEED indisponible pour cet objet"
    end
    if not rollType then rollType = decision.need and ROLL_NEED or ROLL_PASS end
    if not decision.rollDecision then decision.rollDecision = decision.need and "NEED" or "PASS" end
    local automatic = CoALootDeciderDB.autoRoll and RollOnLoot ~= nil
    ShowDecision(decision, automatic)
    AddHistory(rollID, decision, automatic)
    Chat(tostring(decision.rollDecision) .. " " .. (decision.candidate.link or decision.candidate.name or "objet") .. " - " .. decision.reason)

    if automatic then
        confirmations[rollID] = { rollType = rollType, expires = GetTime() + 15 }
        local ok, errorMessage = pcall(RollOnLoot, rollID, rollType)
        if not ok then Chat("le client a refuse le jet automatique : " .. tostring(errorMessage)) end
    end
end

local function TryEvaluateRoll(rollID)
    local state = pendingRolls[rollID]
    if not state then return true end
    local itemLink = GetLootRollItemLink and GetLootRollItemLink(rollID) or nil
    local decision, errorMessage = EvaluateItem(itemLink)
    if not decision then
        state.lastError = errorMessage
        return false
    end

    local _, _, _, _, _, canNeed, canGreed = GetLootRollItemInfo(rollID)
    ApplyRoll(rollID, decision, canNeed, canGreed)
    pendingRolls[rollID] = nil
    return true
end

local function LeaveUnknownRoll(rollID, reason)
    local _, name = GetLootRollItemInfo(rollID)
    local itemLink = GetLootRollItemLink and GetLootRollItemLink(rollID) or nil
    reason = reason or "objet impossible a analyser dans le delai"
    ShowManual(itemLink, name, reason)
    AddManualHistory(rollID, itemLink, name, reason)
    Chat("aucun jet automatique pour " .. (itemLink or name or "objet") .. " : " .. tostring(reason))
    pendingRolls[rollID] = nil
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("SPELLS_CHANGED")
if eventFrame.RegisterEvent then
    pcall(eventFrame.RegisterEvent, eventFrame, "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT")
    pcall(eventFrame.RegisterEvent, eventFrame, "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED")
end
eventFrame:RegisterEvent("START_LOOT_ROLL")
eventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
eventFrame:RegisterEvent("CONFIRM_LOOT_ROLL")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDatabase()
        ApplyBannerPosition()
        ScanEquipment()
        if profile.valid then
            Chat("profil strict " .. profile.className .. " - " .. profile.specName .. " charge ; auto "
                .. (CoALootDeciderDB.autoRoll and "ACTIF" or "inactif") .. ". /cld status")
        else
            Chat("auto suspendu : " .. tostring(profile.error) .. ". /cld status")
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_LEVEL_UP"
        or event == "SPELLS_CHANGED"
        or event == "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT"
        or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED"
    then
        ScanEquipment()
    elseif event == "START_LOOT_ROLL" then
        local rollID = ...
        rollID = tonumber(rollID)
        if rollID then
            pendingRolls[rollID] = { startedAt = GetTime(), lastError = nil }
            TryEvaluateRoll(rollID)
        end
    elseif event == "CANCEL_LOOT_ROLL" then
        local rollID = tonumber(...)
        if rollID then
            pendingRolls[rollID] = nil
            confirmations[rollID] = nil
        end
    elseif event == "CONFIRM_LOOT_ROLL" then
        local rollID, rollType = ...
        rollID = tonumber(rollID)
        rollType = tonumber(rollType)
        local confirmation = rollID and confirmations[rollID] or nil
        if confirmation and confirmation.rollType == rollType and CoALootDeciderDB.autoConfirm and ConfirmLootRoll then
            pcall(ConfirmLootRoll, rollID, rollType)
            confirmations[rollID] = nil
        end
    end
end)

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    retryElapsed = retryElapsed + elapsed
    if retryElapsed < RETRY_INTERVAL then return end
    retryElapsed = 0

    local now = GetTime()
    local rollID, state
    for rollID, state in pairs(pendingRolls) do
        if now - state.startedAt >= ITEM_CACHE_TIMEOUT then
            LeaveUnknownRoll(rollID, state.lastError)
        else
            TryEvaluateRoll(rollID)
        end
    end

    local id, confirmation
    for id, confirmation in pairs(confirmations) do
        if now >= confirmation.expires then confirmations[id] = nil end
    end
end)

local function ProfileSummary()
    if not profile then ScanEquipment() end
    if not profile.valid then return "PROFIL INVALIDE : " .. tostring(profile.error) end
    local values = {}
    local _, key
    for _, key in ipairs(PRIMARY_STATS) do
        table.insert(values, (DISPLAY_STATS[key] or key) .. "=" .. Round(profile.weights[key], 2))
    end
    table.insert(values, "CRIT=" .. Round(profile.weights.ITEM_MOD_CRIT_RATING_SHORT, 2))
    table.insert(values, "HATE=" .. Round(profile.weights.ITEM_MOD_HASTE_RATING_SHORT, 2))
    table.insert(values, "TOUCH=" .. Round(profile.weights.ITEM_MOD_HIT_RATING_SHORT, 2))
    local adaptiveSummary = type(CoALootAdaptation) == "table"
        and type(CoALootAdaptation.Summary) == "function"
        and CoALootAdaptation.Summary(profile.adaptive) or "adaptation indisponible"
    return profile.className .. " - " .. profile.specName .. " [" .. profile.role .. "]"
        .. " | physique=" .. (profile.physical and "oui" or "non")
        .. ", caster=" .. (profile.caster and "oui" or "non")
        .. ", primaire=" .. tostring(profile.primarySource or "inconnue")
        .. ", poids=" .. tostring(profile.weightSource or "inconnu")
        .. " | " .. table.concat(values, ", ")
        .. " | " .. adaptiveSummary
end

local function PrintAdaptiveDetails()
    if not profile then ScanEquipment() end
    local adaptive = profile and profile.adaptive or nil
    if not adaptive then
        Chat("profil adaptatif indisponible")
        return
    end
    Chat("adaptation : " .. CoALootAdaptation.Summary(adaptive))
    Chat("arbre attendu : " .. tostring(adaptive.expectedTab or profile.specName)
        .. " ; source : " .. tostring(adaptive.source or "inconnue"))
    if adaptive.fallback then Chat("repli : " .. tostring(adaptive.fallback)) end
    if adaptive.error then Chat("limite : " .. tostring(adaptive.error)) end
    if adaptive.selectedNames and #adaptive.selectedNames > 0 then
        Chat("talents influencant le stuff : " .. table.concat(adaptive.selectedNames, ", "))
    else
        Chat("aucun talent selectionne ne modifie les priorites de stats de facon certaine")
    end
    if adaptive.changes and #adaptive.changes > 0 then
        Chat("ajustements : " .. table.concat(adaptive.changes, " ; "))
    else
        Chat("poids du profil de specialisation conserves sans ajustement")
    end
end

local function PrintHelp()
    Chat("/cld status - etat et profil detecte")
    Chat("/cld auto - active/desactive NEED/PASS automatique")
    Chat("/cld confirm - confirme automatiquement les objets lies")
    Chat("/cld scan - rescane l'equipement")
    Chat("/cld talents - talents, spellbook et confiance detectes")
    Chat("/cld explain - explique les ajustements adaptatifs")
    Chat("/cld gear - meilleurs objets des sacs, banque et marchand")
    Chat("/cld visuals - active/desactive les contours et tooltips")
    Chat("/cld downgrades - affiche/masque les objets moins bons")
    Chat("/cld chests - NEED les coffres verrouillés, CUPIDITÉ si NEED est indisponible")
    Chat("/cld test [lien] - compare un objet sans lancer de jet")
    Chat("/cld threshold 15 - seuil de la specialisation actuelle")
    Chat("/cld threshold auto - revient au seuil de classe/global")
    Chat("/cld weight <stat> <valeur|auto> - surcharge un poids")
    Chat("/cld history - ouvre l'historique visuel ; /cld history clear l'efface")
    Chat("/cld heretic - rappelle les priorites Heretic CAC")
    Chat("/cld sanguine - rappelle les priorites Bloodmage Sanguine")
end

SLASH_COALOOTDECIDER1 = "/cld"
SLASH_COALOOTDECIDER2 = "/coaloot"
SlashCmdList.COALOOTDECIDER = function(message)
    EnsureDatabase()
    local command, rest = string.match(Trim(message), "^(%S*)%s*(.-)$")
    command = Lower(command)

    if command == "" or command == "help" then
        PrintHelp()
    elseif command == "status" then
        ScanEquipment()
        local threshold, thresholdSource = ActiveThreshold()
        Chat("auto=" .. (CoALootDeciderDB.autoRoll and "ACTIF" or "inactif")
            .. ", confirmation=" .. (CoALootDeciderDB.autoConfirm and "active" or "inactive")
            .. ", coffres=" .. (CoALootDeciderDB.needLockedChests and "RECUPERER" or "passer")
            .. ", seuil=" .. threshold .. "% (" .. thresholdSource .. ")")
        Chat(ProfileSummary())
    elseif command == "auto" then
        ScanEquipment()
        if not profile.valid and not CoALootDeciderDB.autoRoll then
            Chat("activation refusee : " .. tostring(profile.error))
            return
        end
        CoALootDeciderDB.autoRoll = not CoALootDeciderDB.autoRoll
        Chat("jets automatiques " .. (CoALootDeciderDB.autoRoll and "ACTIVES" or "desactives"))
    elseif command == "confirm" then
        CoALootDeciderDB.autoConfirm = not CoALootDeciderDB.autoConfirm
        Chat("confirmation automatique " .. (CoALootDeciderDB.autoConfirm and "active" or "desactivee"))
    elseif command == "scan" then
        ScanEquipment()
        Chat("equipement rescane : " .. ProfileSummary())
    elseif command == "talents" or command == "explain" then
        ScanEquipment()
        PrintAdaptiveDetails()
    elseif command == "gear" then
        if CoALootAdvisor_Toggle then CoALootAdvisor_Toggle() else Chat("interface de comparaison indisponible") end
    elseif command == "visuals" then
        if CoALootAdvisor_ToggleVisuals then
            Chat("conseils visuels " .. (CoALootAdvisor_ToggleVisuals() and "ACTIVES" or "desactives"))
        end
    elseif command == "downgrades" then
        if CoALootAdvisor_ToggleDowngrades then
            Chat("objets moins bons " .. (CoALootAdvisor_ToggleDowngrades() and "affiches" or "masques"))
        end
    elseif command == "chests" or command == "coffres" then
        CoALootDeciderDB.needLockedChests = not CoALootDeciderDB.needLockedChests
        Chat("coffres verrouillés : " .. (CoALootDeciderDB.needLockedChests
            and "NEED, avec CUPIDITÉ de secours" or "PASS"))
    elseif command == "threshold" then
        ScanEquipment()
        local key = ThresholdKey(profile)
        if not key then
            Chat("seuil refuse : " .. tostring(profile and profile.error or "profil CoA non detecte"))
        elseif Lower(rest) == "auto" then
            CoALootDeciderDB.thresholdsBySpec[key] = nil
            local inherited, source = ActiveThreshold()
            Chat("seuil de " .. profile.className .. " - " .. profile.specName
                .. " revenu a " .. inherited .. "% (" .. source .. ")")
        else
            local threshold = tonumber(rest)
            if not threshold or threshold < 0 or threshold > 100 then
                Chat("seuil attendu entre 0 et 100, ou auto")
            else
                CoALootDeciderDB.thresholdsBySpec[key] = threshold
                Chat("seuil de " .. profile.className .. " - " .. profile.specName
                    .. " regle a " .. threshold .. "% ; les autres specialisations ne changent pas")
            end
        end
    elseif command == "weight" then
        ScanEquipment()
        local alias, rawValue = string.match(rest, "^(%S+)%s+(%S+)$")
        local key = alias and STAT_ALIASES[Lower(alias)] or nil
        if not key then
            Chat("stat inconnue (exemples : str, agi, int, crit, haste, hit, spell, ap)")
        elseif not profile.valid then
            Chat("poids refuse : " .. tostring(profile.error))
        elseif not profile.weights[key] or profile.weights[key] <= 0 then
            Chat("poids refuse : " .. (DISPLAY_STATS[key] or key) .. " est interdite pour " .. profile.className .. " - " .. profile.specName)
        elseif Lower(rawValue) == "auto" then
            CoALootDeciderDB.customWeights[key] = nil
            ScanEquipment()
            Chat((DISPLAY_STATS[key] or key) .. " repasse en detection automatique")
        else
            local value = tonumber(rawValue)
            if not value or value < 0 or value > 20 then
                Chat("poids attendu entre 0 et 20, ou auto")
            else
                CoALootDeciderDB.customWeights[key] = value
                ScanEquipment()
                Chat((DISPLAY_STATS[key] or key) .. " = " .. value)
            end
        end
    elseif command == "test" then
        local itemLink = string.match(rest, "(|c%x+|Hitem:.-|h%[.-%]|h|r)") or Trim(rest)
        local decision, errorMessage = EvaluateItem(itemLink)
        if not decision then
            Chat("test impossible : " .. tostring(errorMessage))
        else
            ShowDecision(decision, false)
            Chat((decision.need and "NEED " or "PASS ") .. (decision.candidate.link or decision.candidate.name) .. " - " .. decision.reason)
        end
    elseif command == "heretic" then
        ScanEquipment()
        if profile and profile.isCultistHeretic then
            Chat("Heretic CAC : CRIT > FOR/PA > PS/INT > HATE ; 2M lente ; plaque si stats proches.")
            Chat("Comparaison BagAware active : un loot doit aussi battre le meilleur objet deja present dans les sacs.")
        else
            Chat("Le profil actif n'est pas detecte comme Cultist - Heretic.")
        end
    elseif command == "sanguine" then
        ScanEquipment()
        if profile and profile.isBloodmageSanguine then
            Chat("Bloodmage Sanguine : PS > END/ESPRIT > CRIT > HATE ; cuir prefere ; pas de stats physiques.")
            Chat("Comparaison BagAware active : un loot doit aussi battre le meilleur objet deja present dans les sacs.")
        else
            Chat("Le profil actif n'est pas detecte comme Bloodmage - Sanguine.")
        end
    elseif command == "history" then
        if Lower(rest) == "clear" or Lower(rest) == "effacer" then
            CoALootDeciderDB.history = {}
            Chat("historique des décisions effacé")
        elseif CoALootAdvisor_ShowHistory then
            CoALootAdvisor_ShowHistory()
        else
            local index, entry
            for index, entry in ipairs(CoALootDeciderDB.history) do
                if index > 10 then break end
                Chat(index .. ". " .. entry.decision .. " " .. (entry.itemLink or entry.itemName) .. " - " .. (entry.reason or ""))
            end
            if #CoALootDeciderDB.history == 0 then Chat("aucune decision enregistree") end
        end
    else
        PrintHelp()
    end
end
