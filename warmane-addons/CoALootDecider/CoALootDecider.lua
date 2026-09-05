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
    mp5 = { "ITEM_MOD_MANA_REGENERATION_SHORT" },
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
    INVTYPE_TABARD = { 19 },
    -- Les quatre sacs équipés sont de vrais emplacements d'inventaire en
    -- 3.3.5a. Ils utilisent une logique de capacité dédiée, pas le score de
    -- statistiques de l'équipement.
    INVTYPE_BAG = { 20, 21, 22, 23 }
}

-- Les identifiants numeriques optionnels utilisent les sous-classes d'armure classiques :
-- 1 tissu, 2 cuir, 3 maille, 4 plaque. Les capes, chemises et boucliers ne
-- doivent pas etre confondus avec la famille d'armure du personnage.
local ARMOR_SUBCLASS_NAMES = {
    [1] = "TISSU",
    [2] = "CUIR",
    [3] = "MAILLE",
    [4] = "PLAQUE"
}

local BODY_ARMOR_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true
}

-- Identifiants de sous-classe WotLK 3.3.5a. Ces nombres sont stables et
-- prioritaires sur les libelles localises de GetItemInfo.
local WEAPON_SUBCLASS_NAMES = {
    [0] = "haches a une main",
    [1] = "haches a deux mains",
    [2] = "arcs",
    [3] = "fusils",
    [4] = "masses a une main",
    [5] = "masses a deux mains",
    [6] = "armes d'hast",
    [7] = "epees a une main",
    [8] = "epees a deux mains",
    [10] = "batons",
    [13] = "armes de pugilat",
    [15] = "dagues",
    [16] = "armes de jet",
    [18] = "arbaletes",
    [19] = "baguettes",
    [20] = "cannes a peche"
}

local RELIC_SUBCLASS_NAMES = {
    [7] = "librams",
    [8] = "idoles",
    [9] = "totems",
    [10] = "sigilles"
}

local CLASS_NAMES_FR = {
    WARRIOR = "Guerrier",
    PALADIN = "Paladin",
    HUNTER = "Chasseur",
    ROGUE = "Voleur",
    PRIEST = "Pretre",
    DEATHKNIGHT = "Chevalier de la mort",
    SHAMAN = "Chaman",
    MAGE = "Mage",
    WARLOCK = "Demoniste",
    DRUID = "Druide"
}

-- Maitrises d'armes reelles des classes WotLK. Les restrictions specifiques
-- a un objet (niveau, reputation ou classe inscrite dans son tooltip) restent
-- gerees par le client ; cette matrice empeche surtout de noter une famille
-- que la classe ne saura jamais equiper.
local CLASS_WEAPON_SUBCLASSES = {
    WARRIOR = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true,
        [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true,
        [16] = true, [18] = true },
    PALADIN = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true,
        [7] = true, [8] = true },
    HUNTER = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true,
        [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [18] = true },
    ROGUE = { [0] = true, [2] = true, [3] = true, [4] = true, [7] = true,
        [13] = true, [15] = true, [16] = true, [18] = true },
    PRIEST = { [4] = true, [10] = true, [15] = true, [19] = true },
    DEATHKNIGHT = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true,
        [7] = true, [8] = true },
    SHAMAN = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true,
        [13] = true, [15] = true },
    MAGE = { [7] = true, [10] = true, [15] = true, [19] = true },
    WARLOCK = { [7] = true, [10] = true, [15] = true, [19] = true },
    DRUID = { [4] = true, [5] = true, [6] = true, [10] = true, [13] = true,
        [15] = true }
}

local CLASS_RELIC_SUBCLASS = {
    PALADIN = 7,
    DRUID = 8,
    SHAMAN = 9,
    DEATHKNIGHT = 10
}

local CLASS_CAN_USE_SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local CLASS_CAN_USE_HOLDABLE = { PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true }

local WEAPON_EQUIP_LOCS = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_THROWN = true
}

-- Le Pyromancien exige un gain nettement plus visible avant de NEED.
-- Les autres classes utilisent le seuil global prudent de 5%.
local DEFAULT_CLASS_THRESHOLDS = {}

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff67d9ffLoot Decider Warmane:|r " .. tostring(message))
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

local function CharacterKey()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Warmane"
    return tostring(name) .. "-" .. tostring(realm)
end

local function EnsureDatabase()
    CoALootDeciderDB = CoALootDeciderDB or {}
    -- La première version Warmane reste en conseil visuel tant que le joueur
    -- n'a pas explicitement validé son profil avec /cld auto.
    if CoALootDeciderDB.autoRoll == nil then CoALootDeciderDB.autoRoll = false end
    if CoALootDeciderDB.autoConfirm == nil then CoALootDeciderDB.autoConfirm = true end
    -- Depuis 0.2, une information inconnue ne provoque jamais un PASS
    -- automatique. Ne rien choisir est plus sur qu'une mauvaise decision.
    if CoALootDeciderDB.strictSafetyVersion ~= 2 then
        CoALootDeciderDB.passUnknown = false
        CoALootDeciderDB.strictSafetyVersion = 2
    end
    -- Migration 0.2.3 : l'ancien seuil global de 1% etait trop permissif.
    -- Elle ne s'execute qu'une fois ; les reglages suivants restent conserves.
    if CoALootDeciderDB.thresholdPolicyVersion ~= 4 then
        CoALootDeciderDB.threshold = 8
        CoALootDeciderDB.thresholdPolicyVersion = 4
    else
        CoALootDeciderDB.threshold = tonumber(CoALootDeciderDB.threshold) or 8
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
    CoALootDeciderDB.roleOverrides = CoALootDeciderDB.roleOverrides or {}
    CoALootDeciderDB.adaptiveBuilds = CoALootDeciderDB.adaptiveBuilds or {}
    CoALootDeciderDB.history = CoALootDeciderDB.history or {}
    if CoALootDeciderDB.needLockedChests == nil then CoALootDeciderDB.needLockedChests = true end
    CoALootDeciderDB.bannerPosition = CoALootDeciderDB.bannerPosition or nil
    CoALootDeciderDB.version = "1.23.3-warmane-wotlk"
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
local itemDataCache = {}
local itemDataCacheSize = 0
local ITEM_DATA_CACHE_LIMIT = 600

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

