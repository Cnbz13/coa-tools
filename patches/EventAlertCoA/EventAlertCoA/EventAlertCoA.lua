-- Thin Project Ascension compatibility layer for the genuine EventAlert 4.3.6 addon.
-- EventAlert remains responsible for every icon, sound, option and saved position.

local COA_COMPAT_VERSION = "1.5.8"
local BOOK = BOOKTYPE_SPELL or "spell"
local AUTO_LEARN_DEFAULT = true
local PROC_MAX_DURATION = 60
local SMART_FILTER_VERSION = 2
local recentCasts = {}
local spellbookIds = {}
local spellbookNames = {}
local pendingAuras = {}
local activeAuraIds = {}
local activeAuraProfileKey = nil
local pendingElapsed = 0
local activeProfile = nil
local activeProfileKey = nil
local initialized = false
local safePositionerInstalled = false
local buffManagerFrame = nil
local buffManagerRows = {}
local buffManagerPage = 1
local BUFFS_PER_PAGE = 10
local procScannerTooltip = nil
local RemoveActiveBuff
local TooltipReferencesLearnedSpell
local ConfirmedForActiveProfile
local WasDirectlyCast
local ScanActiveAuras
local IsTracked

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function NormalizedName(value)
    return string.gsub(Lower(value), "[^%a%d]", "")
end

-- CoA Build Hub documents the public class/spec catalogue. The client API is
-- still authoritative: this catalogue validates the resolved profile and
-- provides a stable fallback label when a community page or patch note lags.
local coaSpecializationCatalog = {
    barbarian = { brutality = true, headhunting = true, ancestry = true },
    witchdoctor = { voodoo = true, brewing = true, shadowhunting = true },
    felsworn = { slayer = true, infernal = true, tyrant = true },
    witchhunter = { boltslinger = true, houndmaster = true, blackknight = true, inquisition = true },
    stormbringer = { lightning = true, wind = true, maelstrom = true },
    knightofxoroth = { hellfire = true, war = true, defiance = true },
    guardian = { vanguard = true, inspiration = true, gladiator = true },
    templar = { zealot = true, oathkeeper = true, crusader = true },
    bloodmage = { sanguine = true, accursed = true, eternal = true, fleshweaver = true },
    ranger = { farstrider = true, archery = true, brigand = true },
    chronomancer = { infinite = true, artificer = true, time = true },
    necromancer = { death = true, rime = true, animation = true },
    pyromancer = { flameweaving = true, incineration = true, draconic = true },
    cultist = { godblade = true, corruption = true, heretic = true, dreadnought = true },
    starcaller = { moonguard = true, moonpriest = true, sentinel = true, warden = true },
    suncleric = { piety = true, blessings = true, seraphim = true, valkyrie = true },
    tinker = { demolition = true, invention = true, mechanics = true },
    venomancer = { venom = true, stalking = true, fortitude = true, vizier = true },
    reaper = { harvest = true, soul = true, domination = true },
    primalist = { primal = true, geomancy = true, life = true, mountainking = true },
    runemaster = { runic = true, arcane = true, riftblade = true }
}

local function ResolveActiveProfile()
    local className, classToken = UnitClass("player")
    className = className or classToken or "Classe inconnue"
    classToken = classToken or NormalizedName(className)
    local specializationIndex = nil
    local specializationID = nil
    local specializationName = nil
    local specInfo = nil

    if type(GetSpecialization) == "function" then
        local success, value = pcall(GetSpecialization)
        if success then specializationIndex = tonumber(value) end
    end
    if specializationIndex and specializationIndex > 0 and type(GetSpecializationInfo) == "function" then
        local success, resolvedID, resolvedName = pcall(GetSpecializationInfo, specializationIndex)
        if success then
            specializationID = tonumber(resolvedID)
            if type(resolvedName) == "string" and resolvedName ~= "" then specializationName = resolvedName end
        end
    end

    if specializationIndex and specializationIndex > 0
        and type(C_ClassInfo) == "table"
        and type(C_ClassInfo.GetAllSpecs) == "function"
        and type(C_ClassInfo.GetSpecInfo) == "function"
    then
        local success, specs = pcall(C_ClassInfo.GetAllSpecs, classToken)
        if success and type(specs) == "table" then
            local catalogIndex, spec
            for catalogIndex, spec in ipairs(specs) do
                local infoSuccess, candidate = pcall(C_ClassInfo.GetSpecInfo, classToken, spec)
                local candidateID = infoSuccess and candidate and tonumber(candidate.ID) or nil
                local candidateName = infoSuccess and candidate and candidate.Name or nil
                local idMatches = candidateID and (candidateID == specializationID or candidateID == specializationIndex)
                local keyMatches = tonumber(spec) and (tonumber(spec) == specializationID or tonumber(spec) == specializationIndex)
                local nameMatches = specializationName and candidateName
                    and NormalizedName(specializationName) == NormalizedName(candidateName)
                local positionMatches = not specializationName and not specializationID and catalogIndex == specializationIndex
                if infoSuccess and candidate and (idMatches or keyMatches or nameMatches or positionMatches) then
                    specInfo = candidate
                    specializationID = candidateID or specializationID or specializationIndex
                    specializationName = candidateName or specializationName
                    break
                end
            end
        end
    end

    if not specializationName and type(GetNumTalentTabs) == "function" and type(GetTalentTabInfo) == "function" then
        local bestPoints = -1
        local tab
        for tab = 1, (GetNumTalentTabs() or 0) do
            local name, _, pointsSpent = GetTalentTabInfo(tab)
            pointsSpent = tonumber(pointsSpent) or 0
            if name and pointsSpent > bestPoints then
                bestPoints = pointsSpent
                specializationName = name
                specializationID = specializationID or tab
            end
        end
    end

    if not specializationName and activeProfile and activeProfile.classToken == classToken then
        return activeProfile
    end
    specializationName = specializationName or "Specialisation inconnue"
    specializationID = specializationID or specializationIndex or NormalizedName(specializationName)
    local classKey = NormalizedName(classToken)
    local specKey = NormalizedName(specializationName)
    return {
        key = tostring(classToken) .. ":" .. tostring(specializationID),
        className = className,
        classToken = classToken,
        specializationID = specializationID,
        specName = specializationName,
        sourceKey = classKey .. ":" .. specKey,
        catalogConfirmed = coaSpecializationCatalog[classKey] and coaSpecializationCatalog[classKey][specKey] == true,
        healer = specInfo and specInfo.Healer == true or false,
        tank = specInfo and specInfo.Tank == true or false,
        caster = specInfo and (specInfo.CasterDPS == true or specInfo.Healer == true) or false,
        melee = specInfo and specInfo.MeleeDPS == true or false,
        ranged = specInfo and specInfo.RangedDPS == true or false
    }
