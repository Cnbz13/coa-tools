local addonName = ...

local STATUS = "debuff_coa_dispellable"
local BOOK = BOOKTYPE_SPELL or "spell"
local PET_BOOK = BOOKTYPE_PET or "pet"
local SCAN_INTERVAL = 0.50
local CAPABILITY_RESCAN_INTERVAL = 30

local initialized = false
local elapsedSinceScan = 0
local elapsedSinceCapabilityScan = 0
local GridStatus
local GridStatusAuras
local GridFrame
local GridRoster
local playerGUID
local petGUID

local dispelTypes = {}
local dispelSpells = {}
local dispelSpellsByName = {}
local activeAuraTypes = {}
local dangerousControlCache = {}

local colors = {
    Magic = { r = 0.20, g = 0.60, b = 1.00, a = 1 },
    Curse = { r = 0.60, g = 0.00, b = 1.00, a = 1 },
    Disease = { r = 0.60, g = 0.40, b = 0.00, a = 1 },
    Poison = { r = 0.00, g = 0.60, b = 0.00, a = 1 },
    Learned = { r = 1.00, g = 0.35, b = 0.10, a = 1 },
    Control = { r = 1.00, g = 0.15, b = 0.45, a = 1 }
}

local controlWords = {
    "sleep", "asleep", "slumber", "stun", "fear", "charm", "control",
    "polymorph", "hex", "banish", "sap", "silence", "root", "freeze",
    "frozen", "pacify", "endormi", "sommeil", "peur", "charme", "controle",
    "flee", "terror", "horror", "scream", "nightmare", "hibernate",
    "terreur", "effroi", "hypnose", "hypnotise"
}

-- These IDs only provide localized names and a reliable fallback. Custom CoA
-- dispels are discovered from their spellbook tooltips below.
local classicDispelDefinitions = {
    { id = 4987, types = { "Magic", "Poison", "Disease" } }, -- Cleanse
    { id = 1152, types = { "Poison", "Disease" } }, -- Purify
    { id = 527, types = { "Magic" } }, -- Dispel Magic
    { id = 528, types = { "Disease" } }, -- Cure Disease
    { id = 552, types = { "Disease" } }, -- Abolish Disease
    { id = 32375, types = { "Magic" } }, -- Mass Dispel
    { id = 2782, types = { "Curse" } }, -- Remove Curse
    { id = 2893, types = { "Poison" } }, -- Abolish Poison
    { id = 8946, types = { "Poison" } }, -- Cure Poison
    { id = 526, types = { "Poison" } }, -- Cure Poison
    { id = 2870, types = { "Disease" } }, -- Cure Disease
    { id = 51886, types = { "Curse", "Poison", "Disease" } }, -- Cleanse Spirit
    { id = 475, types = { "Curse" } }, -- Remove Lesser Curse
    { id = 19505, types = { "Magic" }, pet = true }, -- Devour Magic
    { id = 20594, types = { "Poison", "Disease" }, selfOnly = true } -- Stoneform
}