local bagScanner = CreateFrame("GameTooltip", "CoALootDeciderBagScanner", nil, "GameTooltipTemplate")
bagScanner:SetOwner(UIParent, "ANCHOR_NONE")
local bagCapacityCache = {}

-- WotLK ne fournit pas la capacité d'un sac non équipé via GetItemInfo.
-- Le tooltip, lui, contient toujours "16 Slot Bag" (ou son équivalent
-- français). Le parseur reste volontairement court et indépendant de Retail.
local function ReadBagCapacity(itemLink)
    if not itemLink then return nil end
    if bagCapacityCache[itemLink] ~= nil then
        return bagCapacityCache[itemLink] ~= false and bagCapacityCache[itemLink] or nil
    end
    bagScanner:ClearLines()
    if not pcall(bagScanner.SetHyperlink, bagScanner, itemLink) then
        bagScanner:Hide()
        return nil
    end
    local capacity = nil
    local line
    for line = 1, bagScanner:NumLines() do
        local left = _G["CoALootDeciderBagScannerTextLeft" .. line]
        local right = _G["CoALootDeciderBagScannerTextRight" .. line]
        local text = Lower((left and left:GetText() or "") .. " " .. (right and right:GetText() or ""))
        local value = string.match(text, "(%d+)%s+slot")
            or string.match(text, "sac%s+[^%d]*(%d+)%s+emplacement")
            or string.match(text, "(%d+)%s+emplacement")
        if value then
            capacity = tonumber(value)
            break
        end
    end
    bagScanner:Hide()
    bagCapacityCache[itemLink] = capacity or false
    return capacity
end

-- Le moteur ne depend d'aucun backport moderne pour reconnaitre
-- tissu/cuir/maille/plaque. GetItemInfo expose deja le sous-type localise : on
-- l'utilise comme repli, y compris sur un client francais.
local function ArmorSubclassFromText(itemType, itemSubType, equipLoc)
    if not BODY_ARMOR_EQUIP_LOCS[equipLoc] then return nil end

    local localizedGlobals = {
        [1] = "ITEM_SUBCLASS_ARMOR_CLOTH",
        [2] = "ITEM_SUBCLASS_ARMOR_LEATHER",
        [3] = "ITEM_SUBCLASS_ARMOR_MAIL",
        [4] = "ITEM_SUBCLASS_ARMOR_PLATE"
    }
    local subTypeLower = Lower(itemSubType)
    local subClassID, globalName
    for subClassID, globalName in pairs(localizedGlobals) do
        local localized = _G and _G[globalName] or nil
        if localized and localized ~= "" and subTypeLower == Lower(localized) then
            return subClassID
        end
    end

    local text = Lower((itemType or "") .. " " .. (itemSubType or ""))
    local aliases = {
        [1] = { "cloth", "tissu" },
        [2] = { "leather", "cuir" },
        [3] = { "mail", "maille" },
        [4] = { "plate", "plaque" }
    }
    local _, token
    for subClassID = 1, 4 do
        for _, token in ipairs(aliases[subClassID]) do
            if string.find(text, token, 1, true) then return subClassID end
        end
    end
    return nil
end

local ITEM_SUBCLASS_GLOBALS = {
    [2] = {
        [0] = "ITEM_SUBCLASS_WEAPON_AXE", [1] = "ITEM_SUBCLASS_WEAPON_AXE2",
        [2] = "ITEM_SUBCLASS_WEAPON_BOW", [3] = "ITEM_SUBCLASS_WEAPON_GUN",
        [4] = "ITEM_SUBCLASS_WEAPON_MACE", [5] = "ITEM_SUBCLASS_WEAPON_MACE2",
        [6] = "ITEM_SUBCLASS_WEAPON_POLEARM", [7] = "ITEM_SUBCLASS_WEAPON_SWORD",
        [8] = "ITEM_SUBCLASS_WEAPON_SWORD2", [10] = "ITEM_SUBCLASS_WEAPON_STAFF",
        [13] = "ITEM_SUBCLASS_WEAPON_FIST", [15] = "ITEM_SUBCLASS_WEAPON_DAGGER",
        [16] = "ITEM_SUBCLASS_WEAPON_THROWN", [18] = "ITEM_SUBCLASS_WEAPON_CROSSBOW",
        [19] = "ITEM_SUBCLASS_WEAPON_WAND", [20] = "ITEM_SUBCLASS_WEAPON_FISHINGPOLE"
    },
    [4] = {
        [6] = "ITEM_SUBCLASS_ARMOR_SHIELD", [7] = "ITEM_SUBCLASS_ARMOR_LIBRAM",
        [8] = "ITEM_SUBCLASS_ARMOR_IDOL", [9] = "ITEM_SUBCLASS_ARMOR_TOTEM",
        [10] = "ITEM_SUBCLASS_ARMOR_SIGIL"
    }
}