end

local ignoredNameFragments = {
    "keeper's scroll:", "titan scroll:", "crafting speed", "gathering speed"
}

local ignoredExactNames = {
    ["heat"] = true,
    ["ember"] = true
}

-- Confirmed action windows from public CoA class data and observed spellbooks.
local confirmedUsefulProcNames = {
    ["flamecasting"] = true,
    ["sageweaving"] = true,
    ["fired up!"] = true,
    ["superheated"] = true
}

-- These names are accepted automatically only for the specialization whose
-- public rotation/talent data identifies them. A tooltip/spellbook match can
-- still validate a renamed proc without waiting for this table to be updated.
local confirmedProcProfiles = {
    ["flamecasting"] = { ["pyromancer:flameweaving"] = true },
    ["sageweaving"] = { ["pyromancer:flameweaving"] = true },
    ["fired up!"] = { ["pyromancer:incineration"] = true },
    ["superheated"] = { ["pyromancer:incineration"] = true }
}

local actionableTooltipFragments = {
    "your next", "next spell", "next ability", "becomes instant", "cast time",
    "critical strike chance", "damage done is increased", "damage dealt is increased",
    "healing done is increased", "increases all damage", "increases all healing",
    "costs no", "no mana cost", "can be cast", "cooldown is reset", "resets the cooldown",
    "free and instant", "without consuming", "grants an additional charge", "empowers your next",
    "votre prochain", "prochain sort", "prochaine technique", "devient instantane",
    "temps d'incantation", "cout en mana", "reinitialise le temps de recharge"
}

local passiveTooltipFragments = {
    "absorbs", "every sec", "restores", "movement speed", "mounted speed",
    "armor by", "resistance by", "regenerates", "heals the target for",
    "increases your armor", "increases resistance", "experience gained", "reputation gained",
    "vitesse de deplacement", "rend toutes les", "absorbe", "armure augmentee"
}

local function Now()
    return GetTime and GetTime() or 0
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00EventAlert CoA:|r " .. tostring(message))
    end
end

local function IsEventAlertReady()
    return type(EA_Config) == "table"
        and type(EA_Items) == "table"
        and type(EA_AltItems) == "table"
        and type(EA_CustomItems) == "table"
        and type(EventAlert_PositionFrames) == "function"
        and type(EventAlert_DoAlert) == "function"
end

local function ProfileTable(profile, name)
    profile[name] = profile[name] or {}
    return profile[name]
end

local function BindActiveProfile()
    local resolved = ResolveActiveProfile()
    EA_Config.CoA.Profiles = EA_Config.CoA.Profiles or {}
    EA_Config.CoA.ManagedSpellIds = EA_Config.CoA.ManagedSpellIds or {}
    EA_Config.CoA.ManagedAltIds = EA_Config.CoA.ManagedAltIds or {}

    local isLegacy = EA_Config.CoA.ProfileStorageVersion ~= 1
    local profile = EA_Config.CoA.Profiles[resolved.key]
    if not profile and activeProfileKey and activeProfile
        and activeProfile.classToken == resolved.classToken
        and activeProfile.specName == "Specialisation inconnue"
    then
        profile = EA_Config.CoA.Profiles[activeProfileKey]
        EA_Config.CoA.Profiles[activeProfileKey] = nil
        EA_Config.CoA.Profiles[resolved.key] = profile
    end
    if not profile then
        profile = {
            className = resolved.className,
            classToken = resolved.classToken,
            specializationID = resolved.specializationID,
            specName = resolved.specName,
            sourceKey = resolved.sourceKey,
            KnownBuffs = isLegacy and (EA_Config.CoA.KnownBuffs or {}) or {},
            DisabledBuffs = isLegacy and (EA_Config.CoA.DisabledBuffs or {}) or {},
            ManualBuffs = isLegacy and (EA_Config.CoA.ManualBuffs or {}) or {},
            FilterReasons = isLegacy and (EA_Config.CoA.FilterReasons or {}) or {},
            Candidates = {},
            Reactions = {}
        }
        EA_Config.CoA.Profiles[resolved.key] = profile
    end
    ProfileTable(profile, "KnownBuffs")
    ProfileTable(profile, "DisabledBuffs")
    ProfileTable(profile, "ManualBuffs")
    ProfileTable(profile, "FilterReasons")
    ProfileTable(profile, "Candidates")
    ProfileTable(profile, "Reactions")
    profile.className = resolved.className
    profile.classToken = resolved.classToken
    profile.specializationID = resolved.specializationID
    profile.specName = resolved.specName
    profile.sourceKey = resolved.sourceKey
    profile.catalogConfirmed = resolved.catalogConfirmed

    if activeProfileKey ~= resolved.key then
        local index
        for index = #(EA_TempBuffsTable or {}), 1, -1 do
            local activeSpellId = tonumber(EA_TempBuffsTable[index]) or EA_TempBuffsTable[index]
            local activeFrame = _G["EAFrame_" .. tostring(activeSpellId)]
            if activeFrame then activeFrame:ClearAllPoints(); activeFrame:Hide() end
            table.remove(EA_TempBuffsTable, index)
        end
        local rawSpellId
        for rawSpellId in pairs(EA_Config.CoA.ManagedSpellIds) do
            local spellId = tonumber(rawSpellId) or rawSpellId
            EA_CustomItems[spellId] = nil
            EA_CustomItems[tostring(spellId)] = nil
            if RemoveActiveBuff then RemoveActiveBuff(spellId) end
        end
        for rawSpellId in pairs(EA_Config.CoA.ManagedAltIds) do
            local spellId = tonumber(rawSpellId) or rawSpellId
            EA_AltItems[spellId] = nil
            EA_AltItems[tostring(spellId)] = nil
            if RemoveActiveBuff then RemoveActiveBuff(spellId) end
        end
    end

    activeProfile = resolved
    activeProfileKey = resolved.key
    EA_Config.CoA.ActiveProfileKey = resolved.key
    EA_Config.CoA.ProfileStorageVersion = 1
    EA_Config.CoA.KnownBuffs = profile.KnownBuffs
    EA_Config.CoA.DisabledBuffs = profile.DisabledBuffs
    EA_Config.CoA.ManualBuffs = profile.ManualBuffs
    EA_Config.CoA.FilterReasons = profile.FilterReasons
    EA_Config.CoA.Candidates = profile.Candidates
    EA_Config.CoA.Reactions = profile.Reactions

    local rawSpellId, enabled
    for rawSpellId, enabled in pairs(profile.KnownBuffs) do
        local spellId = tonumber(rawSpellId) or rawSpellId
        if enabled and profile.ManualBuffs[spellId] ~= false and not profile.DisabledBuffs[spellId] then
            EA_CustomItems[spellId] = true
            EA_Config.CoA.ManagedSpellIds[spellId] = true
        end
    end
    for rawSpellId in pairs(profile.Reactions) do
        local spellId = tonumber(rawSpellId) or rawSpellId
        EA_AltItems[spellId] = true
        EA_Config.CoA.ManagedAltIds[spellId] = true
    end
    return activeProfile
