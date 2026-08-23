-- Adaptive build layer for CoA Loot Decider.
-- Strictly uses APIs exposed by Project Ascension's 3.3.5 client.

CoALootAdaptation = CoALootAdaptation or {}

local STAT_KEYS = {
    str = "ITEM_MOD_STRENGTH_SHORT",
    agi = "ITEM_MOD_AGILITY_SHORT",
    int = "ITEM_MOD_INTELLECT_SHORT",
    spi = "ITEM_MOD_SPIRIT_SHORT",
    sta = "ITEM_MOD_STAMINA_SHORT",
    ap = "ITEM_MOD_ATTACK_POWER_SHORT",
    sp = "ITEM_MOD_SPELL_POWER_SHORT",
    heal = "ITEM_MOD_HEALING_DONE_SHORT",
    crit = "ITEM_MOD_CRIT_RATING_SHORT",
    hit = "ITEM_MOD_HIT_RATING_SHORT",
    haste = "ITEM_MOD_HASTE_RATING_SHORT",
    arp = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    expertise = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    defense = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    dodge = "ITEM_MOD_DODGE_RATING_SHORT",
    parry = "ITEM_MOD_PARRY_RATING_SHORT",
    block = "ITEM_MOD_BLOCK_RATING_SHORT",
    blockvalue = "ITEM_MOD_BLOCK_VALUE_SHORT",
    armor = "RESISTANCE0_NAME",
    mp5 = "ITEM_MOD_MANA_REGENERATION_SHORT"
}

local SIGNAL_STEP = {
    str = 0.020, agi = 0.020, int = 0.020, spi = 0.020, sta = 0.020,
    ap = 0.012, sp = 0.012, heal = 0.018, crit = 0.025, haste = 0.025,
    hit = 0.020, expertise = 0.025, arp = 0.025, defense = 0.030,
    dodge = 0.030, parry = 0.030, block = 0.035, blockvalue = 0.035,
    armor = 0.025, mp5 = 0.020
}

local MAX_SIGNAL_BONUS = {
    ap = 0.10, sp = 0.10, crit = 0.18, haste = 0.16,
    defense = 0.20, dodge = 0.20, parry = 0.20, block = 0.22,
    blockvalue = 0.22, armor = 0.18
}

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function Copy(source)
    local result = {}
    local key, value
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function PlayerLevel()
    if type(UnitLevel) == "function" then
        local ok, level = pcall(UnitLevel, "player")
        if ok and tonumber(level) then return tonumber(level) end
    end
    return 1
end

local function CharacterKey(presetKey)
    local name = type(UnitName) == "function" and UnitName("player") or "player"
    local realm = type(GetRealmName) == "function" and GetRealmName() or "realm"
    return tostring(realm or "realm") .. ":" .. tostring(name or "player") .. ":" .. tostring(presetKey or "unknown")
end

local function ActiveRank(node)
    if type(C_CharacterAdvancement) ~= "table" then return nil end

    if type(C_CharacterAdvancement.GetTalentRankByID) == "function" then
        local ok, rank = pcall(C_CharacterAdvancement.GetTalentRankByID, node.id)
        if ok and tonumber(rank) and tonumber(rank) > 0 then return tonumber(rank) end
    end

    if type(C_CharacterAdvancement.GetTalentRankBySpellID) == "function" then
        local _, spellID
        for _, spellID in ipairs(node.spells or {}) do
            local ok, rank = pcall(C_CharacterAdvancement.GetTalentRankBySpellID, spellID)
            if ok and tonumber(rank) and tonumber(rank) > 0 then return tonumber(rank) end
        end
    end
    return 0
end

local function SpellbookCount()
    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellName) ~= "function"
    then
        return 0, "indisponible"
    end
    local count = 0
    local tab
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        local index
        for index = (tonumber(offset) or 0) + 1, (tonumber(offset) or 0) + (tonumber(numSpells) or 0) do
            local name = GetSpellName(index, BOOKTYPE_SPELL or "spell")
            if name then count = count + 1 end
        end
    end
    return count, "spellbook"
end