local ITEM_SUBCLASS_ALIASES = {
    [2] = {
        [0] = { "one-handed axes", "one-handed axe", "haches a une main", "hache a une main", "haches à une main", "hache à une main" },
        [1] = { "two-handed axes", "two-handed axe", "haches a deux mains", "hache a deux mains", "haches à deux mains", "hache à deux mains" },
        [2] = { "bows", "bow", "arcs", "arc" },
        [3] = { "guns", "gun", "fusils", "fusil" },
        [4] = { "one-handed maces", "one-handed mace", "masses a une main", "masse a une main", "masses à une main", "masse à une main" },
        [5] = { "two-handed maces", "two-handed mace", "masses a deux mains", "masse a deux mains", "masses à deux mains", "masse à deux mains" },
        [6] = { "polearms", "polearm", "armes d'hast", "arme d'hast" },
        [7] = { "one-handed swords", "one-handed sword", "epees a une main", "epee a une main", "épées à une main", "épée à une main" },
        [8] = { "two-handed swords", "two-handed sword", "epees a deux mains", "epee a deux mains", "épées à deux mains", "épée à deux mains" },
        [10] = { "staves", "staff", "batons", "baton", "bâtons", "bâton" },
        [13] = { "fist weapons", "fist weapon", "armes de pugilat", "arme de pugilat" },
        [15] = { "daggers", "dagger", "dagues", "dague" },
        [16] = { "thrown", "thrown weapons", "armes de jet", "arme de jet" },
        [18] = { "crossbows", "crossbow", "arbaletes", "arbalete", "arbalètes", "arbalète" },
        [19] = { "wands", "wand", "baguettes", "baguette" },
        [20] = { "fishing poles", "fishing pole", "cannes a peche", "canne a peche", "cannes à pêche", "canne à pêche" }
    },
    [4] = {
        [6] = { "shields", "shield", "boucliers", "bouclier" },
        [7] = { "librams", "libram" },
        [8] = { "idols", "idol", "idoles", "idole" },
        [9] = { "totems", "totem" },
        [10] = { "sigils", "sigil", "sigilles", "sigille" }
    }
}

local function SubclassFromText(classID, itemSubType)
    local normalized = Lower(Trim(itemSubType))
    if normalized == "" then return nil end

    local globals = ITEM_SUBCLASS_GLOBALS[classID] or {}
    local subClassID, globalName
    for subClassID, globalName in pairs(globals) do
        local localized = _G and _G[globalName] or nil
        if localized and localized ~= "" and normalized == Lower(Trim(localized)) then
            return subClassID
        end
    end

    local aliases = ITEM_SUBCLASS_ALIASES[classID] or {}
    local _, alias
    for subClassID, aliasesForSubclass in pairs(aliases) do
        for _, alias in ipairs(aliasesForSubclass) do
            if normalized == Lower(alias) then return subClassID end
        end
    end
    return nil
end

local function ItemData(itemLink)
    if not itemLink or not GetItemInfo then return nil end
    local cacheKey = tostring(itemLink)
    local cached = itemDataCache[cacheKey]
    if cached then return cached end
    local name, link, quality, itemLevel, requiredLevel, itemType, itemSubType, stackCount,
        equipLoc, texture, _, returnedClassID, returnedSubClassID = GetItemInfo(itemLink)
    if not name or not equipLoc then return nil end
    -- Le client WotLK d'origine s'arrete au prix de vente. Certains clients
    -- 3.3.5 etendus ajoutent classID/subClassID a GetItemInfo : on les utilise
    -- s'ils existent, sans appeler d'API Retail.
    local classID = tonumber(returnedClassID)
    local subClassID = tonumber(returnedSubClassID)
    if not classID then
        if WEAPON_EQUIP_LOCS[equipLoc] then
            classID = 2
        elseif equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_RELIC"
            or equipLoc == "INVTYPE_HOLDABLE" or BODY_ARMOR_EQUIP_LOCS[equipLoc]
        then
            classID = 4
        end
    end
    if not subClassID then
        if equipLoc == "INVTYPE_SHIELD" then
            subClassID = 6
        elseif equipLoc == "INVTYPE_THROWN" then
            subClassID = 16
        elseif classID == 2 or equipLoc == "INVTYPE_RELIC" then
            subClassID = SubclassFromText(classID or 4, itemSubType)
        else
            subClassID = ArmorSubclassFromText(itemType, itemSubType, equipLoc)
        end
    end

    local isWeapon = equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_WEAPON"
        or equipLoc == "INVTYPE_WEAPONMAINHAND"
        or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_RANGED"
        or equipLoc == "INVTYPE_RANGEDRIGHT"
        or equipLoc == "INVTYPE_THROWN"

    local data = {
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
        weaponSpeed = isWeapon and ReadWeaponSpeed(link or itemLink) or nil,
        bagCapacity = equipLoc == "INVTYPE_BAG" and ReadBagCapacity(link or itemLink) or nil
    }
    -- GetItemStats et les scanners de tooltip sont parmi les appels les plus
    -- couteux du client 3.3.5. Les donnees d'un lien complet sont immuables :
    -- on ne les relit donc pas a chaque BAG_UPDATE ou survol.
    if itemDataCacheSize >= ITEM_DATA_CACHE_LIMIT then
        itemDataCache = {}
        itemDataCacheSize = 0
    end
    itemDataCache[cacheKey] = data
    itemDataCacheSize = itemDataCacheSize + 1
    return data
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

local function ActiveTalentTab()
    local group = type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup(false, false) or 1
    local count = type(GetNumTalentTabs) == "function" and tonumber(GetNumTalentTabs(false, false)) or 3
    local bestIndex, bestPoints, tabName = 1, -1, nil
    local index
    for index = 1, math.min(count or 3, 3) do
        local ok, name, _, points = pcall(GetTalentTabInfo, index, false, false, group)
        points = ok and tonumber(points) or 0
        if points > bestPoints then bestIndex, bestPoints, tabName = index, points, name end
    end
    return bestIndex, bestPoints, tabName
end