end

local function EnsureConfiguration(forceRefresh)
    if not IsEventAlertReady() then return false end
    if not forceRefresh and initialized and activeProfile and EA_Config and EA_Config.CoA then return true end
    EA_Config.CoA = EA_Config.CoA or {}
    if EA_Config.CoA.AutoLearn == nil then EA_Config.CoA.AutoLearn = AUTO_LEARN_DEFAULT end
    EA_Config.CoA.KnownBuffs = EA_Config.CoA.KnownBuffs or {}
    EA_Config.CoA.DisabledBuffs = EA_Config.CoA.DisabledBuffs or {}
    EA_Config.CoA.ManualBuffs = EA_Config.CoA.ManualBuffs or {}
    EA_Config.CoA.FilterReasons = EA_Config.CoA.FilterReasons or {}
    BindActiveProfile()
    if EA_Config.CoA.SmartFilterVersion ~= SMART_FILTER_VERSION then
        local disabledId, disabled
        for disabledId, disabled in pairs(EA_Config.CoA.DisabledBuffs) do
            local spellId = tonumber(disabledId) or disabledId
            if disabled and EA_Config.CoA.FilterReasons[spellId] ~= "desactive manuellement" then
                EA_Config.CoA.DisabledBuffs[disabledId] = nil
                EA_Config.CoA.ManualBuffs[spellId] = nil
            end
        end
        EA_Config.CoA.SmartFilterVersion = SMART_FILTER_VERSION
    end
    if EA_Config.CoA.Initialized == nil then
        EA_Config.AllowAltAlerts = true
        EA_Config.CoA.Initialized = true
    end
    EA_Config.CoA.Version = COA_COMPAT_VERSION
    EA_TempBuffsTable = EA_TempBuffsTable or {}
    EA_PreLoadAlts = EA_PreLoadAlts or {}
    local spellId, enabled
    for spellId, enabled in pairs(EA_CustomItems) do
        if enabled then
            spellId = tonumber(spellId) or spellId
            EA_Config.CoA.KnownBuffs[spellId] = EA_Config.CoA.KnownBuffs[spellId]
                or GetSpellInfo(spellId) or tostring(spellId)
        end
    end
    return true
end

local function ContainsFragment(text, fragments)
    text = string.lower(tostring(text or ""))
    local _, fragment
    for _, fragment in ipairs(fragments) do
        if string.find(text, fragment, 1, true) then return true end
    end
    return false
end

local function AuraTooltipText(index)
    if not GameTooltip then return "" end
    if not procScannerTooltip then
        procScannerTooltip = CreateFrame("GameTooltip", "EventAlertCoAProcScannerTooltip", UIParent, "GameTooltipTemplate")
        procScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    procScannerTooltip:ClearLines()
    if not pcall(procScannerTooltip.SetUnitBuff, procScannerTooltip, "player", index) then return "" end
    local parts = {}
    local line
    for line = 1, (procScannerTooltip:NumLines() or 0) do
        local left = _G["EventAlertCoAProcScannerTooltipTextLeft" .. line]
        local right = _G["EventAlertCoAProcScannerTooltipTextRight" .. line]
        if left and left:GetText() then table.insert(parts, left:GetText()) end
        if right and right:GetText() then table.insert(parts, right:GetText()) end
    end
    procScannerTooltip:Hide()
    return string.lower(table.concat(parts, " "))
end

local function FindPlayerAura(spellId, spellName)
    local index
    for index = 1, 40 do
        local auraName, _, _, count, _, duration, expirationTime, caster, _, _, auraSpellId = UnitBuff("player", index)
        if not auraName then break end
        auraSpellId = tonumber(auraSpellId)
        if (auraSpellId and auraSpellId == spellId) or (spellName and auraName == spellName) then
            return {
                index = index,
                name = auraName,
                count = tonumber(count) or 0,
                duration = tonumber(duration) or 0,
                expirationTime = tonumber(expirationTime) or 0,
                caster = caster,
                -- Tooltips are expensive on the 3.3.5 client. Load one only
                -- after the cheap ownership/duration/name filters passed.
                tooltip = nil
            }
        end
    end
    return nil