local function ApplyLevelBand(weights, level, changes)
    local primaryFactor, staminaFactor, secondaryFactor = 1, 1, 1
    local band = "niveau maximum"
    if level < 20 then
        primaryFactor, staminaFactor, secondaryFactor, band = 1.08, 1.10, 0.90, "1-19"
    elseif level < 40 then
        primaryFactor, staminaFactor, secondaryFactor, band = 1.04, 1.06, 0.95, "20-39"
    elseif level < 50 then
        primaryFactor, staminaFactor, secondaryFactor, band = 1.02, 1.03, 0.98, "40-49"
    elseif level < 60 then
        band = "50-59"
    end

    local _, key
    for _, key in ipairs({ STAT_KEYS.str, STAT_KEYS.agi, STAT_KEYS.int }) do
        if (weights[key] or 0) > 0 and not (CoALootDeciderDB and CoALootDeciderDB.customWeights
            and CoALootDeciderDB.customWeights[key] ~= nil)
        then
            weights[key] = weights[key] * primaryFactor
        end
    end
    if (weights[STAT_KEYS.sta] or 0) > 0 and not (CoALootDeciderDB and CoALootDeciderDB.customWeights
        and CoALootDeciderDB.customWeights[STAT_KEYS.sta] ~= nil)
    then
        weights[STAT_KEYS.sta] = weights[STAT_KEYS.sta] * staminaFactor
    end
    for _, key in ipairs({ STAT_KEYS.hit, STAT_KEYS.haste, STAT_KEYS.expertise, STAT_KEYS.arp }) do
        if (weights[key] or 0) > 0 and not (CoALootDeciderDB and CoALootDeciderDB.customWeights
            and CoALootDeciderDB.customWeights[key] ~= nil)
        then
            weights[key] = weights[key] * secondaryFactor
        end
    end
    if band ~= "niveau maximum" and band ~= "50-59" then
        table.insert(changes, "ajustement leveling " .. band)
    end
    return band
end

local function ResolveClassData(className)
    if type(CoALootTalentData) ~= "table" or type(CoALootTalentData.classes) ~= "table" then return nil end
    if CoALootTalentData.classes[className] then return CoALootTalentData.classes[className] end
    local key, value
    for key, value in pairs(CoALootTalentData.classes) do
        if Lower(key) == Lower(className) then return value end
    end
    return nil
end

local function SavedFallback(presetKey)
    local builds = CoALootDeciderDB and CoALootDeciderDB.adaptiveBuilds or nil
    return builds and builds[CharacterKey(presetKey)] or nil
end

local function SaveSnapshot(presetKey, result)
    if not CoALootDeciderDB then return end
    CoALootDeciderDB.adaptiveBuilds = CoALootDeciderDB.adaptiveBuilds or {}
    CoALootDeciderDB.adaptiveBuilds[CharacterKey(presetKey)] = {
        presetKey = presetKey,
        level = result.level,
        selectedCount = result.selectedCount,
        selectedSignalCount = result.selectedSignalCount,
        selectedNames = result.selectedNames,
        signals = result.signals,
        weaponSignals = result.weaponSignals,
        spellbookCount = result.spellbookCount,
        signature = result.signature,
        savedAt = type(time) == "function" and time() or 0
    }
end