local function ActiveFormContains(...)
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then return false end
    local wanted = { ... }
    local index
    for index = 1, GetNumShapeshiftForms() do
        local _, name, active = GetShapeshiftFormInfo(index)
        if active and name then
            local lowerName = Lower(name)
            local _, token
            for _, token in ipairs(wanted) do
                if string.find(lowerName, Lower(token), 1, true) then return true end
            end
        end
    end
    return false
end

local function RoleOverride()
    EnsureDatabase()
    return CoALootDeciderDB.roleOverrides[CharacterKey()]
end

local function ResolveActiveSpecialization()
    local className, classToken = UnitClass("player")
    local classSpecs = CoALootProfiles and CoALootProfiles.specs and CoALootProfiles.specs[classToken]
    if type(classSpecs) ~= "table" then
        return nil, "classe WotLK non prise en charge : " .. tostring(classToken or className)
    end

    local specializationIndex, points, localizedTab = ActiveTalentTab()
    local base = classSpecs[specializationIndex]
    if type(base) ~= "table" then
        return nil, "arbre de talents WotLK introuvable (index " .. tostring(specializationIndex) .. ")"
    end

    local stableName = base.name
    local role = base.role or "DAMAGE"
    local override = RoleOverride()
    if classToken == "DRUID" and specializationIndex == 2 then
        if override == "TANK" or (override == nil and ActiveFormContains("bear", "ours")) then
            stableName, role = "Feral Bear", "TANK"
        else
            stableName, role = "Feral Cat", "DAMAGE"
        end
    elseif classToken == "DEATHKNIGHT" and specializationIndex == 1 and override == "DAMAGE" then
        stableName, role = "Blood DPS", "DAMAGE"
    elseif override == "TANK" or override == "HEALER" or override == "DAMAGE" then
        role = override
    end

    local primaryStats = {}
    local _, primaryName
    for _, primaryName in ipairs(base.primaryStats or {}) do
        if PRIMARY_STAT_KEYS[primaryName] then table.insert(primaryStats, primaryName) end
    end
    local specInfo = {
        Name = stableName,
        Tank = role == "TANK",
        Healer = role == "HEALER",
        Support = false,
        MeleeDPS = role == "DAMAGE" and (classToken == "WARRIOR" or classToken == "PALADIN"
            or classToken == "ROGUE" or classToken == "DEATHKNIGHT"
            or (classToken == "SHAMAN" and specializationIndex == 2)
            or (classToken == "DRUID" and specializationIndex == 2)),
        RangedDPS = role == "DAMAGE" and classToken == "HUNTER",
        CasterDPS = role == "DAMAGE" and (classToken == "PRIEST" or classToken == "MAGE"
            or classToken == "WARLOCK" or (classToken == "SHAMAN" and specializationIndex == 1)
            or (classToken == "DRUID" and specializationIndex == 1))
    }
    return {
        className = className or classToken or "Classe inconnue",
        classToken = classToken,
        specializationIndex = specializationIndex,
        specializationID = specializationIndex,
        localizedTab = localizedTab,
        talentPoints = points,
        specInfo = specInfo,
        specName = stableName,
        primaryStats = primaryStats,
        primarySource = "arbre de talents WotLK"
    }
end

local function SpecializationProfileKey(specialization)
    return tostring(specialization.classToken or specialization.className or "") .. ":" .. tostring(specialization.specName or "")
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

local function FindArmorRuleIn(tableValue, requestedKey)
    if type(tableValue) ~= "table" or not requestedKey then return nil end
    if tableValue[requestedKey] then return tableValue[requestedKey] end
    local key, value
    for key, value in pairs(tableValue) do
        if Lower(key) == Lower(requestedKey) then return value end
    end
    return nil
end

local function ResolveArmorRule(specialization, presetKey)
    if type(CoALootProfiles) ~= "table" or not specialization then return nil end

    local requestedSpec = presetKey or SpecializationProfileKey(specialization)
    local classRaw = FindArmorRuleIn(CoALootProfiles.armorRules, specialization.classToken or specialization.className)
    local specRaw = FindArmorRuleIn(CoALootProfiles.armorBySpec, requestedSpec)
    if type(classRaw) ~= "table" and type(specRaw) ~= "table" then return nil end

    classRaw = type(classRaw) == "table" and classRaw or {}
    specRaw = type(specRaw) == "table" and specRaw or {}

    local allowed = {}
    local _, subClassID
    local classAllowed = classRaw.allowed or {}
    local classLabel = classRaw.label
    if PlayerLevel() < 40 and type(classRaw.levelingAllowed) == "table" then
        classAllowed = classRaw.levelingAllowed
        classLabel = classRaw.levelingLabel or classLabel
    end
    for _, subClassID in ipairs(specRaw.allowed or classAllowed) do
        subClassID = tonumber(subClassID)
        if subClassID then allowed[subClassID] = true end
    end
    if not next(allowed) then return nil end

    local preferred = {}
    for _, subClassID in ipairs(specRaw.preferred or classRaw.preferred or {}) do
        subClassID = tonumber(subClassID)
        if subClassID and allowed[subClassID] then preferred[subClassID] = true end
    end

    -- Une classe mono-armure a implicitement cette famille en preference.
    if not next(preferred) then
        local count, only = 0, nil
        for subClassID in pairs(allowed) do count, only = count + 1, subClassID end
        if count == 1 then preferred[only] = true end
    end

    local label = tostring(specRaw.label or classLabel or "NON DOCUMENTEE")
    local preferredLabel = specRaw.preferredLabel or classRaw.preferredLabel
    local displayLabel = label
    if preferredLabel and tostring(preferredLabel) ~= label then
        displayLabel = label .. " ; pref " .. tostring(preferredLabel)
    end

    return {
        allowed = allowed,
        preferred = preferred,
        label = label,
        preferredLabel = preferredLabel and tostring(preferredLabel) or nil,
        displayLabel = displayLabel,
        source = tostring(CoALootProfiles.armorSource or "profil WotLK"),
        sourceDate = tostring(CoALootProfiles.armorSourceDate or "")
    }
