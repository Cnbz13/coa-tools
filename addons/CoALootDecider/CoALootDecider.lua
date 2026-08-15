local addonName = ...

local ROLL_PASS = 0
local ROLL_NEED = 1
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

local PRIMARY_STATS = {
    "ITEM_MOD_STRENGTH_SHORT",
    "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_INTELLECT_SHORT"
}

local PRIMARY_STAT_KEYS = {
    Strength = "ITEM_MOD_STRENGTH_SHORT",
    Agility = "ITEM_MOD_AGILITY_SHORT",
    Intellect = "ITEM_MOD_INTELLECT_SHORT"
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
    CoALootDeciderDB.threshold = tonumber(CoALootDeciderDB.threshold) or 1
    CoALootDeciderDB.itemLevelWeight = tonumber(CoALootDeciderDB.itemLevelWeight) or 0.35
    CoALootDeciderDB.customWeights = CoALootDeciderDB.customWeights or {}
    CoALootDeciderDB.history = CoALootDeciderDB.history or {}
    CoALootDeciderDB.version = "0.2.1"
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

local function ItemData(itemLink)
    if not itemLink or not GetItemInfo then return nil end
    local name, link, quality, itemLevel, requiredLevel, itemType, itemSubType, stackCount, equipLoc, texture = GetItemInfo(itemLink)
    if not name or not equipLoc then return nil end
    return {
        name = name,
        link = link or itemLink,
        quality = tonumber(quality) or 0,
        itemLevel = tonumber(itemLevel) or 0,
        requiredLevel = tonumber(requiredLevel) or 0,
        itemType = itemType,
        itemSubType = itemSubType,
        stackCount = tonumber(stackCount) or 1,
        equipLoc = equipLoc,
        texture = texture,
        stats = ReadItemStats(link or itemLink)
    }
end

local effectScanner = CreateFrame("GameTooltip", "CoALootDeciderEffectScanner", nil, "GameTooltipTemplate")
effectScanner:SetOwner(UIParent, "ANCHOR_NONE")

local function HasUnscoredEffect(itemLink)
    if not itemLink then return false end
    effectScanner:ClearLines()
    local success = pcall(effectScanner.SetHyperlink, effectScanner, itemLink)
    if not success then return true end

    local line
    for line = 2, effectScanner:NumLines() do
        local fontString = _G["CoALootDeciderEffectScannerTextLeft" .. line]
        local rawText = fontString and fontString:GetText() or ""
        local text = Lower(rawText)
        if string.find(text, "equip:", 1, true)
            or string.find(text, "use:", 1, true)
            or string.find(text, "chance on hit", 1, true)
            or string.find(text, "equipe :", 1, true)
            or string.find(text, "equipe:", 1, true)
            or string.find(rawText, "Équipé", 1, true)
            or string.find(rawText, "Équipée", 1, true)
            or string.find(text, "utiliser :", 1, true)
            or string.find(text, "utiliser:", 1, true)
            or string.find(text, "chance de", 1, true)
        then
            effectScanner:Hide()
            return true
        end
    end
    effectScanner:Hide()
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
            return {
                className = className or classToken or "Classe inconnue",
                classToken = classToken,
                specializationIndex = specializationIndex,
                specializationID = catalogID or specializationID,
                specInfo = specInfo,
                specName = specInfo.Name or tostring(spec),
                primaryStats = specInfo.PrimaryStats or {}
            }
        end
    end
    return nil, "specialisation absente du catalogue " .. tostring(classToken)
        .. " (index=" .. tostring(specializationIndex)
        .. ", id=" .. tostring(specializationID)
        .. ", nom=" .. tostring(specializationName or "inconnu") .. ")"
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
        caster = acceptedPrimaries.ITEM_MOD_INTELLECT_SHORT and true or false
        physical = (acceptedPrimaries.ITEM_MOD_STRENGTH_SHORT or acceptedPrimaries.ITEM_MOD_AGILITY_SHORT) and true or false
    end

    local weights = {
        ITEM_MOD_STRENGTH_SHORT = acceptedPrimaries.ITEM_MOD_STRENGTH_SHORT and 2.00 or 0,
        ITEM_MOD_AGILITY_SHORT = acceptedPrimaries.ITEM_MOD_AGILITY_SHORT and 2.00 or 0,
        ITEM_MOD_INTELLECT_SHORT = acceptedPrimaries.ITEM_MOD_INTELLECT_SHORT and 2.00 or 0,
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

    local weights, acceptedPrimaries, physical, caster, strictError = StrictWeights(specialization)
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
        scannedAt = GetTime and GetTime() or 0
    }
    return profile
end

local function ScoreItem(data)
    if not data or not profile then return 0 end
    local score = data.itemLevel * CoALootDeciderDB.itemLevelWeight
    local key, value
    for key, value in pairs(data.stats or {}) do
        score = score + (tonumber(value) or 0) * (profile.weights[key] or 0)
    end
    return score
end

local function CompatibilityProblem(data)
    if not profile or not profile.valid then
        return profile and profile.error or "profil CoA non detecte"
    end

    local _, key
    for _, key in ipairs(PRIMARY_STATS) do
        if StatValue(data.stats, key) > 0 and not profile.acceptedPrimaries[key] then
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

local function ComparisonFor(data)
    local slots = EQUIP_SLOTS[data.equipLoc]
    if not slots then return nil, nil, "type d'objet non equipable" end

    if data.equipLoc == "INVTYPE_2HWEAPON" then
        local main = profile.items[16]
        local off = profile.items[17]
        local combined = ScoreItem(main) + ScoreItem(off)
        local currentLevel = math.max(main and main.itemLevel or 0, off and off.itemLevel or 0)
        return combined, currentLevel, main and main.link or nil
    end

    if data.equipLoc == "INVTYPE_WEAPON" and not profile.items[17] then
        local main = profile.items[16]
        return ScoreItem(main), main and main.itemLevel or 0, main and main.link or nil
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
    return lowestScore or 0, lowestLevel or 0, lowestLink
end

local function EvaluateItem(itemLink)
    profile = ScanEquipment()
    if not profile.valid then return nil, profile.error end
    local candidate = ItemData(itemLink)
    if not candidate then return nil, "informations d'objet indisponibles" end
    if not EQUIP_SLOTS[candidate.equipLoc] then
        return { need = false, candidate = candidate, reason = "objet non equipable", confidence = "haute" }
    end
    local compatibilityProblem = CompatibilityProblem(candidate)
    if compatibilityProblem then
        return { need = false, candidate = candidate, reason = compatibilityProblem, confidence = "haute" }
    end
    if candidate.equipLoc == "INVTYPE_TRINKET" then
        return nil, "bijou avec effet non chiffrable : decision manuelle requise"
    end
    if HasUnscoredEffect(candidate.link) then
        return nil, "effet Equipe/Utiliser non chiffrable : decision manuelle requise"
    end
    if not next(candidate.stats or {}) then
        return nil, "aucune statistique chiffrable : decision manuelle requise"
    end

    local currentScore, currentLevel, currentLinkOrReason = ComparisonFor(candidate)
    if currentScore == nil then
        return { need = false, candidate = candidate, reason = currentLinkOrReason or "comparaison impossible", confidence = "basse" }
    end

    local candidateScore = ScoreItem(candidate)
    local delta = candidateScore - currentScore
    local percent = currentScore > 0 and delta / currentScore * 100 or (candidateScore > 0 and 100 or 0)
    local minimum = math.max(1, currentScore * (CoALootDeciderDB.threshold / 100))
    local need = currentScore <= 0 and candidateScore > 0 or delta >= minimum
    local reason
    if currentScore <= 0 and candidateScore > 0 then
        reason = "emplacement vide"
    elseif need then
        reason = "+" .. Round(percent, 1) .. "% (ilvl " .. candidate.itemLevel .. " contre " .. currentLevel .. ")"
    else
        reason = Round(percent, 1) .. "% (ilvl " .. candidate.itemLevel .. " contre " .. currentLevel .. ")"
    end

    return {
        need = need,
        candidate = candidate,
        candidateScore = candidateScore,
        currentScore = currentScore,
        currentLevel = currentLevel,
        currentLink = currentLinkOrReason,
        percent = percent,
        reason = reason,
        confidence = next(candidate.stats or {}) and "haute" or "moyenne"
    }
end

local banner = CreateFrame("Frame", "CoALootDeciderBanner", UIParent)
banner:SetWidth(430)
banner:SetHeight(68)
banner:SetPoint("TOP", UIParent, "TOP", 0, -150)
banner:SetFrameStrata("DIALOG")
banner:Hide()

banner.background = banner:CreateTexture(nil, "BACKGROUND")
banner.background:SetAllPoints(banner)
banner.background:SetTexture(0, 0, 0, 0.86)

banner.icon = banner:CreateTexture(nil, "ARTWORK")
banner.icon:SetWidth(48)
banner.icon:SetHeight(48)
banner.icon:SetPoint("LEFT", banner, "LEFT", 10, 0)

banner.verdict = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
banner.verdict:SetPoint("TOPLEFT", banner.icon, "TOPRIGHT", 12, -2)
banner.verdict:SetJustifyH("LEFT")

banner.detail = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
banner.detail:SetPoint("TOPLEFT", banner.verdict, "BOTTOMLEFT", 0, -5)
banner.detail:SetWidth(350)
banner.detail:SetJustifyH("LEFT")

banner.expires = 0
banner:SetScript("OnUpdate", function(self)
    if self.expires > 0 and GetTime() >= self.expires then self:Hide() end
end)

local function ShowDecision(decision, automatic)
    local candidate = decision.candidate or {}
    banner.icon:SetTexture(candidate.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if decision.need then
        banner.verdict:SetText("|cff3cff52NEED|r  " .. (candidate.link or candidate.name or "Objet"))
    else
        banner.verdict:SetText("|cffff5b5bPASS|r  " .. (candidate.link or candidate.name or "Objet"))
    end
    banner.detail:SetText((automatic and "Jet automatique - " or "Conseil - ") .. (decision.reason or "raison inconnue"))
    banner.expires = GetTime() + 6
    banner:Show()
end

local function ShowManual(itemLink, itemName, reason)
    local data = ItemData(itemLink)
    banner.icon:SetTexture(data and data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    banner.verdict:SetText("|cffffcc33CHOIX MANUEL|r  " .. (itemLink or itemName or "Objet"))
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
        decision = decision.need and "NEED" or "PASS",
        reason = decision.reason,
        automatic = automatic and true or false
    })
    while #history > HISTORY_LIMIT do table.remove(history) end
end

local function ApplyRoll(rollID, decision, canNeed)
    if decision.need and not canNeed then
        decision.need = false
        decision.reason = "NEED indisponible pour cet objet"
    end
    local rollType = decision.need and ROLL_NEED or ROLL_PASS
    local automatic = CoALootDeciderDB.autoRoll and RollOnLoot ~= nil
    ShowDecision(decision, automatic)
    AddHistory(rollID, decision, automatic)
    Chat((decision.need and "NEED " or "PASS ") .. (decision.candidate.link or decision.candidate.name or "objet") .. " - " .. decision.reason)

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

    local _, _, _, _, _, canNeed = GetLootRollItemInfo(rollID)
    ApplyRoll(rollID, decision, canNeed)
    pendingRolls[rollID] = nil
    return true
end

local function LeaveUnknownRoll(rollID, reason)
    local _, name = GetLootRollItemInfo(rollID)
    local itemLink = GetLootRollItemLink and GetLootRollItemLink(rollID) or nil
    reason = reason or "objet impossible a analyser dans le delai"
    ShowManual(itemLink, name, reason)
    Chat("aucun jet automatique pour " .. (itemLink or name or "objet") .. " : " .. tostring(reason))
    pendingRolls[rollID] = nil
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("START_LOOT_ROLL")
eventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
eventFrame:RegisterEvent("CONFIRM_LOOT_ROLL")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDatabase()
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
    return profile.className .. " - " .. profile.specName .. " [" .. profile.role .. "]"
        .. " | physique=" .. (profile.physical and "oui" or "non")
        .. ", caster=" .. (profile.caster and "oui" or "non")
        .. " | " .. table.concat(values, ", ")
end

local function PrintHelp()
    Chat("/cld status - etat et profil detecte")
    Chat("/cld auto - active/desactive NEED/PASS automatique")
    Chat("/cld confirm - confirme automatiquement les objets lies")
    Chat("/cld scan - rescane l'equipement")
    Chat("/cld test [lien] - compare un objet sans lancer de jet")
    Chat("/cld threshold 1 - gain minimum en pourcentage")
    Chat("/cld weight <stat> <valeur|auto> - surcharge un poids")
    Chat("/cld history - affiche les dix dernieres decisions")
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
        Chat("auto=" .. (CoALootDeciderDB.autoRoll and "ACTIF" or "inactif")
            .. ", confirmation=" .. (CoALootDeciderDB.autoConfirm and "active" or "inactive")
            .. ", seuil=" .. CoALootDeciderDB.threshold .. "%")
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
    elseif command == "threshold" then
        local threshold = tonumber(rest)
        if not threshold or threshold < 0 or threshold > 100 then
            Chat("seuil attendu entre 0 et 100")
        else
            CoALootDeciderDB.threshold = threshold
            Chat("gain minimum regle a " .. threshold .. "%")
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
    elseif command == "history" then
        local index, entry
        for index, entry in ipairs(CoALootDeciderDB.history) do
            if index > 10 then break end
            Chat(index .. ". " .. entry.decision .. " " .. (entry.itemLink or entry.itemName) .. " - " .. (entry.reason or ""))
        end
        if #CoALootDeciderDB.history == 0 then Chat("aucune decision enregistree") end
    else
        PrintHelp()
    end
end