end

local function IsLikelyUsefulProc(spellId, spellName, observedAura)
    if not EnsureConfiguration() then return false, "configuration indisponible" end
    spellId = tonumber(spellId) or spellId
    local manual = EA_Config.CoA.ManualBuffs[spellId]
    if manual == true then return true, "selection manuelle" end
    if manual == false then return false, "desactive manuellement" end

    local lowerName = Lower(spellName or GetSpellInfo(spellId) or "")
    if ignoredExactNames[lowerName] then return false, "ressource passive" end
    if ContainsFragment(lowerName, ignoredNameFragments) then return false, "buff systeme persistant" end

    local aura = observedAura or FindPlayerAura(spellId, spellName)
    if not aura then return nil, "aura en attente de verification" end
    if aura.caster and aura.caster ~= "player" and aura.caster ~= "pet" then
        return false, "buff externe au personnage"
    end
    if aura.duration <= 0 then return false, "buff permanent ou passif" end
    if aura.duration > PROC_MAX_DURATION then return false, "buff longue duree" end
    if confirmedUsefulProcNames[lowerName] and ConfirmedForActiveProfile(lowerName) then
        return true, "proc confirme pour " .. tostring(activeProfile and activeProfile.specName or "la specialisation")
    end
    if confirmedUsefulProcNames[lowerName] and not ConfirmedForActiveProfile(lowerName) then
        return false, "proc repertorie pour une autre specialisation"
    end

    if aura.tooltip == nil then aura.tooltip = AuraTooltipText(aura.index) end
    local actionable = ContainsFragment(aura.tooltip, actionableTooltipFragments)
    local passive = ContainsFragment(aura.tooltip, passiveTooltipFragments)
    local learnedSpellReference = TooltipReferencesLearnedSpell(aura.tooltip)
    if actionable and learnedSpellReference then return true, "fenetre liee a un sort appris" end
    if actionable then return true, "fenetre d'action temporaire du profil actif" end
    if passive then return false, "effet passif temporaire" end
    return nil, "candidat observe sans action immediate confirmee"
end

local function IsBuffDisabled(spellId)
    if not EA_Config or not EA_Config.CoA or not EA_Config.CoA.DisabledBuffs then return false end
    spellId = tonumber(spellId) or spellId
    return EA_Config.CoA.DisabledBuffs[spellId] == true
        or EA_Config.CoA.DisabledBuffs[tostring(spellId)] == true
end

local function SpellIdFromBook(slot)
    if not GetSpellLink then return nil end
    local link = GetSpellLink(slot, BOOK)
    return link and tonumber(string.match(link, "spell:(%d+)")) or nil
end

local function ScanSpellbook()
    spellbookIds = {}
    spellbookNames = {}
    local tab, slot
    for tab = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local name = GetSpellName(slot, BOOK)
            local spellId = SpellIdFromBook(slot)
            if name and spellId then
                spellbookIds[name] = spellId
                spellbookNames[Lower(name)] = spellId
            end
        end
    end
end

TooltipReferencesLearnedSpell = function(tooltip)
    tooltip = Lower(tooltip)
    if tooltip == "" then return false end
    local learnedName
    for learnedName in pairs(spellbookNames) do
        if string.len(learnedName) >= 4 and string.find(tooltip, learnedName, 1, true) then return true end
    end
    return false
end

ConfirmedForActiveProfile = function(lowerName)
    local profiles = confirmedProcProfiles[lowerName]
    return profiles and activeProfile and profiles[activeProfile.sourceKey] == true
end

local function IsActive(spellId)
    local _, value
    for _, value in ipairs(EA_TempBuffsTable or {}) do
        if value == spellId then return true end
    end
    return false
end

local function EnsureAlertFrame(spellId)
    local frameName = "EAFrame_" .. spellId
    if _G[frameName] then return _G[frameName] end
    if not EA_Main_Frame then return nil end

    local frame = CreateFrame("FRAME", frameName, EA_Main_Frame)
    if EA_Config.AllowESC == true then tinsert(UISpecialFrames, frameName) end
    frame:SetFrameStrata("DIALOG")

    frame.spellName = frame:CreateFontString(frameName .. "_Name", "OVERLAY")
    frame.spellName:SetFontObject(ChatFontNormal)
    frame.spellName:SetPoint("BOTTOM", 0, -15)

    frame.spellTimer = frame:CreateFontString(frameName .. "_Timer", "OVERLAY")
    frame.spellTimer:SetFontObject(ChatFontNormal)
    frame.spellTimer:SetPoint("TOP", 0, 20)

    frame.spellCounter = frame:CreateFontString(frameName .. "_Counter", "OVERLAY")
    frame.spellCounter:SetFontObject(ChatFontNormal)
    frame.spellCounter:SetPoint("RIGHT", 20, 0)

    frame:SetScript("OnEvent", EventAlert_OnEvent)
    return frame
end

local function ActiveAlertFrames()
    local source = EA_TempBuffsTable or {}
    local active = {}
    local seen = {}
    local _, rawSpellId

    for _, rawSpellId in ipairs(source) do
        local spellId = tonumber(rawSpellId) or rawSpellId
        local frame = _G["EAFrame_" .. tostring(spellId)]
        if frame and not seen[spellId] and not IsBuffDisabled(spellId) then
            seen[spellId] = true
            table.insert(active, spellId)
        elseif frame and IsBuffDisabled(spellId) then
            frame:Hide()
        end
    end

    -- EventAlert 4.3.6 can insert the same proc more than once. Keep the
    -- original table object because the genuine addon owns this state.
    for index = #source, 1, -1 do source[index] = nil end
    for index, spellId in ipairs(active) do source[index] = spellId end
    EA_TempBuffsTable = source
    return active
end

local function AlertSpellData(spellId)
    local spellName, icon
    if spellId == 48517 then
        spellName = GetSpellInfo(spellId)
        _, _, icon = GetSpellInfo(5176)
    elseif spellId == 48518 then
        spellName = GetSpellInfo(spellId)
        _, _, icon = GetSpellInfo(2912)
    else
        spellName, _, icon = GetSpellInfo(spellId)
    end
    return spellName, icon