end

local function PublicWeights(specialization)
    local preset, weaponRule, presetKey = FindPublicPreset(specialization)
    if not preset then return nil end

    local effectivePreset = {}
    local presetName, presetValue
    for presetName, presetValue in pairs(preset) do effectivePreset[presetName] = presetValue end
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
    for slot = 1, 23 do
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
    local weightSource = "profils Warmane/WotLK " .. tostring(CoALootProfiles and CoALootProfiles.sourceDate or "")
    if not weights then
        weights, acceptedPrimaries, physical, caster, strictError = StrictWeights(specialization)
        weightSource = "repli WotLK prudent"
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
        weightSource = weightSource .. " + adaptation locale"
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
        talentPoints = specialization.talentPoints,
        localizedTab = specialization.localizedTab,
        primarySource = specialization.primarySource,
        weightSource = weightSource,
        presetKey = presetKey,
        weaponRule = weaponRule,
        armorRule = ResolveArmorRule(specialization, presetKey),
        adaptive = adaptive,
        level = PlayerLevel(),
        isCultistHeretic = false,
        isBloodmageSanguine = false,
        tuningLabel = "Warmane Icecrown WotLK",
        scannedAt = GetTime and GetTime() or 0
    }
    profile.bagItems = ScanBagItems()
    return profile
end

local function RefreshBagItems()
    if not profile then return ScanEquipment() end
    profile.bagItems = ScanBagItems()
    profile.bagsScannedAt = GetTime and GetTime() or 0
    return profile.bagItems
end

local function ThresholdKey(targetProfile)
    if not targetProfile or not targetProfile.valid then return nil end
    local classPart = targetProfile.classToken or targetProfile.className
    local specPart = targetProfile.specializationID or targetProfile.specName
    if not classPart or not specPart then return nil end
    return tostring(classPart) .. ":" .. tostring(specPart)
end

local function ActiveThreshold()
    local globalThreshold = tonumber(CoALootDeciderDB.threshold) or 8
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

local function ArmorCompatibility(data)
    if not data or not profile or not profile.armorRule then return true end
    if data.classID ~= 4 or not BODY_ARMOR_EQUIP_LOCS[data.equipLoc] then return true end

    local subClassID = tonumber(data.subClassID)
    if not subClassID or not ARMOR_SUBCLASS_NAMES[subClassID] then
        -- Le client n'a pas encore fourni le sous-type : ne jamais fabriquer
        -- une incompatibilite a partir d'une information inconnue.
        return true
    end
    if profile.armorRule.allowed[subClassID] then return true end

    local actual = ARMOR_SUBCLASS_NAMES[subClassID] or tostring(data.itemSubType or "?")
    return false, "armure " .. actual .. " hors profil pour "
        .. tostring(profile.className) .. " - " .. tostring(profile.specName)
        .. " ; attendu : " .. tostring(profile.armorRule.label)
end

local function ClassDisplayName(classToken)
    return CLASS_NAMES_FR[classToken]
        or (profile and profile.className)
        or tostring(classToken or "classe inconnue")
end

-- Retourne true pour un type autorise, false pour un type incompatible et nil
-- lorsqu'il manque une information fiable. Le cas nil suspend toujours le jet
-- automatique : mieux vaut demander une verification que PASS un objet valide.
local function WeaponCompatibility(data)
    if not data then return nil, "type d'arme introuvable : verification manuelle" end
    local equipLoc = data.equipLoc
    if not WEAPON_EQUIP_LOCS[equipLoc]
        and equipLoc ~= "INVTYPE_SHIELD"
        and equipLoc ~= "INVTYPE_HOLDABLE"
        and equipLoc ~= "INVTYPE_RELIC"
    then
        return true
    end

    local classToken = profile and profile.classToken or nil
    local className = ClassDisplayName(classToken)
    if not classToken or not CLASS_WEAPON_SUBCLASSES[classToken] then
        return nil, "Verification manuelle : la classe ne permet pas de valider ce type d'arme"
    end

    if equipLoc == "INVTYPE_SHIELD" then
        if CLASS_CAN_USE_SHIELD[classToken] then return true end
        return false, "Incompatible avec " .. className .. " : les boucliers ne sont pas utilisables"
    end

    if equipLoc == "INVTYPE_HOLDABLE" then
        if CLASS_CAN_USE_HOLDABLE[classToken] then return true end
        return false, "Incompatible avec " .. className .. " : les objets tenus en main gauche ne sont pas utilisables"
    end

    if equipLoc == "INVTYPE_RELIC" then
        local subClassID = tonumber(data.subClassID)
        if not subClassID or not RELIC_SUBCLASS_NAMES[subClassID] then
            return nil, "Verification manuelle : le type de relique n'a pas pu etre valide"
        end
        if CLASS_RELIC_SUBCLASS[classToken] == subClassID then return true end
        return false, "Incompatible avec " .. className .. " : les "
            .. RELIC_SUBCLASS_NAMES[subClassID] .. " ne sont pas utilisables"
    end

    if tonumber(data.classID) ~= 2 then
        return nil, "Verification manuelle : la categorie d'arme n'a pas pu etre validee"
    end
    local subClassID = tonumber(data.subClassID)
    local weaponName = subClassID and WEAPON_SUBCLASS_NAMES[subClassID] or nil
    if not weaponName then
        return nil, "Verification manuelle : le type d'arme n'a pas pu etre valide"
    end
    if not CLASS_WEAPON_SUBCLASSES[classToken][subClassID] then
        return false, "Incompatible avec " .. className .. " : les " .. weaponName .. " ne sont pas utilisables"
    end

    -- Une arme explicitement Main gauche exige le double maniement deja
    -- disponible sur le personnage. Cette API existe en 3.3.5a ; son absence
    -- sur un client modifie ne doit jamais provoquer un faux rejet.
    if equipLoc == "INVTYPE_WEAPONOFFHAND" and type(CanDualWield) == "function" then
        local ok, canDualWield = pcall(CanDualWield)
        if ok and not canDualWield then
            return false, "Incompatible actuellement avec " .. className .. " : double maniement indisponible"
        end
    end
    return true