local tooltip = CreateFrame("GameTooltip", "GridCoASpellScannerTooltip", UIParent, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c0ffGrid CoA:|r " .. tostring(message))
    end
end

local function EnsureDatabase()
    if type(GridCoADB) ~= "table" then GridCoADB = {} end
    if type(GridCoADB.knownDispellable) ~= "table" then GridCoADB.knownDispellable = {} end
    if type(GridCoADB.learnedDispelSpells) ~= "table" then GridCoADB.learnedDispelSpells = {} end
end

local function MergeTypes(target, source)
    local _, debuffType
    for _, debuffType in ipairs(source or {}) do target[debuffType] = true end
end

local function TypesAsArray(types)
    local result = {}
    local _, debuffType
    for _, debuffType in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
        if types[debuffType] then table.insert(result, debuffType) end
    end
    return result
end

local function ContainsAny(text, words)
    local _, word
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function TooltipText(index, book)
    tooltip:ClearLines()
    local ok = pcall(tooltip.SetSpell, tooltip, index, book)
    if not ok then tooltip:Hide() return "" end
    local lines = {}
    local line
    for line = 1, tooltip:NumLines() do
        local left = getglobal("GridCoASpellScannerTooltipTextLeft" .. line)
        local right = getglobal("GridCoASpellScannerTooltipTextRight" .. line)
        if left and left:GetText() then table.insert(lines, left:GetText()) end
        if right and right:GetText() then table.insert(lines, right:GetText()) end
    end
    tooltip:Hide()
    return Lower(table.concat(lines, " "))
end

local function AuraTooltipText(unit, index)
    if type(tooltip.SetUnitDebuff) ~= "function" then return "" end
    tooltip:ClearLines()
    local ok = pcall(tooltip.SetUnitDebuff, tooltip, unit, index)
    if not ok then tooltip:Hide() return "" end
    local lines = {}
    local line
    for line = 1, tooltip:NumLines() do
        local left = getglobal("GridCoASpellScannerTooltipTextLeft" .. line)
        local right = getglobal("GridCoASpellScannerTooltipTextRight" .. line)
        if left and left:GetText() then table.insert(lines, left:GetText()) end
        if right and right:GetText() then table.insert(lines, right:GetText()) end
    end
    tooltip:Hide()
    return Lower(table.concat(lines, " "))
end

local function ParseDispelTypes(text)
    local result = {}
    if text == "" then return result, false end

    local hasAction = ContainsAny(text, {
        "dispel", "remove", "cleanse", "cure", "purif", "dissip", "supprim",
        "annule", "retire"
    })
    if not hasAction then return result, false end

    local selfOnly = ContainsAny(text, {
        "only yourself", "from yourself only", "affects only you", "sur vous-meme uniquement",
        "sur vous-même uniquement", "uniquement sur le lanceur"
    })
    local enemyOnly = ContainsAny(text, { "enemy", "ennemi" })
    local friendly = ContainsAny(text, {
        "friendly", "ally", "party", "raid", "group member", "amical", "allie",
        "allié", "groupe", "membre"
    })
    if enemyOnly and not friendly and not selfOnly then return result, false end

    if ContainsAny(text, { "magic", "magique", "magie" }) then result.Magic = true end
    if ContainsAny(text, { "curse", "malediction", "malédiction" }) then result.Curse = true end
    if ContainsAny(text, { "disease", "maladie" }) then result.Disease = true end
    if ContainsAny(text, { "poison", "venin" }) then result.Poison = true end

    return result, selfOnly
end

local function SpellIdAt(index, book)
    if not GetSpellLink then return nil end
    local link = GetSpellLink(index, book)
    if not link then return nil end
    return tonumber(string.match(link, "spell:(%d+)"))
end

local function BuildClassicNameMap()
    local byName = {}
    local _, definition
    for _, definition in ipairs(classicDispelDefinitions) do
        local name = GetSpellInfo and GetSpellInfo(definition.id)
        if name then
            local key = Lower(name)
            if not byName[key] then byName[key] = { types = {}, selfOnly = true, pet = definition.pet } end
            MergeTypes(byName[key].types, definition.types)
            if not definition.selfOnly then byName[key].selfOnly = false end
            if definition.pet then byName[key].pet = true end
        end
    end
    return byName
end

local function RegisterDispelSpell(name, index, book, types, selfOnly, generic)
    if not name or (not next(types) and not generic) then return end
    local entry = {
        name = name,
        index = index,
        book = book,
        types = types,
        selfOnly = selfOnly and true or false,
        generic = generic and true or false
    }
    table.insert(dispelSpells, entry)
    dispelSpellsByName[Lower(name)] = entry
    local debuffType
    for debuffType in pairs(types) do
        dispelTypes[debuffType] = true
    end
end

local function InspectSpell(index, book, classicByName)
    local name = GetSpellName and GetSpellName(index, book)
    if not name then return end
    if IsPassiveSpell and IsPassiveSpell(index, book) then return end

    local spellId = SpellIdAt(index, book)
    local classic
    local _, definition
    if spellId then
        for _, definition in ipairs(classicDispelDefinitions) do
            if definition.id == spellId then
                classic = { types = {}, selfOnly = definition.selfOnly and true or false }
                MergeTypes(classic.types, definition.types)
                break
            end
        end
    end
    classic = classic or classicByName[Lower(name)]

    local types = {}
    local selfOnly = false
    if classic then
        MergeTypes(types, TypesAsArray(classic.types))
        selfOnly = classic.selfOnly
    end

    local tooltipTypes, tooltipSelfOnly = ParseDispelTypes(TooltipText(index, book))
    MergeTypes(types, TypesAsArray(tooltipTypes))
    if tooltipSelfOnly then selfOnly = true end
    EnsureDatabase()
    local learned = GridCoADB.learnedDispelSpells[Lower(name)]
    if type(learned) == "table" and type(learned.types) == "table" then
        local learnedType
        for learnedType in pairs(learned.types) do types[learnedType] = true end
    end
    RegisterDispelSpell(name, index, book, types, selfOnly, learned and learned.any)
end

local function ScanSpellbook(silent)
    dispelTypes = {}
    dispelSpells = {}
    dispelSpellsByName = {}
    local classicByName = BuildClassicNameMap()

    if GetNumSpellTabs and GetSpellTabInfo and GetSpellName then
        local tab
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, number = GetSpellTabInfo(tab)
            local index
            for index = (offset or 0) + 1, (offset or 0) + (number or 0) do
                InspectSpell(index, BOOK, classicByName)
            end
        end
    end

    if HasPetSpells and GetSpellName then
        local count = HasPetSpells() or 0
        local index
        for index = 1, count do InspectSpell(index, PET_BOOK, classicByName) end
    end

    if not silent then
        local names = {}
        local _, spell
        for _, spell in ipairs(dispelSpells) do table.insert(names, spell.name) end
        if #names == 0 then
            Chat("aucun sort de dissipation allie detecte : aucune icone ne sera affichee")
        else
            Chat("dissipations detectees : " .. table.concat(names, ", "))
        end
    end
end

local function HasAnyDispel()
    return #dispelSpells > 0
end

local function CanDispelType(debuffType, unit)
    if not debuffType or not dispelTypes[debuffType] then return false end
    local _, spell
    for _, spell in ipairs(dispelSpells) do
        if spell.types[debuffType] and (unit == "player" or not spell.selfOnly) then return true end
    end
    return false
end

local function AuraKey(spellId, name)
    if spellId then return "spell:" .. tostring(spellId) end
    return "name:" .. Lower(name)
end

local function KnownAuraCanBeDispelled(key, unit)
    EnsureDatabase()
    local learned = GridCoADB.knownDispellable[key]
    if not learned or not HasAnyDispel() then return false end
    if type(learned) ~= "table" or type(learned.types) ~= "table" then return true end
    local debuffType
    for debuffType in pairs(learned.types) do
        if CanDispelType(debuffType, unit) then return true end
    end
    return learned.any and true or false
end

local function IsDangerousControl(unit, index, key, name)
    if dangerousControlCache[key] ~= nil then return dangerousControlCache[key] end
    local description = Lower(name)
    if not ContainsAny(description, controlWords) then
        description = description .. " " .. AuraTooltipText(unit, index)
    end
    local dangerous = ContainsAny(description, controlWords)
    dangerousControlCache[key] = dangerous and true or false
    return dangerous
end

local function AuraScore(name, count, expirationTime, dangerousControl)
    local score = 100 + (tonumber(count) or 0)
    local lowered = Lower(name)
    local _, word
    for _, word in ipairs(controlWords) do
        if string.find(lowered, word, 1, true) then score = score + 100 break end
    end
    if dangerousControl then score = score + 200 end
    if expirationTime and expirationTime > 0 then
        local remaining = expirationTime - GetTime()
        if remaining > 0 and remaining < 5 then score = score + 10 end
    end
    return score
end

local function ConfigureIndicators()
    if not GridFrame or not GridFrame.db or not GridFrame.db.profile then return end
    local statusmap = GridFrame.db.profile.statusmap
    statusmap.icon = statusmap.icon or {}
    statusmap.text = statusmap.text or {}
    statusmap.text2 = statusmap.text2 or {}
    local changed = false

    -- The center icon is intentionally exclusive: one actionable debuff only.
    local mappedStatus
    for mappedStatus, enabled in pairs(statusmap.icon) do
        if mappedStatus ~= STATUS and enabled then
            statusmap.icon[mappedStatus] = false
            changed = true
        end
    end
    if not statusmap.icon[STATUS] then statusmap.icon[STATUS] = true changed = true end
    if statusmap.text[STATUS] then statusmap.text[STATUS] = false changed = true end
    if statusmap.text2[STATUS] then statusmap.text2[STATUS] = false changed = true end

    local typedStatuses = { "debuff_magic", "debuff_curse", "debuff_disease", "debuff_poison" }
    local _, status
    for _, status in ipairs(typedStatuses) do
        if statusmap.icon[status] then statusmap.icon[status] = false changed = true end
        if statusmap.text[status] then statusmap.text[status] = false changed = true end
        if statusmap.text2[status] then statusmap.text2[status] = false changed = true end
        local settings = GridStatusAuras and GridStatusAuras.db and GridStatusAuras.db.profile[status]
        if settings and settings.enable then
            settings.enable = false
            changed = true
            if GridStatusAuras.OnStatusDisable then GridStatusAuras:OnStatusDisable(status) end
        end
    end
    if changed and GridFrame.UpdateAllFrames then GridFrame:UpdateAllFrames() end
end

local function ScanUnit(unit)
    if not initialized or not unit or not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or not GridRoster:IsGUIDInRaid(guid) then return end

    local selected
    local seen = {}
    local index
    for index = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime, caster,
            isStealable, shouldConsolidate, spellId = UnitAura(unit, index, "HARMFUL")
        if not name then break end
        local key = AuraKey(spellId, name)
        seen[key] = debuffType or false
        local dispellable = debuffType and CanDispelType(debuffType, unit)
        local learned = not debuffType and KnownAuraCanBeDispelled(key, unit)
        local dangerousControl = IsDangerousControl(unit, index, key, name)
        if dispellable or learned or dangerousControl then
            local score = AuraScore(name, count, expirationTime, dangerousControl)
            if not selected or score > selected.score then
                selected = {
                    name = name,
                    icon = icon,
                    count = count,
                    debuffType = debuffType,
                    duration = tonumber(duration) or 0,
                    expirationTime = tonumber(expirationTime) or 0,
                    control = dangerousControl,
                    score = score
                }
            end
        end
    end
    activeAuraTypes[guid] = seen

    if selected then
        local start = selected.duration > 0 and selected.expirationTime > 0
            and selected.expirationTime - selected.duration or nil
        local auraColor = selected.control and colors.Control
            or colors[selected.debuffType] or colors.Learned
        local label = selected.control and ("Controle: " .. selected.name)
            or (selected.debuffType and (selected.debuffType .. ": " .. selected.name) or selected.name)
        GridStatus:SendStatusGained(
            guid, STATUS, 99, nil, auraColor, label, selected.count, nil,
            selected.icon, start, selected.duration, selected.count
        )
    else
        GridStatus:SendStatusLost(guid, STATUS)
    end
end

local function ScanAll()
    if not initialized then return end
    ConfigureIndicators()
    local guid, unit
    for guid, unit in GridRoster:IterateRoster() do ScanUnit(unit) end
end

local function RememberSuccessfulDispel(destGUID, extraSpellId, extraSpellName, dispelSpellName)
    if not extraSpellId and not extraSpellName then return end
    EnsureDatabase()
    local key = AuraKey(extraSpellId, extraSpellName)
    local learnedTypes = {}
    local friendlyAuras = destGUID and activeAuraTypes[destGUID]
    if not friendlyAuras then return end
    local cached = friendlyAuras[key]
    if cached then learnedTypes[cached] = true end
    local dispelSpell = dispelSpellsByName[Lower(dispelSpellName)]
    if not next(learnedTypes) and dispelSpell then MergeTypes(learnedTypes, TypesAsArray(dispelSpell.types)) end
    if dispelSpellName then
        local spellKey = Lower(dispelSpellName)
        local learnedSpell = GridCoADB.learnedDispelSpells[spellKey]
        if type(learnedSpell) ~= "table" then learnedSpell = { types = {} } end
        if type(learnedSpell.types) ~= "table" then learnedSpell.types = {} end
        local learnedType
        for learnedType in pairs(learnedTypes) do learnedSpell.types[learnedType] = true end
        learnedSpell.any = not next(learnedSpell.types)
        learnedSpell.learnedAt = time()
        GridCoADB.learnedDispelSpells[spellKey] = learnedSpell
        if not dispelSpell then
            RegisterDispelSpell(dispelSpellName, nil, BOOK, learnedSpell.types, false, learnedSpell.any)
        end
    end
    GridCoADB.knownDispellable[key] = {
        name = extraSpellName,
        learnedAt = time(),
        types = learnedTypes,
        any = not next(learnedTypes)
    }
end

local function Initialize()
    if initialized or not Grid or not Grid.GetModule then return false end
    GridStatus = Grid:GetModule("GridStatus")
    GridFrame = Grid:GetModule("GridFrame")
    GridRoster = Grid:GetModule("GridRoster")
    GridStatusAuras = GridStatus and GridStatus:GetModule("GridStatusAuras")
    if not GridStatus or not GridFrame or not GridRoster or not GridStatusAuras
        or not GridStatusAuras.db or not GridFrame.db then return false end

    if not GridStatus:IsStatusRegistered(STATUS) then
        GridStatus:RegisterStatus(STATUS, "CoA: dissipation ou controle dangereux", addonName or "GridCoA")
    end
    EnsureDatabase()
    initialized = true
    playerGUID = UnitGUID("player")
    petGUID = UnitGUID("pet")
    ScanSpellbook(true)
    ConfigureIndicators()
    ScanAll()
    Chat("actif : le centre affiche les effets dissipables et les controles dangereux")
    return true
end

local frame = CreateFrame("Frame", "GridCoAEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PET_BAR_UPDATE")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = select(1, ...)
        if loaded == "Grid" or loaded == addonName then Initialize() end
        return
    end
    if not initialized and not Initialize() then return end

    if event == "UNIT_AURA" then
        ScanUnit(select(1, ...))
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB"
        or event == "PLAYER_TALENT_UPDATE" or event == "PET_BAR_UPDATE" then
        ScanSpellbook(true)
        ScanAll()
    elseif event == "UNIT_PET" then
        petGUID = UnitGUID("pet")
        ScanSpellbook(true)
        ScanAll()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID = ...
        if subevent == "SPELL_DISPEL" and (sourceGUID == playerGUID or sourceGUID == petGUID) then
            local spellId, spellName, spellSchool, extraSpellId, extraSpellName = select(9, ...)
            RememberSuccessfulDispel(destGUID, extraSpellId, extraSpellName, spellName)
            ScanAll()
        end
    else
        playerGUID = UnitGUID("player")
        petGUID = UnitGUID("pet")
        ScanAll()
    end
end)
frame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceScan = elapsedSinceScan + elapsed
    elapsedSinceCapabilityScan = elapsedSinceCapabilityScan + elapsed
    if elapsedSinceCapabilityScan >= CAPABILITY_RESCAN_INTERVAL then
        elapsedSinceCapabilityScan = 0
        if initialized then ScanSpellbook(true) end
    end
    if elapsedSinceScan < SCAN_INTERVAL then return end
    elapsedSinceScan = 0
    if not initialized then Initialize() else ScanAll() end
end)

SLASH_GRIDCOA1 = "/gridcoa"
SlashCmdList.GRIDCOA = function(message)
    local command = Lower(message):match("^%s*(%S*)") or ""
    if command == "scan" then
        ScanSpellbook(false)
        ScanAll()
    elseif command == "reset" then
        EnsureDatabase()
        GridCoADB.knownDispellable = {}
        GridCoADB.learnedDispelSpells = {}
        ScanSpellbook(true)
        ScanAll()
        Chat("apprentissage des effets dissipables reinitialise")
    else
        local types = TypesAsArray(dispelTypes)
        Chat(#dispelSpells .. " sort(s) de dissipation ; types : " .. (#types > 0 and table.concat(types, ", ") or "aucun"))
        Chat("/gridcoa scan : rescanner les sorts ; /gridcoa reset : oublier les effets appris")
    end
end

Initialize()