end

local function SafePositionFrames()
    if not EA_Config or EA_Config.ShowFrame ~= true or not EA_Main_Frame or not EA_Position then return end

    EA_Main_Frame:ClearAllPoints()
    EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)

    local active = ActiveAlertFrames()
    local _, spellId

    -- This must be a separate first pass. When proc A disappears, 4.3.6 can
    -- reverse the order of A and B while B still points at A. Anchoring A to B
    -- before clearing B creates the "is dependent on this" SetPoint cycle.
    for _, spellId in ipairs(active) do
        local frame = _G["EAFrame_" .. tostring(spellId)]
        if frame then frame:ClearAllPoints() end
    end

    local previous = EA_Main_Frame
    for _, spellId in ipairs(active) do
        local frame = _G["EAFrame_" .. tostring(spellId)]
        if frame then
            local spellName, icon = AlertSpellData(spellId)
            if previous == EA_Main_Frame then
                frame:SetPoint("CENTER", EA_Main_Frame, "CENTER", 0, 0)
            else
                frame:SetPoint("CENTER", previous, "CENTER", 100 + (EA_Position.xOffset or 0), EA_Position.yOffset or 0)
            end

            frame:SetWidth(EA_Config.IconSize or 60)
            frame:SetHeight(EA_Config.IconSize or 60)
            if icon then frame:SetBackdrop({ bgFile = icon }) end
            if frame.spellName then
                frame.spellName:SetText(EA_Config.ShowName == true and (spellName or tostring(spellId)) or "")
            end
            frame:SetScript("OnUpdate", EventAlert_OnUpdate)
            frame:Show()
            previous = frame
        end
    end
end

local function InstallSafePositioner()
    if safePositionerInstalled or type(EventAlert_PositionFrames) ~= "function" then return end
    EventAlert_PositionFrames = SafePositionFrames
    safePositionerInstalled = true
end

local function RegisterAuraProc(spellId, spellName)
    if not spellId or not EnsureConfiguration() then return false end
    spellId = tonumber(spellId) or spellId
    EA_Config.CoA.KnownBuffs[spellId] = spellName or GetSpellInfo(spellId) or tostring(spellId)
    EA_Config.CoA.ManagedSpellIds[spellId] = true
    if EA_Config.CoA.ManualBuffs[spellId] == false then return false end
    EA_Config.CoA.DisabledBuffs[spellId] = nil
    EA_Config.CoA.DisabledBuffs[tostring(spellId)] = nil
    EA_Config.CoA.Candidates[spellId] = nil
    local learned = EA_CustomItems[spellId] == nil
    EA_CustomItems[spellId] = true
    EnsureAlertFrame(spellId)
    if learned then
        Chat("proc appris : " .. tostring(spellName or GetSpellInfo(spellId) or spellId) .. " [" .. spellId .. "]")
    end
    return learned
end

local function AutoIgnoreAura(spellId, spellName, reason)
    if not spellId or not EnsureConfiguration() then return end
    spellId = tonumber(spellId) or spellId
    local name = spellName or GetSpellInfo(spellId) or tostring(spellId)
    local previousReason = EA_Config.CoA.FilterReasons[spellId]
    EA_Config.CoA.KnownBuffs[spellId] = name
    EA_Config.CoA.ManagedSpellIds[spellId] = true
    EA_Config.CoA.Candidates[spellId] = nil
    EA_Config.CoA.ManagedSpellIds[spellId] = true
    EA_Config.CoA.FilterReasons[spellId] = reason or "non pertinent"
    EA_Config.CoA.DisabledBuffs[spellId] = true
    EA_CustomItems[spellId] = nil
    EA_CustomItems[tostring(spellId)] = nil
    if RemoveActiveBuff then RemoveActiveBuff(spellId) end
    if previousReason ~= EA_Config.CoA.FilterReasons[spellId] then
        Chat("ignore automatiquement : " .. tostring(name) .. " [" .. tostring(spellId) .. "] - "
            .. tostring(EA_Config.CoA.FilterReasons[spellId]))
    end
end

local function RecordCandidate(spellId, spellName, reason)
    if not spellId or not EnsureConfiguration() then return end
    spellId = tonumber(spellId) or spellId
    local candidate = EA_Config.CoA.Candidates[spellId] or { observations = 0 }
    local now = Now()
    if not candidate.lastObservedAt or now - candidate.lastObservedAt > 0.5 then
        candidate.observations = (tonumber(candidate.observations) or 0) + 1
    end
    candidate.lastObservedAt = now
    candidate.name = spellName or GetSpellInfo(spellId) or tostring(spellId)
    candidate.reason = reason or "candidat non confirme"
    candidate.profileKey = activeProfileKey
    EA_Config.CoA.Candidates[spellId] = candidate
    EA_Config.CoA.KnownBuffs[spellId] = candidate.name
    EA_Config.CoA.FilterReasons[spellId] = candidate.reason .. " (" .. tostring(candidate.observations) .. " observation(s))"
    EA_Config.CoA.DisabledBuffs[spellId] = true
    EA_Config.CoA.ManagedSpellIds[spellId] = true
    EA_CustomItems[spellId] = nil
    EA_CustomItems[tostring(spellId)] = nil
end

local function EvaluateObservedAura(spellId, spellName, directlyCast, observedAura)
    if not spellId or not EnsureConfiguration() then return false end
    spellId = tonumber(spellId) or spellId
    if directlyCast and EA_Config.CoA.ManualBuffs[spellId] ~= true then
        AutoIgnoreAura(spellId, spellName, "sort lance manuellement")
        return false
    end
    local useful, reason = IsLikelyUsefulProc(spellId, spellName, observedAura)
    if useful == true then
        RegisterAuraProc(spellId, spellName)
        EA_Config.CoA.FilterReasons[spellId] = reason
        return true
    elseif useful == false then
        AutoIgnoreAura(spellId, spellName, reason)
        return false
    end
    RecordCandidate(spellId, spellName, reason)
    return false