end

local function PrimaryFitScore(data)
    if not data or not profile or not profile.weights then return nil end
    local maxWeight = 0
    local _, key
    for _, key in ipairs(PRIMARY_STATS) do
        maxWeight = math.max(maxWeight, math.max(0, tonumber(profile.weights[key]) or 0))
    end
    if maxWeight <= 0 then return nil end

    local total, useful = 0, 0
    for _, key in ipairs(PRIMARY_STATS) do
        local value = math.max(0, StatValue(data.stats, key))
        if value > 0 then
            total = total + value
            useful = useful + value * math.min(1, math.max(0, tonumber(profile.weights[key]) or 0) / maxWeight)
        end
    end
    if total <= 0 then return nil end
    return Round(100 * useful / total, 0)
end

local function FitScore(data)
    if not data or not profile or not profile.weights then return 0 end
    local weaponCompatible = WeaponCompatibility(data)
    if weaponCompatible ~= true then return 0 end
    local armorCompatible = ArmorCompatibility(data)
    if not armorCompatible then return 0 end
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

    if data.classID == 4 and BODY_ARMOR_EQUIP_LOCS[data.equipLoc]
        and profile.armorRule and next(profile.armorRule.preferred or {})
    then
        local subClassID = tonumber(data.subClassID)
        if subClassID and profile.armorRule.allowed[subClassID]
            and not profile.armorRule.preferred[subClassID]
        then
            -- Une famille autorisee mais non preferee reste possible sur CoA ;
            -- elle ne doit simplement pas battre trop facilement l'itemisation
            -- naturelle de la specialisation.
            score = score * 0.85
        end
    end

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
        -- Un objet classe MAUVAIS ne devient plus un NEED parce que son score
        -- brut ou son ilvl est tres eleve. Il reste visible pour jugement manuel.
        return 999
    end
    if fitScore >= 85 then return baseThreshold end
    if fitScore >= 70 then return math.max(baseThreshold, 8) end
    if fitScore >= 55 then return math.max(baseThreshold, 12) end
    if fitScore >= 40 then return math.max(baseThreshold, 20) end
    return 999
end