function CoALootAdaptation.Scan(className, specName, presetKey, baseWeights, baseWeaponRule)
    local result = {
        enabled = true,
        level = PlayerLevel(),
        selectedCount = 0,
        selectedSignalCount = 0,
        queriedCount = 0,
        selectedNames = {},
        signals = {},
        weaponSignals = {},
        changes = {},
        confidence = "basse",
        source = CoALootTalentData and CoALootTalentData.source or "indisponible"
    }
    local weights = Copy(baseWeights)
    local weaponRule = Copy(baseWeaponRule)
    result.levelBand = ApplyLevelBand(weights, result.level, result.changes)
    result.spellbookCount, result.spellbookSource = SpellbookCount()

    local classData = ResolveClassData(className)
    local expectedTab = CoALootTalentData and CoALootTalentData.profileTabs
        and CoALootTalentData.profileTabs[presetKey] or specName
    result.expectedTab = expectedTab
    if not classData then
        result.error = "classe absente de la base de talents"
        return weights, weaponRule, result
    end

    local apiAvailable = type(C_CharacterAdvancement) == "table"
        and (type(C_CharacterAdvancement.GetTalentRankByID) == "function"
            or type(C_CharacterAdvancement.GetTalentRankBySpellID) == "function")
    local selectedIDs = {}
    local _, node
    if apiAvailable then
        for _, node in ipairs(classData.nodes or {}) do
            if node.tab == "Class" or Lower(node.tab) == Lower(expectedTab) then
                result.queriedCount = result.queriedCount + 1
                local rank = ActiveRank(node) or 0
                if rank > 0 then
                    result.selectedCount = result.selectedCount + 1
                    table.insert(selectedIDs, tostring(node.id) .. "x" .. tostring(rank))
                    local hasSignal = next(node.signals or {}) or next(node.weapons or {})
                    if hasSignal then
                        result.selectedSignalCount = result.selectedSignalCount + 1
                        if #result.selectedNames < 12 then table.insert(result.selectedNames, node.name) end
                    end
                    local stat, strength
                    for stat, strength in pairs(node.signals or {}) do
                        result.signals[stat] = (result.signals[stat] or 0) + (tonumber(strength) or 0) * rank
                    end
                    local weapon
                    for weapon in pairs(node.weapons or {}) do
                        result.weaponSignals[weapon] = (result.weaponSignals[weapon] or 0) + rank
                    end
                end
            end
        end
        table.sort(selectedIDs)
        result.signature = table.concat(selectedIDs, ",")
        if result.selectedCount > 0 then
            result.confidence = "haute"
            SaveSnapshot(presetKey, result)
        else
            local saved = SavedFallback(presetKey)
            if saved and result.level >= 10 then
                result.selectedCount = tonumber(saved.selectedCount) or 0
                result.selectedSignalCount = tonumber(saved.selectedSignalCount) or 0
                result.selectedNames = saved.selectedNames or {}
                result.signals = saved.signals or {}
                result.weaponSignals = saved.weaponSignals or {}
                result.signature = saved.signature or ""
                result.confidence = "moyenne"
                result.fallback = "dernier profil memorise ; API vide pendant le chargement"
            else
                result.confidence = "moyenne"
            end
        end
    else
        local saved = SavedFallback(presetKey)
        if saved then
            result.selectedCount = tonumber(saved.selectedCount) or 0
            result.selectedSignalCount = tonumber(saved.selectedSignalCount) or 0
            result.selectedNames = saved.selectedNames or {}
            result.signals = saved.signals or {}
            result.weaponSignals = saved.weaponSignals or {}
            result.signature = saved.signature or ""
            result.confidence = "moyenne"
            result.fallback = "dernier profil de talents memorise"
        else
            result.error = "API C_CharacterAdvancement indisponible et aucun profil memorise"
        end
    end

    local stat, strength
    for stat, strength in pairs(result.signals) do
        local key = STAT_KEYS[stat]
        if key and (weights[key] or 0) > 0
            and not (CoALootDeciderDB and CoALootDeciderDB.customWeights
                and CoALootDeciderDB.customWeights[key] ~= nil)
        then
            local step = SIGNAL_STEP[stat] or 0.015
            local cap = MAX_SIGNAL_BONUS[stat] or 0.14
            local bonus = math.min(cap, (tonumber(strength) or 0) * step)
            if bonus > 0 then
                weights[key] = weights[key] * (1 + bonus)
                table.insert(result.changes, stat .. " +" .. math.floor(bonus * 100 + 0.5) .. "% (talents)")
            end
        end
    end

    if (result.weaponSignals.twoHand or 0) > 0 then
        weaponRule.preferTwoHand = true
        weaponRule.detectedFromTalents = true
        table.insert(result.changes, "arme 2M favorisee par les talents")
    end
    if (result.weaponSignals.dualWield or 0) > 0 then
        weaponRule.preferDualWield = true
        weaponRule.detectedFromTalents = true
        table.insert(result.changes, "deux armes 1M favorisees par les talents")
    end
    if (result.weaponSignals.shield or 0) > 0 then
        weaponRule.preferShield = true
        weaponRule.detectedFromTalents = true
        table.insert(result.changes, "bouclier favorise par les talents")
    end
    return weights, weaponRule, result
end

function CoALootAdaptation.Summary(adaptive)
    if not adaptive then return "adaptation indisponible" end
    local status = adaptive.error and ("limitee : " .. adaptive.error) or "active"
    return status .. " ; talents=" .. tostring(adaptive.selectedCount or 0)
        .. "/" .. tostring(adaptive.queriedCount or 0)
        .. " ; signaux stuff=" .. tostring(adaptive.selectedSignalCount or 0)
        .. " ; spellbook=" .. tostring(adaptive.spellbookCount or 0)
        .. " ; niveau=" .. tostring(adaptive.level or 0) .. " (" .. tostring(adaptive.levelBand or "?") .. ")"
        .. " ; confiance=" .. tostring(adaptive.confidence or "basse")
end