end

local function ApplyStaticFilterToKnownBuffs()
    if not EnsureConfiguration() then return end
    local spellId, name
    for spellId, name in pairs(EA_Config.CoA.KnownBuffs) do
        spellId = tonumber(spellId) or spellId
        if EA_Config.CoA.ManualBuffs[spellId] == nil then
            local lowerName = string.lower(tostring(name or GetSpellInfo(spellId) or ""))
            if ignoredExactNames[lowerName] then
                AutoIgnoreAura(spellId, name, "ressource passive")
            elseif ContainsFragment(lowerName, ignoredNameFragments) then
                AutoIgnoreAura(spellId, name, "buff systeme persistant")
            else
                local activeAura = FindPlayerAura(spellId, name)
                if activeAura then
                    local useful, reason = IsLikelyUsefulProc(spellId, name, activeAura)
                    if useful == false then
                        AutoIgnoreAura(spellId, name, reason)
                    elseif useful == nil then
                        RecordCandidate(spellId, name, reason)
                    end
                end
            end
        end
    end
end

local function RegisterActiveSpell(spellId, spellName)
    if not spellId or not EnsureConfiguration() then return false end
    spellId = tonumber(spellId) or spellId
    local learned = EA_AltItems[spellId] == nil
    EA_AltItems[spellId] = true
    EA_Config.CoA.Reactions[spellId] = spellName or GetSpellInfo(spellId) or tostring(spellId)
    EA_Config.CoA.ManagedAltIds[spellId] = true
    if spellName then EA_PreLoadAlts[spellName] = tostring(spellId) end
    EnsureAlertFrame(spellId)
    if learned then
        Chat("reaction apprise : " .. tostring(spellName or GetSpellInfo(spellId) or spellId) .. " [" .. spellId .. "]")
    end
    return learned
end

local function Activate(spellId)
    if not spellId or IsBuffDisabled(spellId) or IsActive(spellId) then return end
    if not EnsureAlertFrame(spellId) then return end
    table.insert(EA_TempBuffsTable, spellId)
    EventAlert_PositionFrames()
    EventAlert_DoAlert()
end

ScanActiveAuras = function()
    if not EnsureConfiguration() then return end
    local forceProfileRefresh = activeAuraProfileKey ~= activeProfileKey
    local currentAuraIds = {}
    local index
    for index = 1, 40 do
        local spellName, _, _, count, _, duration, expirationTime, caster, _, _, rawSpellId = UnitBuff("player", index)
        if not spellName then break end
        local spellId = tonumber(rawSpellId)
        if spellId then
            currentAuraIds[spellId] = true
            -- UNIT_AURA fires for stack/refresh changes too. Reclassifying every
            -- unchanged buff made the previous implementation O(n²), including
            -- repeated GameTooltip construction in combat.
            if forceProfileRefresh or not activeAuraIds[spellId] or pendingAuras[spellId] then
                local manual = EA_Config.CoA.ManualBuffs[spellId]
                if manual == true or EA_Config.CoA.AutoLearn or IsTracked(spellId) then
                    local directlyCast = WasDirectlyCast(spellId, spellName)
                    local observedAura = {
                        index = index,
                        name = spellName,
                        count = tonumber(count) or 0,
                        duration = tonumber(duration) or 0,
                        expirationTime = tonumber(expirationTime) or 0,
                        caster = caster,
                        tooltip = nil
                    }
                    if EvaluateObservedAura(spellId, spellName, directlyCast, observedAura) then Activate(spellId) end
                end
            end
            pendingAuras[spellId] = nil
        end
    end
    activeAuraIds = currentAuraIds
    activeAuraProfileKey = activeProfileKey
end

local function QueueAuraEvaluation(spellId, spellName)
    spellId = tonumber(spellId)
    if not spellId then return end
    pendingAuras[spellId] = {
        name = spellName,
        queuedAt = Now(),
        attempts = 0
    }
end

local function ProcessPendingAuras()
    local spellId, pending
    for spellId, pending in pairs(pendingAuras) do
        if Now() - (pending.queuedAt or 0) >= 0.08 then
            pending.attempts = (pending.attempts or 0) + 1
            local aura = FindPlayerAura(spellId, pending.name)
            if aura then
                if EvaluateObservedAura(spellId, pending.name, WasDirectlyCast(spellId, pending.name)) then Activate(spellId) end
                pendingAuras[spellId] = nil
            elseif pending.attempts >= 8 or Now() - (pending.queuedAt or 0) > 1.5 then
                pendingAuras[spellId] = nil
            end
        end
    end
end

WasDirectlyCast = function(spellId, spellName)
    local castAt = recentCasts[spellId] or (spellName and recentCasts[spellName])
    return castAt and Now() - castAt < 2.5
end

IsTracked = function(spellId)
    if IsBuffDisabled(spellId) then return false end
    return EA_Items[spellId] or EA_CustomItems[spellId]
end

local function IsOwnedSource(sourceGUID, sourceFlags)
    if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then return true end
    if sourceFlags and bit and bit.band and COMBATLOG_OBJECT_AFFILIATION_MINE then
        return bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
    end
    -- Several CoA triggered auras omit the source GUID on the 3.3.5 combat log.
    return sourceGUID == nil and UnitAffectingCombat and UnitAffectingCombat("player")
end