local function ScoreItem(data)
    if not data or not profile then return 0 end
    -- Garde-fou central : meme un appel interne (comparaison avec les sacs ou
    -- l'equipement) ne doit jamais valoriser les degats d'une arme interdite.
    local weaponCompatible = WeaponCompatibility(data)
    if weaponCompatible ~= true then return 0 end
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
        return profile and profile.error or "profil WotLK non detecte"
    end

    local weaponCompatible, weaponProblem = WeaponCompatibility(data)
    if weaponCompatible == nil then return weaponProblem, true end
    if not weaponCompatible then return weaponProblem, false end

    local armorCompatible, armorProblem = ArmorCompatibility(data)
    if not armorCompatible then return armorProblem end

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

    -- Une stat "poubelle" sur un objet mixte ne rend pas tout l'objet
    -- incompatible. On rejette seulement un objet dont TOUT le budget primaire
    -- est hors profil et qui n'apporte aucune puissance directe utile.
    local _, key
    local primaryTotal, primaryUseful = 0, 0
    for _, key in ipairs(PRIMARY_STATS) do
        local value = math.max(0, StatValue(data.stats, key))
        if value > 0 then
            primaryTotal = primaryTotal + value
            if (profile.weights[key] or 0) > 0 then primaryUseful = primaryUseful + value end
        end
    end
    if primaryTotal > 0 and primaryUseful <= 0 then
        local usefulDirect = 0
        local directKeys = {
            "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_HEALING_DONE_SHORT",
            "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
            "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
        }
        for _, key in ipairs(directKeys) do
            if (profile.weights[key] or 0) > 0 then
                usefulDirect = usefulDirect + math.max(0, StatValue(data.stats, key))
            end
        end
        if usefulDirect <= 0 then
            return "aucune statistique principale utile pour " .. profile.className .. " - " .. profile.specName
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

local function BagFamily(data)
    if not data or data.equipLoc ~= "INVTYPE_BAG" then return nil end
    local subClassID = tonumber(data.subClassID)
    if subClassID == 0 then return "GENERAL" end
    if subClassID then return "SPECIAL:" .. tostring(subClassID) end
    local subtype = Lower(data.itemSubType)
    if subtype == "bag" or subtype == "sac" or subtype == "container" or subtype == "conteneur" then
        return "GENERAL"
    end
    if subtype ~= "" then return "SPECIAL:" .. subtype end
    return nil
end

-- Détermine le plus petit sac qui resterait dans le meilleur ensemble que le
-- personnage possède déjà. Les sacs de réserve sont pris en compte : on ne
-- NEED donc pas un 18 places si quatre sacs de 20 places attendent déjà dans
-- l'inventaire. Un exemplaire survolé dans le sac peut être exclu du calcul.
local function BagBaselineFor(candidate, excludeOwnedCopy)
    local family = BagFamily(candidate)
    if family ~= "GENERAL" then
        return nil, nil, nil, nil, "sac spécialisé : choix manuel conseillé"
    end

    local replaceableSlots = 0
    local owned = {}
    local slot
    for slot = 20, 23 do
        local data = profile.items[slot]
        if not data then
            replaceableSlots = replaceableSlots + 1
        elseif BagFamily(data) == family then
            replaceableSlots = replaceableSlots + 1
            table.insert(owned, {
                capacity = tonumber(data.bagCapacity) or 0,
                link = data.link,
                data = data,
                source = "equipe"
            })
        end
    end
    if replaceableSlots <= 0 then
        return nil, nil, nil, nil, "aucun emplacement de sac général remplaçable"
    end

    local skippedCandidate = false
    local _, data
    for _, data in ipairs(profile.bagItems or {}) do
        if BagFamily(data) == family then
            if excludeOwnedCopy and not skippedCandidate and data.link == candidate.link then
                skippedCandidate = true
            else
                table.insert(owned, {
                    capacity = tonumber(data.bagCapacity) or 0,
                    link = data.link,
                    data = data,
                    source = "sac"
                })
            end
        end
    end
    table.sort(owned, function(a, b) return (a.capacity or 0) > (b.capacity or 0) end)
    local baseline = owned[replaceableSlots]
    if baseline then
        return baseline.capacity or 0, baseline.link, baseline.data, baseline.source
    end
    return 0, nil, nil, "emplacement vide"
end

local function AnalyzeBag(candidate, excludeOwnedCopy)
    local capacity = tonumber(candidate and candidate.bagCapacity)
    if not capacity or capacity <= 0 then
        return {
            need = false,
            candidate = candidate,
            reason = "capacité du sac introuvable : vérification manuelle recommandée",
            confidence = "basse",
            manual = true,
            bagUpgrade = true,
            nonEquipable = false
        }
    end

    local currentCapacity, currentLink, currentData, currentSource, problem =
        BagBaselineFor(candidate, excludeOwnedCopy)
    if currentCapacity == nil then
        return {
            need = false,
            candidate = candidate,
            candidateScore = capacity,
            reason = problem or "comparaison de sac impossible",
            confidence = "moyenne",
            manual = true,
            bagUpgrade = true,
            bagCapacity = capacity,
            nonEquipable = false
        }
    end

    local gain = capacity - currentCapacity
    local percent = currentCapacity > 0 and (gain / currentCapacity * 100) or (capacity > 0 and 100 or 0)
    local need = gain > 0
    local reason
    if need then
        reason = "+" .. tostring(gain) .. " emplacement(s) : " .. tostring(capacity)
            .. " contre " .. tostring(currentCapacity) .. " pour ton plus petit sac utile"
    elseif gain == 0 then
        reason = "même capacité que ton ensemble actuel : " .. tostring(capacity) .. " emplacements"
    else
        reason = tostring(math.abs(gain)) .. " emplacement(s) de moins que ton ensemble actuel"
    end
    return {
        need = need,
        candidate = candidate,
        candidateScore = capacity,
        currentScore = currentCapacity,
        currentLevel = currentData and currentData.itemLevel or 0,
        currentLink = currentLink,
        currentSource = currentSource,
        currentStats = {},
        percent = percent,
        threshold = 0,
        effectiveThreshold = 0,
        thresholdSource = "capacité de sac",
        fitScore = 100,
        currentFitScore = currentData and 100 or 0,
        fitTier = "PRATIQUE",
        fitBlocked = false,
        reason = reason,
        manual = false,
        confidence = "haute",
        bagUpgrade = true,
        bagCapacity = capacity,
        currentBagCapacity = currentCapacity,
        slotGain = gain,
        nonEquipable = false
    }
end

local function SameOwnedSlot(candidate, owned)
    return candidate and owned and EquipFamily(candidate.equipLoc) == EquipFamily(owned.equipLoc)
end

local function OwnedBaselineFor(candidate, equippedScore, equippedLevel, equippedLink, equippedData, excludeOwnedCopy)
    local pool = {}
    local skippedOwnedCopy = false
    local function AddOwned(data, source)
        if not data or not SameOwnedSlot(candidate, data) then return end
        local weaponCompatible = WeaponCompatibility(data)
        if weaponCompatible ~= true then return end
        if excludeOwnedCopy and not skippedOwnedCopy and data.link == candidate.link and source == "sac" then
            skippedOwnedCopy = true
            return
        end
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
    if candidate.equipLoc == "INVTYPE_BAG" then
        return AnalyzeBag(candidate, excludeOwnedCopy)
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
    local compatibilityProblem, compatibilityManual = CompatibilityProblem(candidate)
    if compatibilityProblem then
        return {
            need = false,
            candidate = candidate,
            reason = compatibilityProblem,
            manual = compatibilityManual and true or false,
            incompatible = not compatibilityManual,
            confidence = compatibilityManual and "basse" or "haute"
        }
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
    local fitBlocked = effectiveThreshold >= 999
    local minimum = fitBlocked and math.huge or math.max(1, currentScore * (effectiveThreshold / 100))
    local need = not fitBlocked
        and ((currentScore <= 0 and candidateScore > 0) or delta >= minimum)
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
    elseif fitBlocked then
        reason = "adequation " .. fitScore .. "/100 " .. FitTier(fitScore)
            .. " : objet hors profil, jamais NEED automatique"
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
        primaryFitScore = PrimaryFitScore(candidate),
        armorRuleLabel = profile.armorRule and profile.armorRule.displayLabel or nil,
        fitBlocked = fitBlocked,
        reason = reason,
        manual = manualReason and true or false,
        confidence = manualReason and "moyenne" or "haute"
    }
end