local function HandleCombatLog(...)
    if not EnsureConfiguration() then return end
    local subEvent = select(2, ...)
    local sourceGUID = select(3, ...)
    local sourceFlags = select(5, ...)
    local destGUID = select(6, ...)
    -- select() returns every argument from this position onward. Passing it
    -- directly to tonumber() accidentally supplied spellName as the numeric
    -- base on Ascension (for example 91810, "Keeper's Scroll...", 1, "BUFF").
    local rawSpellId = select(9, ...)
    local spellId = tonumber(rawSpellId)
    local spellName = select(10, ...)
    local playerGUID = UnitGUID("player")

    if subEvent == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID then
        local castAt = Now()
        if spellId then recentCasts[spellId] = castAt end
        if spellName then recentCasts[spellName] = castAt end
        return
    end

    local applied = subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_APPLIED_DOSE"
    local refreshed = subEvent == "SPELL_AURA_REFRESH"
    if (applied or refreshed) and destGUID == playerGUID and spellId then
        local owned = IsOwnedSource(sourceGUID, sourceFlags)
        local directlyCast = WasDirectlyCast(spellId, spellName)
        local manual = EA_Config.CoA.ManualBuffs[spellId]
        if manual == true or (EA_Config.CoA.AutoLearn and (owned or IsTracked(spellId))) then
            local observedAura = FindPlayerAura(spellId, spellName)
            if observedAura then
                if EvaluateObservedAura(spellId, spellName, directlyCast, observedAura) then Activate(spellId) end
            else
                -- Combat log delivery can precede UNIT_AURA on Ascension. Wait
                -- for the real aura and tooltip instead of disabling it forever.
                QueueAuraEvaluation(spellId, spellName)
            end
        end
    end
end

local function HandleSpellActive(spellName)
    if not spellName or not EnsureConfiguration() then return end
    local spellId = spellbookIds[spellName]
    if not spellId then ScanSpellbook(); spellId = spellbookIds[spellName] end
    if spellId then
        RegisterActiveSpell(spellId, spellName)
        Activate(spellId)
    end
end

local function CountEntries(values)
    local count = 0
    for _, enabled in pairs(values or {}) do if enabled then count = count + 1 end end
    return count
end

RemoveActiveBuff = function(spellId)
    spellId = tonumber(spellId) or spellId
    local active = EA_TempBuffsTable or {}
    local index
    for index = #active, 1, -1 do
        if (tonumber(active[index]) or active[index]) == spellId then table.remove(active, index) end
    end
    local frame = _G["EAFrame_" .. tostring(spellId)]
    if frame then
        frame:ClearAllPoints()
        frame:Hide()
    end
    if type(EventAlert_PositionFrames) == "function" then EventAlert_PositionFrames() end
end

local function LearnedBuffEntries()
    local entries = {}
    if not EnsureConfiguration() then return entries end
    local rawSpellId, storedName
    for rawSpellId, storedName in pairs(EA_Config.CoA.KnownBuffs) do
        local spellId = tonumber(rawSpellId) or rawSpellId
        local name = GetSpellInfo(spellId) or storedName or tostring(spellId)
        table.insert(entries, { id = spellId, name = tostring(name) })
    end
    table.sort(entries, function(left, right)
        local leftName = string.lower(left.name)
        local rightName = string.lower(right.name)
        if leftName == rightName then return tostring(left.id) < tostring(right.id) end
        return leftName < rightName
    end)
    return entries
end

local RefreshBuffManager

local function SetLearnedBuffEnabled(spellId, enabled)
    if not EnsureConfiguration() then return end
    spellId = tonumber(spellId) or spellId
    local name = GetSpellInfo(spellId) or EA_Config.CoA.KnownBuffs[spellId] or tostring(spellId)
    EA_Config.CoA.KnownBuffs[spellId] = name
    EA_Config.CoA.DisabledBuffs[tostring(spellId)] = nil
    EA_Config.CoA.ManualBuffs[tostring(spellId)] = nil
    EA_Config.CoA.ManualBuffs[spellId] = enabled and true or false
    if enabled then
        EA_Config.CoA.DisabledBuffs[spellId] = nil
        EA_Config.CoA.FilterReasons[spellId] = "selection manuelle"
        EA_CustomItems[spellId] = true
        EnsureAlertFrame(spellId)
        local index
        for index = 1, 40 do
            local activeName = UnitBuff("player", index)
            if not activeName then break end
            if activeName == name then Activate(spellId); break end
        end
    else
        EA_Config.CoA.DisabledBuffs[spellId] = true
        EA_Config.CoA.FilterReasons[spellId] = "desactive manuellement"
        EA_CustomItems[spellId] = nil
        EA_CustomItems[tostring(spellId)] = nil
        RemoveActiveBuff(spellId)
    end
    Chat(tostring(name) .. " [" .. tostring(spellId) .. "] " .. (enabled and "active" or "ignore"))
    if RefreshBuffManager then RefreshBuffManager() end
end

RefreshBuffManager = function()
    if not buffManagerFrame or not buffManagerFrame:IsVisible() then return end
    local entries = LearnedBuffEntries()
    local pageCount = math.max(1, math.ceil(#entries / BUFFS_PER_PAGE))
    if buffManagerPage > pageCount then buffManagerPage = pageCount end
    if buffManagerPage < 1 then buffManagerPage = 1 end

    local enabledCount = 0
    local _, entry
    for _, entry in ipairs(entries) do
        if EA_CustomItems[entry.id] and not IsBuffDisabled(entry.id) then enabledCount = enabledCount + 1 end
    end
    buffManagerFrame.summary:SetText(tostring(enabledCount) .. " actif(s) / " .. tostring(#entries)
        .. " memorise(s) / " .. tostring(CountEntries(EA_Config.CoA.Candidates)) .. " candidat(s)")
    buffManagerFrame.pageText:SetText("Page " .. tostring(buffManagerPage) .. " / " .. tostring(pageCount))
    buffManagerFrame.autoLearn:SetChecked(EA_Config.CoA.AutoLearn == true)

    local rowIndex
    for rowIndex = 1, BUFFS_PER_PAGE do
        local row = buffManagerRows[rowIndex]
        entry = entries[(buffManagerPage - 1) * BUFFS_PER_PAGE + rowIndex]
        if entry then
            row.spellId = entry.id
            local enabled = EA_CustomItems[entry.id] == true and not IsBuffDisabled(entry.id)
            local reason = EA_Config.CoA.FilterReasons[entry.id]
            row.check:SetChecked(enabled)
            row.text:SetText(entry.name .. "  |cff888888[" .. tostring(entry.id) .. "]|r"
                .. (not enabled and reason and "  |cffff7777" .. tostring(reason) .. "|r" or ""))
            row:Show()
        else
            row.spellId = nil
            row:Hide()
        end
    end
    if buffManagerPage > 1 then buffManagerFrame.previous:Enable() else buffManagerFrame.previous:Disable() end
    if buffManagerPage < pageCount then buffManagerFrame.next:Enable() else buffManagerFrame.next:Disable() end
end

local function CreateBuffManager()
    if buffManagerFrame then return buffManagerFrame end
    local frame = CreateFrame("Frame", "EventAlertCoABuffManagerFrame", UIParent)
    frame:SetWidth(520)
    frame:SetHeight(410)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnShow", function() buffManagerPage = 1; RefreshBuffManager() end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("EventAlert CoA - Procs du profil actif")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    frame.autoLearn = CreateFrame("CheckButton", "EventAlertCoAAutoLearnCheck", frame, "UICheckButtonTemplate")
    frame.autoLearn:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -51)
    frame.autoLearn:SetScript("OnClick", function(self)
        EA_Config.CoA.AutoLearn = self:GetChecked() and true or false
        Chat("apprentissage automatique " .. (EA_Config.CoA.AutoLearn and "active" or "desactive"))
    end)
    local autoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoText:SetPoint("LEFT", frame.autoLearn, "RIGHT", 2, 1)
    autoText:SetText("Apprendre automatiquement les nouveaux procs")

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -58)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -83)
    help:SetText("Classe, specialisation, grimoire et tooltip sont verifies. Coche pour forcer un candidat.")

    local rowIndex
    for rowIndex = 1, BUFFS_PER_PAGE do
        local row = CreateFrame("Frame", nil, frame)
        row:SetWidth(470)
        row:SetHeight(25)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -105 - ((rowIndex - 1) * 25))
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.check:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if parent.spellId then SetLearnedBuffEnabled(parent.spellId, self:GetChecked() and true or false) end
        end)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.check, "RIGHT", 3, 1)
        row.text:SetWidth(425)
        row.text:SetJustifyH("LEFT")
        buffManagerRows[rowIndex] = row
    end

    frame.previous = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.previous:SetWidth(90)
    frame.previous:SetHeight(22)
    frame.previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 21)
    frame.previous:SetText("Precedent")
    frame.previous:SetScript("OnClick", function() buffManagerPage = buffManagerPage - 1; RefreshBuffManager() end)

    frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.next:SetWidth(90)
    frame.next:SetHeight(22)
    frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 21)
    frame.next:SetText("Suivant")
    frame.next:SetScript("OnClick", function() buffManagerPage = buffManagerPage + 1; RefreshBuffManager() end)

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 27)
    buffManagerFrame = frame
    return frame
end

local function ToggleBuffManager()
    if not EnsureConfiguration() then return end
    local frame = CreateBuffManager()
    if frame:IsVisible() then frame:Hide() else frame:Show() end
end

local function CoAStatus()
    if not EnsureConfiguration() then
        Chat("EventAlert 4.3.6 n'est pas charge")
        return
    end
    local profile = BindActiveProfile()
    Chat("compatibilite " .. COA_COMPAT_VERSION .. " chargee ; profil "
        .. tostring(profile.className) .. " - " .. tostring(profile.specName)
        .. (profile.catalogConfirmed and " (catalogue confirme)" or " (profil client)")
        .. " ; " .. CountEntries(EA_CustomItems) .. " proc(s) personnalise(s) ; "
        .. CountEntries(EA_AltItems) .. " reaction(s) ; apprentissage "
        .. (EA_Config.CoA.AutoLearn and "ON" or "OFF")
        .. " ; /ea coa buffs pour gerer la liste")
end

local originalSlashHandler = EventAlert_SlashHandler
local function CoASlashHandler(message)
    local normalized = string.lower(tostring(message or ""))
    if normalized == "coa" or normalized == "coa status" then
        CoAStatus()
    elseif normalized == "coa learn" then
        if EnsureConfiguration() then
            EA_Config.CoA.AutoLearn = not EA_Config.CoA.AutoLearn
            Chat("apprentissage automatique " .. (EA_Config.CoA.AutoLearn and "active" or "desactive"))
        end
    elseif normalized == "coa scan" then
        ScanSpellbook()
        ScanActiveAuras()
        CoAStatus()
    elseif normalized == "coa buffs" then
        ToggleBuffManager()
    else
        originalSlashHandler(message)
    end
end

local function Initialize()
    if not EnsureConfiguration(true) then return false end
    InstallSafePositioner()
    ScanSpellbook()
    ApplyStaticFilterToKnownBuffs()
    ScanActiveAuras()
    EventAlert_SlashHandler = CoASlashHandler
    SlashCmdList["EVENTALERT"] = CoASlashHandler
    if not initialized then
        initialized = true
        Chat("compatibilite CoA " .. COA_COMPAT_VERSION .. " chargee avec EventAlert 4.3.6")
    end
    return true
end

local eventFrame = CreateFrame("Frame", "EventAlertCoAEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("COMBAT_TEXT_UPDATE")
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    if not next(pendingAuras) then
        pendingElapsed = 0
        return
    end
    pendingElapsed = pendingElapsed + elapsed
    if pendingElapsed < 0.08 then return end
    pendingElapsed = 0
    ProcessPendingAuras()
end)
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = select(1, ...)
        if addonName == "EventAlert" or addonName == "EventAlertCoA" then Initialize() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE"
        or event == "ACTIVE_TALENT_GROUP_CHANGED"
    then
        Initialize()
    elseif event == "UNIT_AURA" and select(1, ...) == "player" then
        ScanActiveAuras()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLog(...)
    elseif event == "COMBAT_TEXT_UPDATE" and select(1, ...) == "SPELL_ACTIVE" then
        HandleSpellActive(select(2, ...))
    end
end)

Initialize()