local function EvaluateItem(itemLink)
    -- Les evenements equipement/talents maintiennent deja le profil a jour.
    -- Refaire spellbook + talents + sacs a chaque tentative de jet causait des
    -- gels en donjon, surtout tant que GetLootRollItemLink n'etait pas charge.
    local analysis, errorMessage = AnalyzeItem(itemLink, false)
    if analysis and analysis.manual then return nil, analysis.reason end
    return analysis, errorMessage
end

-- API interne stable pour la couche universelle (sacs, marchands, quetes,
-- butin, liens de chat et fenetres tierces). Aucune dependance externe.
CoALootDeciderAPI = {
    AnalyzeItem = AnalyzeItem,
    RefreshProfile = ScanEquipment,
    RefreshBagItems = RefreshBagItems,
    GetProfile = function() return profile end,
    GetAdaptiveBuild = function() return profile and profile.adaptive or nil end,
    GetDisplayStats = function() return DISPLAY_STATS end,
    ScoreItem = ScoreItem,
    FitScore = FitScore,
    ArmorCompatibility = ArmorCompatibility,
    WeaponCompatibility = WeaponCompatibility,
    PrimaryFitScore = PrimaryFitScore,
    ReadBagCapacity = ReadBagCapacity,
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
local profileRefreshAt = nil
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
        -- Ascension envoie souvent plusieurs evenements pour un seul changement
        -- de niveau/talent. Un seul scan groupe evite les micro-gels en chaine.
        profileRefreshAt = GetTime() + 0.30
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
    if profileRefreshAt and GetTime() >= profileRefreshAt then
        profileRefreshAt = nil
        ScanEquipment()
    end
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
    local adaptiveSummary = "arbre " .. tostring(profile.localizedTab or profile.specName)
        .. " (" .. tostring(profile.talentPoints or 0) .. " points)"
    return profile.className .. " - " .. profile.specName .. " [" .. profile.role .. "]"
        .. " | physique=" .. (profile.physical and "oui" or "non")
        .. ", caster=" .. (profile.caster and "oui" or "non")
        .. ", primaire=" .. tostring(profile.primarySource or "inconnue")
        .. ", armure=" .. tostring(profile.armorRule and profile.armorRule.displayLabel or "non documentee")
        .. ", poids=" .. tostring(profile.weightSource or "inconnu")
        .. " | " .. table.concat(values, ", ")
        .. " | " .. adaptiveSummary
end

local function PrintAdaptiveDetails()
    if not profile then ScanEquipment() end
    if not profile or not profile.valid then
        Chat("profil WotLK indisponible : " .. tostring(profile and profile.error or "inconnu"))
        return
    end
    Chat("arbre actif : " .. tostring(profile.localizedTab or profile.specName)
        .. " ; " .. tostring(profile.talentPoints or 0) .. " points investis")
    Chat("profil retenu : " .. tostring(profile.specName) .. " [" .. tostring(profile.role) .. "]")
    if profile.classToken == "DRUID" or profile.classToken == "DEATHKNIGHT" then
        Chat("Feral et Blood peuvent être précisés avec /cld role tank|dps|auto")
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
    Chat("Survole un objet et maintiens MAJ pour voir pourquoi il est meilleur ou moins bon")
    Chat("/cld visuals - active/desactive les contours et tooltips")
    Chat("/cld downgrades - affiche/masque les objets moins bons")
    Chat("/cld chests - NEED les coffres verrouillés, CUPIDITÉ si NEED est indisponible")
    Chat("/cld test [lien] - compare un objet sans lancer de jet")
    Chat("/cld role auto|tank|dps - tranche Feral et Blood selon ton rôle")
    Chat("/cld threshold 15 - seuil de la specialisation actuelle")
    Chat("/cld threshold auto - revient au seuil de classe/global")
    Chat("/cld weight <stat> <valeur|auto> - surcharge un poids")
    Chat("/cld history - ouvre l'historique visuel ; /cld history clear l'efface")
    Chat("/cld minimap show|hide|reset - affiche, masque ou replace le bouton dédié")
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
    elseif command == "minimap" then
        local action = Lower(rest)
        if action == "hide" or action == "masquer" then
            if CoALootAdvisor_SetMinimapVisible then CoALootAdvisor_SetMinimapVisible(false) end
            Chat("bouton de minicarte masqué ; /cld minimap show pour le retrouver")
        elseif action == "reset" or action == "reinitialiser" then
            if CoALootAdvisor_ResetMinimapButton then CoALootAdvisor_ResetMinimapButton() end
            Chat("bouton de minicarte replacé")
        else
            if CoALootAdvisor_SetMinimapVisible then CoALootAdvisor_SetMinimapVisible(true) end
            Chat("bouton de minicarte affiché")
        end
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
    elseif command == "role" then
        local requested = Lower(rest)
        local _, classToken = UnitClass("player")
        local tab = ActiveTalentTab()
        if requested == "auto" then
            CoALootDeciderDB.roleOverrides[CharacterKey()] = nil
        elseif (requested == "tank" or requested == "dps")
            and ((classToken == "DRUID" and tab == 2) or (classToken == "DEATHKNIGHT" and tab == 1))
        then
            CoALootDeciderDB.roleOverrides[CharacterKey()] = requested == "tank" and "TANK" or "DAMAGE"
        else
            Chat("Cette commande sert uniquement à distinguer Feral tank/DPS et Blood tank/DPS.")
            return
        end
        ScanEquipment()
        Chat("rôle " .. (CoALootDeciderDB.roleOverrides[CharacterKey()] or "AUTO") .. " ; " .. ProfileSummary())
    elseif command == "threshold" then
        ScanEquipment()
        local key = ThresholdKey(profile)
        if not key then
            Chat("seuil refuse : " .. tostring(profile and profile.error or "profil WotLK non detecte"))
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
