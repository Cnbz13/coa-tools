-- CoA Essential Assistant
-- Assistant visuel universel de mecanismes importants. Aucune rotation,
-- aucun ciblage et aucun lancement automatique de sort.

local ADDON_NAME = "CoAEssentialAssistant"
local DATA = CoAEssentialData or { themes = {}, profiles = {}, aliases = {}, procSemantics = {}, noise = {} }
local VERSION = "1.21.1"
local floor = math.floor
local max = math.max
local min = math.min

local db
local settings
local character = { className = "Inconnue", classToken = "UNKNOWN", specName = "Avant specialisation", role = "DAMAGE", level = 0 }
local theme = { layout = "ROW", color = {0.02,0.06,0.10}, accent = {0.25,0.85,1.00}, resource = "Ressource", aliases = {} }
local profile
local spellbook = {}
local spellOrder = {}
local talents = {}
local talentCount = 0
local updateDirty = true
local coverageDirty = true
local elapsedUpdate = 0
local elapsedCoverage = 0
local elapsedClock = 0
local testUntil = 0
local activeSignalKeys = {}
local currentSignals = {}
local currentTargetSignal = nil
local currentResource = nil
local currentCoverage = nil
local latestUpdate = nil
local specialistDelegated = false
local hubManaged = false

local procFrame
local resourceFrame
local targetFrame
local coverageFrame
local panel
local minimapButton
local procCards = {}
local movers = {}
local moduleFrames = {}
local panelWidgets = {}
local resourceBar
local resourceText
local targetIcon
local targetCooldown
local targetText
local targetTimer
local targetGlow
local coverageIcon
local coverageText
local coverageTimer
local coverageDots = {}
local scanTooltip
local auraTooltipCache = {}
local auraTooltipCacheSize = 0
local fullScanAt = nil
local fullScanReason = nil

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function Trim(value)
    return string.gsub(string.gsub(tostring(value or ""), "^%s+", ""), "%s+$", "")
end

local function Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function SafeAtan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function Contains(text, fragment)
    return string.find(Lower(text), Lower(fragment), 1, true) ~= nil
end

local function ContainsAny(text, fragments)
    local _, fragment
    for _, fragment in ipairs(fragments or {}) do
        if Contains(text, fragment) then return true end
    end
    return false
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff42e8ffCoA Essentiel|r : " .. tostring(message)) end
end

local function CharacterKey()
    local name = UnitName and UnitName("player") or "Personnage"
    local realm = GetRealmName and GetRealmName() or "Royaume"
    return tostring(realm) .. "-" .. tostring(name)
end

local DEFAULT_MODULES = {
    procs = { enabled = true, scale = 1.00, alpha = 1.00 },
    resource = { enabled = true, scale = 1.00, alpha = 0.95 },
    target = { enabled = true, scale = 1.00, alpha = 0.95 },
    coverage = { enabled = true, scale = 1.00, alpha = 0.95 }
}

local DEFAULT_POSITIONS = {
    ROW = { procs={0,-92}, resource={0,-164}, target={0,-196}, coverage={0,-232} },
    TOTEM = { procs={-92,-100}, resource={0,-102}, target={92,-100}, coverage={0,-158} },
    ARC = { procs={0,-126}, resource={-112,-76}, target={112,-76}, coverage={0,-196} },
    COLUMN = { procs={150,-72}, resource={150,-148}, target={150,-182}, coverage={150,-224} },
    STORM = { procs={0,-118}, resource={-104,-58}, target={104,-58}, coverage={0,-190} },
    BANNER = { procs={0,-74}, resource={0,-146}, target={112,-110}, coverage={-112,-110} },
    RUNES = { procs={0,-110}, resource={0,-174}, target={108,-110}, coverage={-108,-110} },
    BLOOD = { procs={0,-134}, resource={-116,-92}, target={116,-92}, coverage={0,-204} },
    CLOCK = { procs={0,-100}, resource={-126,-100}, target={126,-100}, coverage={0,-168} },
    VOID = { procs={0,-122}, resource={-102,-66}, target={102,-66}, coverage={0,-194} },
    CELESTIAL = { procs={0,-78}, resource={-112,-145}, target={112,-145}, coverage={0,-184} },
    SUN = { procs={0,-80}, resource={-118,-128}, target={118,-128}, coverage={0,-188} },
    TECH = { procs={112,-100}, resource={0,-160}, target={-112,-100}, coverage={0,-206} },
    VENOM = { procs={-90,-105}, resource={0,-58}, target={90,-105}, coverage={0,-164} },
    SOUL = { procs={0,-118}, resource={0,-58}, target={0,-186}, coverage={104,-118} },
    GLYPH = { procs={0,-96}, resource={-118,-154}, target={118,-154}, coverage={0,-204} }
}

local function CopyDefaults(target, defaults)
    local key, value
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function EnsureDatabase()
    CoAEssentialAssistantDB = CoAEssentialAssistantDB or {}
    db = CoAEssentialAssistantDB
    if db.enabled == nil then db.enabled = true end
    if db.sound == nil then db.sound = true end
    if db.minimap == nil then db.minimap = true end
    if db.hideRotationHUD == nil then db.hideRotationHUD = true end
    if db.profileMode ~= "GLOBAL" and db.profileMode ~= "CHARACTER" then db.profileMode = "CHARACTER" end
    if type(db.global) ~= "table" then db.global = {} end
    if type(db.characters) ~= "table" then db.characters = {} end
    if type(db.panel) ~= "table" then db.panel = { point="CENTER", relativePoint="CENTER", x=0, y=40 } end
end

local function NewSettings()
    return {
        locked = true,
        ignored = {},
        seen = {},
        modules = {
            procs = { enabled=true, scale=1, alpha=1 },
            resource = { enabled=true, scale=1, alpha=0.95 },
            target = { enabled=true, scale=1, alpha=0.95 },
            coverage = { enabled=true, scale=1, alpha=0.95 }
        },
        positions = {}
    }
end

local function SelectSettings()
    EnsureDatabase()
    local container
    if db.profileMode == "GLOBAL" then
        container = db.global
    else
        local key = CharacterKey()
        if type(db.characters[key]) ~= "table" then db.characters[key] = {} end
        container = db.characters[key]
    end
    local classKey = character.className or "Inconnue"
    if type(container[classKey]) ~= "table" then container[classKey] = NewSettings() end
    settings = container[classKey]
    CopyDefaults(settings.modules, DEFAULT_MODULES)
    if type(settings.positions) ~= "table" then settings.positions = {} end
    if type(settings.ignored) ~= "table" then settings.ignored = {} end
    if type(settings.seen) ~= "table" then settings.seen = {} end
end

local function RoleFromSpecInfo(specInfo)
    if type(specInfo) ~= "table" then return nil end
    if specInfo.Healer then return "HEALER" end
    if specInfo.Tank then return "TANK" end
    if specInfo.Support then return "SUPPORT" end
    return "DAMAGE"
end

local function ResolveProfile(className, specName)
    local key = tostring(className or "") .. ":" .. tostring(specName or "")
    key = DATA.aliases[key] or key
    if DATA.profiles[key] then return DATA.profiles[key], key end
    local candidateKey, candidate
    for candidateKey, candidate in pairs(DATA.profiles or {}) do
        if Lower(candidate.className) == Lower(className) and Lower(candidate.specName) == Lower(specName) then
            return candidate, candidateKey
        end
    end
    return nil, key
end

local function ResolveCharacter()
    local className, classToken = UnitClass("player")
    className = className or classToken or "Inconnue"
    local resolved = {
        className = className,
        classToken = classToken or "UNKNOWN",
        specName = "Avant specialisation",
        role = "DAMAGE",
        level = UnitLevel("player") or 0,
        source = "talents 3.3.5"
    }
    if type(C_ClassInfo) == "table" and type(C_ClassInfo.GetAllSpecs) == "function"
        and type(C_ClassInfo.GetSpecInfo) == "function" and type(GetSpecialization) == "function" then
        local activeOK, activeIndex = pcall(GetSpecialization)
        activeIndex = activeOK and tonumber(activeIndex) or nil
        local activeID = activeIndex
        local activeName = nil
        if activeIndex and type(GetSpecializationInfo) == "function" then
            local infoOK, infoID, infoName = pcall(GetSpecializationInfo, activeIndex)
            if infoOK and tonumber(infoID) and tonumber(infoID) ~= 0 then activeID = tonumber(infoID) end
            if infoOK and type(infoName) == "string" and infoName ~= "" then activeName = infoName end
        end
        local catalogOK, catalog = pcall(C_ClassInfo.GetAllSpecs, classToken)
        if activeIndex and catalogOK and type(catalog) == "table" then
            local index, specKey
            for index, specKey in ipairs(catalog) do
                local specOK, specInfo = pcall(C_ClassInfo.GetSpecInfo, classToken, specKey)
                local catalogID = specOK and specInfo and tonumber(specInfo.ID) or nil
                local catalogName = specOK and specInfo and specInfo.Name or nil
                local matches = catalogID and (catalogID == activeID or catalogID == activeIndex)
                    or tonumber(specKey) and (tonumber(specKey) == activeID or tonumber(specKey) == activeIndex)
                    or activeName and catalogName and Lower(activeName) == Lower(catalogName)
                    or not activeName and activeID == activeIndex and index == activeIndex
                if specOK and specInfo and matches then
                    resolved.specName = catalogName or activeName or tostring(specKey)
                    resolved.role = RoleFromSpecInfo(specInfo) or resolved.role
                    resolved.source = "catalogue CoA actif"
                    return resolved
                end
            end
        end
    end
    local bestName, bestPoints = nil, -1
    if GetNumTalentTabs and GetTalentTabInfo then
        local tab
        for tab = 1, GetNumTalentTabs() do
            local name, _, points = GetTalentTabInfo(tab)
            points = tonumber(points) or 0
            if name and Lower(name) ~= "class" and points > bestPoints then
                bestName, bestPoints = name, points
            end
        end
    end
    if bestName and bestPoints > 0 then resolved.specName = bestName end
    local found = ResolveProfile(resolved.className, resolved.specName)
    if found then resolved.role = found.role end
    return resolved
end

local function EnsureTooltip()
    if scanTooltip then return end
    scanTooltip = CreateFrame("GameTooltip", "CoAEssentialScannerTooltip", UIParent, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function TooltipLines()
    local lines = {}
    local count = scanTooltip and scanTooltip.NumLines and scanTooltip:NumLines() or 0
    local index
    for index = 1, count do
        local left = _G["CoAEssentialScannerTooltipTextLeft" .. tostring(index)]
        local right = _G["CoAEssentialScannerTooltipTextRight" .. tostring(index)]
        if left and left:GetText() then table.insert(lines, left:GetText()) end
        if right and right:GetText() then table.insert(lines, right:GetText()) end
    end
    return Trim(table.concat(lines, " "))
end

local function SpellTooltip(index, book)
    EnsureTooltip()
    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetSpellBookItem, scanTooltip, index, book)
    local text = ok and TooltipLines() or ""
    scanTooltip:Hide()
    return text
end

local function AuraTooltip(unit, index, harmful, name, spellID)
    local cacheKey = (harmful and "D:" or "B:") .. tostring(tonumber(spellID) or Lower(name))
    if auraTooltipCache[cacheKey] ~= nil then return auraTooltipCache[cacheKey] end
    EnsureTooltip()
    scanTooltip:ClearLines()
    local ok
    if harmful and scanTooltip.SetUnitDebuff then ok = pcall(scanTooltip.SetUnitDebuff, scanTooltip, unit, index)
    elseif not harmful and scanTooltip.SetUnitBuff then ok = pcall(scanTooltip.SetUnitBuff, scanTooltip, unit, index) end
    local text = ok and TooltipLines() or ""
    scanTooltip:Hide()
    if auraTooltipCacheSize >= 256 then
        auraTooltipCache = {}
        auraTooltipCacheSize = 0
    end
    auraTooltipCache[cacheKey] = text
    auraTooltipCacheSize = auraTooltipCacheSize + 1
    return text
end

local function ScanSpellbook()
    spellbook = {}
    spellOrder = {}
    if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellName) then return end
    local book = BOOKTYPE_SPELL or "spell"
    local tabs = tonumber(GetNumSpellTabs()) or 0
    local tab
    for tab = 1, tabs do
        local _, _, offset, count = GetSpellTabInfo(tab)
        local index
        for index = (tonumber(offset) or 0) + 1, (tonumber(offset) or 0) + (tonumber(count) or 0) do
            local name, rank = GetSpellName(index, book)
            if name then
                local passive = IsPassiveSpell and IsPassiveSpell(index, book) or false
                local icon = GetSpellTexture and GetSpellTexture(index, book) or "Interface\\Icons\\INV_Misc_QuestionMark"
                local spell = { name=name, rank=rank or "", index=index, icon=icon, passive=passive, tooltip=SpellTooltip(index, book), id=nil }
                if GetSpellLink then
                    local ok, link = pcall(GetSpellLink, index, book)
                    if ok and type(link) == "string" then spell.id = tonumber(string.match(link, "spell:(%d+)")) end
                end
                local key = Lower(name)
                local previous = spellbook[key]
                if not previous then table.insert(spellOrder, spell) end
                if not previous or index >= (previous.index or 0) then spellbook[key] = spell end
            end
        end
    end
end

local function ScanTalents()
    talents = {}
    talentCount = 0
    if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return end
    local tab
    for tab = 1, GetNumTalentTabs() do
        local total = tonumber(GetNumTalents(tab)) or 0
        local index
        for index = 1, total do
            local ok, name, _, _, _, rank = pcall(GetTalentInfo, tab, index)
            rank = ok and tonumber(rank) or 0
            if name and rank and rank > 0 then
                talents[Lower(name)] = rank
                talentCount = talentCount + 1
            end
        end
    end
end

local function CombinedAliases()
    local result = {}
    local _, value
    for _, value in ipairs(theme.aliases or {}) do table.insert(result, value) end
    for _, value in ipairs(profile and profile.aliases or {}) do table.insert(result, value) end
    return result
end

local function IsNoise(name, tooltip, duration)
    local combined = Lower(name) .. " " .. Lower(tooltip)
    if ContainsAny(combined, DATA.noise) then return true end
    if tonumber(duration) and tonumber(duration) > 90 then return true end
    return false
end

local function ExplicitMechanic(name)
    local _, alias
    for _, alias in ipairs(CombinedAliases()) do
        if Contains(name, alias) or Contains(alias, name) then return true, alias end
    end
    local talentName
    for talentName in pairs(talents) do
        if Contains(name, talentName) or Contains(talentName, name) then return true, talentName end
    end
    return false, nil
end

local function AuraSignal(unit, index, harmful)
    local getter = harmful and UnitDebuff or UnitBuff
    if not getter then return nil, false end
    local name, rank, icon, count, auraType, duration, expiration, caster, stealable, consolidate, spellID = getter(unit, index)
    if not name then return nil, false end
    local tooltip = AuraTooltip(unit, index, harmful, name, spellID)
    local learned = spellbook[Lower(name)]
    if learned and learned.tooltip and learned.tooltip ~= "" then tooltip = tooltip .. " " .. learned.tooltip end
    local key = tostring(tonumber(spellID) or Lower(name))
    if settings and settings.ignored[key] then return nil, true end
    if IsNoise(name, tooltip, duration) then return nil, true end
    if caster and caster ~= "player" and caster ~= "pet" and not harmful then return nil, true end

    local explicit, alias = ExplicitMechanic(name)
    local semantic = ContainsAny(tooltip, DATA.procSemantics)
    local short = tonumber(duration) and tonumber(duration) > 0 and tonumber(duration) <= 45
    local stacked = tonumber(count) and tonumber(count) >= 2
    local score = 0
    if explicit then score = score + 90 end
    if semantic then score = score + 80 end
    if learned and not learned.passive then score = score + 18 end
    if short then score = score + 16 end
    if stacked then score = score + 22 end
    if harmful and caster == "player" and explicit then score = score + 25 end
    if harmful and not explicit and not semantic then return nil, true end
    if not explicit and not semantic then return nil, true end
    if not short and not stacked and not semantic then return nil, true end
    if not short and not stacked and not explicit then return nil, true end
    if score < 80 then return nil, true end

    local now = GetTime()
    local remaining = tonumber(expiration) and tonumber(expiration) > 0 and max(0, tonumber(expiration) - now) or nil
    local kind = harmful and "CIBLE" or "PROC"
    if stacked then kind = "CHARGES" end
    if ContainsAny(tooltip, {"instant", "prochain", "next", "sans cout", "no mana", "free of cost"}) then kind = "PRET" end
    return {
        key=key, name=name, rank=rank, icon=icon or learned and learned.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        count=tonumber(count) or 0, duration=tonumber(duration) or 0, expiration=tonumber(expiration) or 0,
        remaining=remaining, spellID=tonumber(spellID), score=score, explicit=explicit, alias=alias,
        semantic=semantic, harmful=harmful, kind=kind, tooltip=tooltip
    }, true
end

local function RememberSignal(signal)
    if not settings or not signal then return end
    local seen = settings.seen[signal.key]
    if type(seen) ~= "table" then seen = { name=signal.name, count=0 } settings.seen[signal.key] = seen end
    seen.name = signal.name
    seen.count = (tonumber(seen.count) or 0) + 1
    seen.lastSeen = time and time() or 0
    seen.kind = signal.kind
end

local function ScanSignals()
    currentSignals = {}
    currentTargetSignal = nil
    if specialistDelegated then return end
    local index
    for index = 1, 40 do
        local signal, exists = AuraSignal("player", index, false)
        if not exists then break end
        if signal then table.insert(currentSignals, signal) end
    end
    table.sort(currentSignals, function(left, right)
        if left.score ~= right.score then return left.score > right.score end
        return (left.remaining or 999) < (right.remaining or 999)
    end)
    while #currentSignals > 3 do table.remove(currentSignals) end
    local _, signal
    for _, signal in ipairs(currentSignals) do RememberSignal(signal) end

    if UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") then
        local candidates = {}
        for index = 1, 40 do
            local signal, exists = AuraSignal("target", index, true)
            if not exists then break end
            if signal then table.insert(candidates, signal) end
        end
        table.sort(candidates, function(left, right)
            if left.score ~= right.score then return left.score > right.score end
            return (left.remaining or 999) < (right.remaining or 999)
        end)
        currentTargetSignal = candidates[1]
        RememberSignal(currentTargetSignal)
    end
end

local function ReadResource()
    currentResource = nil
    if specialistDelegated then return end
    local current, maximum, source
    if theme.powerType ~= nil and UnitPower and UnitPowerMax then
        local okMax, valueMax = pcall(UnitPowerMax, "player", theme.powerType)
        if okMax and tonumber(valueMax) and tonumber(valueMax) > 0 then
            local okCurrent, valueCurrent = pcall(UnitPower, "player", theme.powerType)
            if okCurrent then current, maximum, source = tonumber(valueCurrent) or 0, tonumber(valueMax), "API" end
        end
    end
    if not maximum then
        local index
        for index = 1, 40 do
            local name, _, _, count = UnitBuff and UnitBuff("player", index)
            if not name then break end
            local explicit = ExplicitMechanic(name)
            if explicit and tonumber(count) and tonumber(count) > 0 then
                current, maximum, source = tonumber(count), max(5, tonumber(count)), "aura"
                break
            end
        end
    end
    if maximum and maximum > 0 then
        local percent = current / maximum
        local urgent = theme.powerType == 0 and percent <= 0.25 or theme.powerType ~= 0 and percent >= 0.80
        currentResource = { current=current, maximum=maximum, percent=percent, urgent=urgent, source=source, name=theme.resource or "Ressource" }
    end
end

local function GroupUnits()
    local units = {"player"}
    local raidCount = GetNumRaidMembers and tonumber(GetNumRaidMembers()) or 0
    local partyCount = GetNumPartyMembers and tonumber(GetNumPartyMembers()) or 0
    local index
    if raidCount > 0 then
        units = {}
        for index=1,raidCount do table.insert(units,"raid"..tostring(index)) end
    else
        for index=1,partyCount do table.insert(units,"party"..tostring(index)) end
    end
    return units
end

local function ScanCoverage()
    currentCoverage = nil
    if specialistDelegated or not profile or profile.role ~= "HEALER" and profile.role ~= "SUPPORT" then return end
    local units = GroupUnits()
    if #units <= 1 then return end
    local candidates = {}
    local unitIndex, unit
    for unitIndex,unit in ipairs(units) do
        if not UnitExists or UnitExists(unit) then
            local auraIndex
            for auraIndex=1,40 do
                local name, _, icon, count, _, duration, expiration, caster, _, _, spellID = UnitBuff(unit,auraIndex)
                if not name then break end
                local explicit, alias = ExplicitMechanic(name)
                if explicit and tonumber(duration) and tonumber(duration)>0 and tonumber(duration)<=60
                    and (caster==nil or caster=="player") and not IsNoise(name,"",duration) then
                    local key=tostring(tonumber(spellID) or Lower(name))
                    local entry=candidates[key]
                    if not entry then
                        entry={key=key,name=name,icon=icon,count=0,total=#units,minimum=nil,duration=tonumber(duration) or 0,expiration=tonumber(expiration) or 0,alias=alias,members={},other=false}
                        candidates[key]=entry
                    end
                    entry.count=entry.count+1;entry.members[unitIndex]=true
                    local isPlayerUnit=UnitIsUnit and UnitIsUnit(unit,"player") or unit=="player"
                    if not isPlayerUnit then entry.other=true end
                    local remaining=tonumber(expiration) and tonumber(expiration)>0 and max(0,tonumber(expiration)-GetTime()) or nil
                    if remaining and (not entry.minimum or remaining<entry.minimum) then entry.minimum=remaining end
                end
            end
        end
    end
    local _,entry
    for _,entry in pairs(candidates) do
        if entry.other and (not currentCoverage or entry.count>currentCoverage.count) then currentCoverage=entry end
    end
    if currentCoverage then
        local seen=settings.seen[currentCoverage.key] or {}
        seen.name=currentCoverage.name;seen.icon=currentCoverage.icon;seen.group=true;seen.lastSeen=time and time() or 0
        settings.seen[currentCoverage.key]=seen
        return
    end
    local key,seen
    for key,seen in pairs(settings.seen) do
        if seen.group and seen.name and not settings.ignored[key] then
            currentCoverage={key=key,name=seen.name,icon=seen.icon or theme.texture,count=0,total=#units,minimum=nil,members={},missing=true}
            return
        end
    end
end

local function RefreshUpdateNotice()
    latestUpdate = nil
    local feed = CoARotationUpdateFeed or CoAEssentialUpdateFeed
    if type(feed) ~= "table" or type(feed.items) ~= "table" then return end
    local className = Lower(character.className)
    local specName = Lower(character.specName)
    local index, item
    for index, item in ipairs(feed.items) do
        local searchable = Lower(item.title) .. " " .. Lower(item.officialNote) .. " " .. Lower(item.friendly)
        local relevant = Contains(searchable, className) or Contains(searchable, specName)
        local _, tag
        for _, tag in ipairs(item.tags or {}) do
            if Contains(tag, className) or Contains(tag, specName) or spellbook[Lower(tag)] then relevant = true break end
        end
        if relevant then latestUpdate = item break end
    end
    if latestUpdate and latestUpdate.significant and db.lastEssentialNotice ~= latestUpdate.id then
        db.lastEssentialNotice = latestUpdate.id
        Chat("mise a jour officielle a verifier pour " .. character.className .. " : " .. tostring(latestUpdate.title or "changement de mecanique"))
    end
end

local function PlaySignalSound(signal)
    if not db.sound or not signal or activeSignalKeys[signal.key] then return end
    if signal.score >= 120 and PlaySound then pcall(PlaySound, "RaidWarning") end
end

local function ModulePosition(name)
    local position = settings.positions[name]
    if position then return position end
    local layout = DEFAULT_POSITIONS[theme.layout] or DEFAULT_POSITIONS.ROW
    local fallback = layout[name] or {0,0}
    return { point="CENTER", relativePoint="CENTER", x=fallback[1], y=fallback[2] }
end

local function ApplyModulePosition(name)
    local frame = moduleFrames[name]
    if not frame then return end
    local position = ModulePosition(name)
    frame:ClearAllPoints()
    frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
    local config = settings.modules[name] or DEFAULT_MODULES[name]
    frame:SetScale(Clamp(config.scale, 0.55, 1.80))
    frame:SetAlpha(Clamp(config.alpha, 0.20, 1.00))
end

local function SaveModulePosition(name)
    local frame = moduleFrames[name]
    if not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    settings.positions[name] = { point=point or "CENTER", relativePoint=relativePoint or point or "CENTER", x=x or 0, y=y or 0 }
end

local function PositionProcCards()
    local layout = theme.layout
    local positions
    if layout == "COLUMN" or layout == "TOTEM" then
        positions = {{0,0},{0,-58},{0,-108}}
    elseif layout == "ARC" or layout == "BLOOD" or layout == "VOID" then
        positions = {{0,0},{-58,-42},{58,-42}}
    elseif layout == "STORM" or layout == "CLOCK" or layout == "SUN" or layout == "CELESTIAL" then
        positions = {{0,0},{-64,-26},{64,-26}}
    elseif layout == "TECH" or layout == "VENOM" then
        positions = {{0,0},{-52,48},{52,-48}}
    else
        positions = {{0,0},{58,0},{108,0}}
    end
    local index, card
    for index, card in ipairs(procCards) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", procFrame, "TOPLEFT", positions[index][1], positions[index][2])
    end
end

local function AddBackdrop(frame, alpha)
    frame:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    frame:SetBackdropColor(theme.color[1], theme.color[2], theme.color[3], alpha or 0.88)
    frame:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.92)
end

local function CreateMover(name, frame, label)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    overlay:EnableMouse(true)
    overlay:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    overlay:SetBackdropColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.18)
    overlay:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(label .. "\nGLISSER")
    text:SetTextColor(1,0.88,0.28)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function() frame:StartMoving() end)
    overlay:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SaveModulePosition(name) end)
    overlay:Hide()
    movers[name] = overlay
end

local function IgnoreSignal(signal)
    if not signal or not settings then return end
    settings.ignored[signal.key] = { name=signal.name, ignoredAt=time and time() or 0 }
    updateDirty = true
    Chat(signal.name .. " ne sera plus affiche sur ce personnage. Tu peux le reactiver dans les reglages.")
end

local function CreateProcCard(index)
    local size = index == 1 and 54 or 44
    local card = CreateFrame("Button", nil, procFrame)
    card:SetWidth(size); card:SetHeight(size)
    card:RegisterForClicks("RightButtonUp")
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints(card); card.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    card.cooldown = CreateFrame("Cooldown", nil, card, "CooldownFrameTemplate")
    card.cooldown:SetAllPoints(card)
    card.glow = card:CreateTexture(nil, "OVERLAY")
    card.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); card.glow:SetBlendMode("ADD")
    card.glow:SetWidth(size + 28); card.glow:SetHeight(size + 28); card.glow:SetPoint("CENTER")
    card.glow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.95)
    card.count = card:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    card.count:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -2, 2)
    card.timer = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.timer:SetPoint("TOP", card, "BOTTOM", 0, -1)
    card.kind = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.kind:SetPoint("BOTTOM", card, "TOP", 0, 1); card.kind:SetTextColor(theme.accent[1],theme.accent[2],theme.accent[3])
    card:SetScript("OnClick", function(self, button) if button == "RightButton" then IgnoreSignal(self.signal) end end)
    card:SetScript("OnEnter", function(self)
        if not self.signal or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.signal.name, theme.accent[1],theme.accent[2],theme.accent[3])
        GameTooltip:AddLine("Mecanisme detecte : " .. tostring(self.signal.alias or self.signal.kind), 1,1,1, true)
        if self.signal.tooltip and self.signal.tooltip ~= "" then GameTooltip:AddLine(self.signal.tooltip, 0.78,0.82,0.88, true) end
        GameTooltip:AddLine("Clic droit : ne plus afficher", 1,0.55,0.25)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    card:Hide()
    procCards[index] = card
end

local function CreateVisuals()
    procFrame = CreateFrame("Frame", "CoAEssentialAssistantHUD", UIParent)
    procFrame:SetWidth(160); procFrame:SetHeight(130); procFrame:SetFrameStrata("HIGH")
    procFrame:SetMovable(true); procFrame:SetClampedToScreen(true); procFrame:EnableMouse(false)
    moduleFrames.procs = procFrame
    CreateProcCard(1); CreateProcCard(2); CreateProcCard(3)
    CreateMover("procs", procFrame, "PROCS ESSENTIELS")

    resourceFrame = CreateFrame("Frame", "CoAEssentialResourceHUD", UIParent)
    resourceFrame:SetWidth(176); resourceFrame:SetHeight(28); resourceFrame:SetFrameStrata("HIGH")
    resourceFrame:SetMovable(true); resourceFrame:SetClampedToScreen(true)
    moduleFrames.resource = resourceFrame
    AddBackdrop(resourceFrame, 0.84)
    local resourceIcon = resourceFrame:CreateTexture(nil, "ARTWORK")
    resourceIcon:SetWidth(22); resourceIcon:SetHeight(22); resourceIcon:SetPoint("LEFT", resourceFrame, "LEFT", 3, 0)
    resourceIcon:SetTexture(theme.texture)
    resourceBar = CreateFrame("StatusBar", nil, resourceFrame)
    resourceBar:SetWidth(142); resourceBar:SetHeight(9); resourceBar:SetPoint("TOPLEFT", resourceIcon, "TOPRIGHT", 5, -2)
    resourceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    resourceBar:SetStatusBarColor(theme.accent[1],theme.accent[2],theme.accent[3])
    local bg = resourceBar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(resourceBar); bg:SetTexture(0.04,0.04,0.04,0.9)
    resourceText = resourceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resourceText:SetPoint("BOTTOMLEFT", resourceIcon, "BOTTOMRIGHT", 5, 1); resourceText:SetTextColor(0.92,0.94,1)
    CreateMover("resource", resourceFrame, "RESSOURCE")

    targetFrame = CreateFrame("Button", "CoAEssentialTargetHUD", UIParent)
    targetFrame:SetWidth(150); targetFrame:SetHeight(42); targetFrame:SetFrameStrata("HIGH")
    targetFrame:SetMovable(true); targetFrame:SetClampedToScreen(true); targetFrame:RegisterForClicks("RightButtonUp")
    moduleFrames.target = targetFrame
    AddBackdrop(targetFrame, 0.84)
    targetIcon = targetFrame:CreateTexture(nil, "ARTWORK"); targetIcon:SetWidth(34); targetIcon:SetHeight(34); targetIcon:SetPoint("LEFT",4,0); targetIcon:SetTexCoord(0.07,0.93,0.07,0.93)
    targetCooldown = CreateFrame("Cooldown", nil, targetFrame, "CooldownFrameTemplate"); targetCooldown:SetAllPoints(targetIcon)
    targetGlow = targetFrame:CreateTexture(nil,"OVERLAY"); targetGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); targetGlow:SetBlendMode("ADD")
    targetGlow:SetWidth(52); targetGlow:SetHeight(52); targetGlow:SetPoint("CENTER",targetIcon,"CENTER"); targetGlow:SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3])
    targetText = targetFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); targetText:SetPoint("TOPLEFT",targetIcon,"TOPRIGHT",6,-2); targetText:SetWidth(104); targetText:SetJustifyH("LEFT")
    targetTimer = targetFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); targetTimer:SetPoint("BOTTOMLEFT",targetIcon,"BOTTOMRIGHT",6,2); targetTimer:SetTextColor(theme.accent[1],theme.accent[2],theme.accent[3])
    targetFrame:SetScript("OnClick", function(self, button) if button == "RightButton" then IgnoreSignal(currentTargetSignal) end end)
    targetFrame:SetScript("OnEnter", function(self)
        if not currentTargetSignal or not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(currentTargetSignal.name,theme.accent[1],theme.accent[2],theme.accent[3])
        GameTooltip:AddLine("Effet important que tu as applique sur la cible.",1,1,1,true)
        GameTooltip:AddLine("Clic droit : ne plus afficher",1,0.55,0.25); GameTooltip:Show()
    end)
    targetFrame:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    CreateMover("target", targetFrame, "EFFET CIBLE")

    coverageFrame=CreateFrame("Button","CoAEssentialCoverageHUD",UIParent)
    coverageFrame:SetWidth(184);coverageFrame:SetHeight(42);coverageFrame:SetFrameStrata("HIGH");coverageFrame:SetMovable(true);coverageFrame:SetClampedToScreen(true);coverageFrame:RegisterForClicks("RightButtonUp")
    moduleFrames.coverage=coverageFrame;AddBackdrop(coverageFrame,0.84)
    coverageIcon=coverageFrame:CreateTexture(nil,"ARTWORK");coverageIcon:SetWidth(32);coverageIcon:SetHeight(32);coverageIcon:SetPoint("LEFT",5,0);coverageIcon:SetTexCoord(0.07,0.93,0.07,0.93)
    coverageText=coverageFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");coverageText:SetPoint("TOPLEFT",coverageIcon,"TOPRIGHT",7,-1);coverageText:SetWidth(138);coverageText:SetJustifyH("LEFT")
    coverageTimer=coverageFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");coverageTimer:SetPoint("BOTTOMLEFT",coverageIcon,"BOTTOMRIGHT",7,3)
    local dotIndex
    for dotIndex=1,5 do
        local dot=coverageFrame:CreateTexture(nil,"OVERLAY");dot:SetWidth(5);dot:SetHeight(5);dot:SetPoint("BOTTOMRIGHT",coverageFrame,"BOTTOMRIGHT",-7-(dotIndex-1)*8,5);dot:SetTexture("Interface\\Buttons\\WHITE8X8");coverageDots[dotIndex]=dot
    end
    coverageFrame:SetScript("OnClick",function(_,button)if button=="RightButton" and currentCoverage then IgnoreSignal(currentCoverage)end end)
    coverageFrame:SetScript("OnEnter",function(self)if not currentCoverage then return end;GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(currentCoverage.name,theme.accent[1],theme.accent[2],theme.accent[3]);GameTooltip:AddLine("Couverture observée : "..tostring(currentCoverage.count).."/"..tostring(currentCoverage.total),1,1,1);GameTooltip:AddLine("Clic droit : ne plus afficher",1,0.55,0.25);GameTooltip:Show()end)
    coverageFrame:SetScript("OnLeave",function()GameTooltip:Hide()end)
    CreateMover("coverage",coverageFrame,"COUVERTURE GROUPE")
end

local function ApplyTheme()
    theme = DATA.themes[character.className] or theme
    local resolvedProfile, resolvedKey = ResolveProfile(character.className, character.specName)
    profile = resolvedProfile
    specialistDelegated = resolvedKey == "Cultist:Heretic" and type(CoAHereticHelperAPI) == "table"
    SelectSettings()
    local _, frame
    for _, frame in pairs(moduleFrames) do AddBackdrop(frame, frame == procFrame and 0 or 0.84) end
    if resourceBar then resourceBar:SetStatusBarColor(theme.accent[1],theme.accent[2],theme.accent[3]) end
    if targetGlow then targetGlow:SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3]) end
    local _, card
    for _, card in ipairs(procCards) do
        card.glow:SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3],0.95)
        card.kind:SetTextColor(theme.accent[1],theme.accent[2],theme.accent[3])
    end
    PositionProcCards()
    ApplyModulePosition("procs"); ApplyModulePosition("resource"); ApplyModulePosition("target"); ApplyModulePosition("coverage")
end

local function UpdateMoverVisibility()
    local name, overlay
    for name, overlay in pairs(movers) do
        if settings and not settings.locked then
            overlay:Show(); moduleFrames[name]:Show(); moduleFrames[name]:EnableMouse(true)
        else
            overlay:Hide()
            if name == "procs" or name == "resource" then moduleFrames[name]:EnableMouse(false) end
            if name == "target" then moduleFrames[name]:EnableMouse(true) end
        end
    end
end

local function TestSignal(index)
    local names = { "PROC MAJEUR", "CHARGES", "FENETRE" }
    return {
        key="test"..index, name=names[index], icon=theme.texture or "Interface\\Icons\\INV_Misc_QuestionMark",
        count=index == 2 and 3 or 0, duration=10, expiration=GetTime()+10-index, remaining=10-index,
        score=200, explicit=true, alias=profile and profile.mechanic or theme.resource, kind=names[index]
    }
end

local function UpdateVisuals()
    if not db or not settings then return end
    local now = GetTime()
    local testing = testUntil > now
    local unlocked = not settings.locked
    local enabled = db.enabled and not specialistDelegated
    local signals = testing and {TestSignal(1),TestSignal(2),TestSignal(3)} or currentSignals
    local nextKeys = {}
    local index, card
    for index, card in ipairs(procCards) do
        local signal = signals[index]
        if signal and enabled and settings.modules.procs.enabled then
            card.signal = signal; card.icon:SetTexture(signal.icon); card.count:SetText(signal.count and signal.count > 1 and tostring(signal.count) or "")
            card.kind:SetText(signal.kind or "PROC")
            local remaining = signal.expiration and signal.expiration > 0 and max(0,signal.expiration-now) or signal.remaining
            card.timer:SetText(remaining and remaining > 0 and string.format("%.1f",remaining) or "")
            if card.cooldown and card.cooldown.SetCooldown and signal.duration and signal.duration > 0 and signal.expiration and signal.expiration > 0 then
                card.cooldown:SetCooldown(signal.expiration-signal.duration,signal.duration)
            end
            card:Show(); nextKeys[signal.key]=true; PlaySignalSound(signal)
        else card.signal=nil; card:Hide() end
    end
    activeSignalKeys = nextKeys
    if enabled and settings.modules.procs.enabled and (#signals > 0 or unlocked) then procFrame:Show() else procFrame:Hide() end

    local resource = testing and {current=82,maximum=100,percent=0.82,urgent=true,name=theme.resource or "Ressource",source="test"} or currentResource
    local showResource = enabled and settings.modules.resource.enabled and resource and (resource.urgent or unlocked or testing)
    if showResource then
        resourceBar:SetMinMaxValues(0,resource.maximum); resourceBar:SetValue(resource.current)
        if resource.urgent then resourceBar:SetStatusBarColor(1.00,0.34,0.12) else resourceBar:SetStatusBarColor(theme.accent[1],theme.accent[2],theme.accent[3]) end
        resourceText:SetText((resource.name or "Ressource") .. "  " .. tostring(floor(resource.current+0.5)) .. "/" .. tostring(floor(resource.maximum+0.5)))
        resourceFrame:Show()
    elseif unlocked then resourceText:SetText((theme.resource or "Ressource") .. "  aperçu"); resourceFrame:Show()
    else resourceFrame:Hide() end

    local targetSignal = testing and {name="EFFET CIBLE",icon=theme.texture,duration=10,expiration=now+4.5,remaining=4.5,kind="CIBLE"} or currentTargetSignal
    if enabled and settings.modules.target.enabled and (targetSignal or unlocked) then
        targetIcon:SetTexture(targetSignal and targetSignal.icon or theme.texture)
        targetText:SetText(targetSignal and targetSignal.name or "Effet cible")
        local remaining = targetSignal and targetSignal.expiration and targetSignal.expiration > 0 and max(0,targetSignal.expiration-now) or nil
        targetTimer:SetText(remaining and string.format("expire %.1f s",remaining) or "aucun effet actif")
        if targetSignal and targetCooldown and targetCooldown.SetCooldown and targetSignal.duration and targetSignal.duration > 0 then targetCooldown:SetCooldown(targetSignal.expiration-targetSignal.duration,targetSignal.duration) end
        targetFrame:Show()
    else targetFrame:Hide() end

    local coverage=testing and {name="COUVERTURE GROUPE",icon=theme.texture,count=4,total=5,minimum=6.2,members={[1]=true,[2]=true,[3]=true,[4]=true}} or currentCoverage
    if enabled and settings.modules.coverage.enabled and (coverage or unlocked) then
        coverageIcon:SetTexture(coverage and coverage.icon or theme.texture)
        coverageText:SetText(coverage and (coverage.name.."  "..tostring(coverage.count).."/"..tostring(coverage.total)) or "Couverture groupe")
        coverageTimer:SetText(coverage and coverage.minimum and string.format("plus court : %.1f s",coverage.minimum) or (coverage and coverage.missing and "ABSENT DU GROUPE" or "aucun suivi appris"))
        local dotIndex,dot
        for dotIndex,dot in ipairs(coverageDots) do
            if coverage and dotIndex<=min(5,coverage.total) then
                dot:SetVertexColor(coverage.members[dotIndex] and theme.accent[1] or 1,coverage.members[dotIndex] and theme.accent[2] or 0.18,coverage.members[dotIndex] and theme.accent[3] or 0.12,1);dot:Show()
            else dot:Hide() end
        end
        coverageFrame:Show()
    else coverageFrame:Hide() end
    UpdateMoverVisibility()
end

local function FullScan(reason, quiet)
    EnsureDatabase()
    local previousClass = character.className
    character = ResolveCharacter()
    theme = DATA.themes[character.className] or theme
    profile = ResolveProfile(character.className, character.specName)
    ScanSpellbook(); ScanTalents(); ApplyTheme(); ScanSignals(); ReadResource(); ScanCoverage(); RefreshUpdateNotice(); UpdateVisuals()
    updateDirty = false
    coverageDirty = false
    if not quiet then
        Chat((reason or "scan") .. " : " .. character.className .. " / " .. character.specName .. " niv. " .. tostring(character.level)
            .. " - " .. tostring(#spellOrder) .. " sorts, " .. tostring(talentCount) .. " talents.")
    elseif previousClass ~= character.className then Chat("profil visuel adapte a " .. character.className .. ".") end
end

local function ScheduleFullScan(reason)
    fullScanReason = reason or fullScanReason or "mise a jour"
    fullScanAt = GetTime() + 0.25
end

local function SetLocked(value)
    settings.locked = value and true or false
    UpdateVisuals()
    Chat(settings.locked and "modules verrouilles." or "deplacement libre : glisse chaque zone separement.")
end

local function ResetLayout()
    settings.positions = {}
    settings.modules = { procs={enabled=true,scale=1,alpha=1}, resource={enabled=true,scale=1,alpha=0.95}, target={enabled=true,scale=1,alpha=0.95}, coverage={enabled=true,scale=1,alpha=0.95} }
    settings.ignored = {}
    ApplyTheme(); UpdateVisuals(); Chat("disposition " .. tostring(theme.layout) .. " restauree pour " .. character.className .. ".")
end

local function ToggleRotationHUDPolicy()
    db.hideRotationHUD = not db.hideRotationHUD
    if CoARotationGuideAPI and CoARotationGuideAPI.SetHUDEnabled then CoARotationGuideAPI:SetHUDEnabled(not db.hideRotationHUD) end
    Chat(db.hideRotationHUD and "HUD de rotation masque ; le guide reste accessible." or "HUD de rotation de nouveau autorise.")
end

local function ApplyCompanionPolicy()
    if db.hideRotationHUD and CoARotationGuideAPI and CoARotationGuideAPI.SetHUDEnabled then
        pcall(CoARotationGuideAPI.SetHUDEnabled, CoARotationGuideAPI, false)
    end
    if CoAStormbringerHelperAPI and CoAStormbringerHelperAPI.SetUniversalManaged then
        pcall(CoAStormbringerHelperAPI.SetUniversalManaged, CoAStormbringerHelperAPI, true)
    end
    if CoAPrimalistHelperAPI and CoAPrimalistHelperAPI.SetUniversalManaged then
        pcall(CoAPrimalistHelperAPI.SetUniversalManaged, CoAPrimalistHelperAPI, true)
    end
end

local function MakeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 118); button:SetHeight(height or 22); button:SetText(text)
    return button
end

local function SavePanelPosition()
    local point, _, relativePoint, x, y = panel:GetPoint(1)
    db.panel = { point=point or "CENTER", relativePoint=relativePoint or point or "CENTER", x=x or 0, y=y or 0 }
end

local function ModuleLabel(name)
    local labels = {procs="PROCS / FENETRES",resource="RESSOURCE CRITIQUE",target="EFFET SUR LA CIBLE",coverage="COUVERTURE DU GROUPE"}
    return labels[name] or name
end

local function RefreshPanel()
    if not panel then return end
    local color = theme.accent
    panel:SetBackdropBorderColor(color[1],color[2],color[3],0.95)
    panelWidgets.title:SetText("CoA Essentiel  •  " .. character.className)
    panelWidgets.title:SetTextColor(color[1],color[2],color[3])
    panelWidgets.identity:SetText(character.specName .. "  •  niveau " .. tostring(character.level) .. "  •  " .. tostring(character.role))
    panelWidgets.mechanic:SetText(profile and ("Surveille : " .. profile.mechanic) or "Avant la specialisation : seuls les procs certains sont affiches.")
    local status = specialistDelegated and "Hérétique : le HUD spécialisé Sang noir / soin instantané garde la main."
        or (#currentSignals > 0 and (tostring(#currentSignals) .. " mécanisme(s) actif(s) détecté(s).") or "Rien d'indispensable maintenant : l'écran reste propre.")
    if latestUpdate then status = status .. "\nActu officielle à vérifier : " .. tostring(latestUpdate.title or "changement récent") end
    panelWidgets.status:SetText(status)
    panelWidgets.profile:SetText("PROFIL : " .. db.profileMode)
    panelWidgets.enabled:SetText(db.enabled and "ASSISTANT : ON" or "ASSISTANT : OFF")
    panelWidgets.sound:SetText(db.sound and "SON : ON" or "SON : OFF")
    panelWidgets.rotation:SetText(db.hideRotationHUD and "ROTATION MASQUÉE" or "ROTATION AUTORISÉE")
    panelWidgets.lock:SetText(settings.locked and "DÉPLACER LES MODULES" or "VERROUILLER")
    local name, row
    for name, row in pairs(panelWidgets.moduleRows) do
        local config = settings.modules[name]
        row.toggle:SetText(config.enabled and "ON" or "OFF")
        row.value:SetText(string.format("taille %.2f  •  alpha %.2f",config.scale,config.alpha))
        row.label:SetText(ModuleLabel(name))
        row.label:SetTextColor(color[1],color[2],color[3])
    end
    local observed = {}
    local key, value
    for key, value in pairs(settings.seen) do table.insert(observed,{key=key,name=value.name or key,lastSeen=tonumber(value.lastSeen) or 0}) end
    table.sort(observed,function(a,b)if a.lastSeen~=b.lastSeen then return a.lastSeen>b.lastSeen end return a.name<b.name end)
    local index,button
    for index,button in ipairs(panelWidgets.mechanicRows or {}) do
        local item=observed[index]
        if item then
            button.mechanicKey=item.key;button.mechanicName=item.name
            button:SetText((settings.ignored[item.key] and "RÉACTIVER  " or "IGNORER  ")..item.name);button:Show()
        else button.mechanicKey=nil;button:Hide() end
    end
    panelWidgets.ignored:SetText(#observed==0 and "Aucun mécanisme encore observé sur ce personnage." or "MÉCANISMES APPRIS • les trois plus récents")
end

local function AdjustModule(name, field, delta)
    local config = settings.modules[name]
    config[field] = Clamp((tonumber(config[field]) or 1) + delta, field == "scale" and 0.55 or 0.20, field == "scale" and 1.80 or 1.00)
    ApplyModulePosition(name); UpdateVisuals(); RefreshPanel()
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CoAEssentialAssistantSettings", UIParent)
    panel:SetWidth(500); panel:SetHeight(590); panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true); panel:SetClampedToScreen(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=14,insets={left=4,right=4,top=4,bottom=4}})
    panel:SetBackdropColor(0.008,0.016,0.032,0.97)
    panel:SetScript("OnDragStart",function(self)self:StartMoving()end)
    panel:SetScript("OnDragStop",function(self)self:StopMovingOrSizing();SavePanelPosition()end)
    local pos=db.panel or {}; panel:SetPoint(pos.point or "CENTER",UIParent,pos.relativePoint or "CENTER",pos.x or 0,pos.y or 40)

    panelWidgets.title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); panelWidgets.title:SetPoint("TOPLEFT",18,-16)
    panelWidgets.identity=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight"); panelWidgets.identity:SetPoint("TOPLEFT",18,-44)
    panelWidgets.mechanic=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); panelWidgets.mechanic:SetPoint("TOPLEFT",18,-66); panelWidgets.mechanic:SetWidth(460); panelWidgets.mechanic:SetJustifyH("LEFT")
    panelWidgets.status=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); panelWidgets.status:SetPoint("TOPLEFT",18,-90); panelWidgets.status:SetWidth(460); panelWidgets.status:SetJustifyH("LEFT"); panelWidgets.status:SetTextColor(0.70,0.82,0.90)
    local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5)

    panelWidgets.enabled=MakeButton(panel,"ASSISTANT : ON",138); panelWidgets.enabled:SetPoint("TOPLEFT",18,-122)
    panelWidgets.enabled:SetScript("OnClick",function()db.enabled=not db.enabled;UpdateVisuals();RefreshPanel()end)
    panelWidgets.sound=MakeButton(panel,"SON : ON",100); panelWidgets.sound:SetPoint("LEFT",panelWidgets.enabled,"RIGHT",6,0)
    panelWidgets.sound:SetScript("OnClick",function()db.sound=not db.sound;RefreshPanel()end)
    panelWidgets.profile=MakeButton(panel,"PROFIL",120); panelWidgets.profile:SetPoint("LEFT",panelWidgets.sound,"RIGHT",6,0)
    panelWidgets.profile:SetScript("OnClick",function()db.profileMode=db.profileMode=="GLOBAL" and "CHARACTER" or "GLOBAL";SelectSettings();ApplyTheme();UpdateVisuals();RefreshPanel()end)
    panelWidgets.rotation=MakeButton(panel,"ROTATION MASQUÉE",148); panelWidgets.rotation:SetPoint("TOPLEFT",18,-152)
    panelWidgets.rotation:SetScript("OnClick",function()ToggleRotationHUDPolicy();RefreshPanel()end)
    panelWidgets.lock=MakeButton(panel,"DÉPLACER",154); panelWidgets.lock:SetPoint("LEFT",panelWidgets.rotation,"RIGHT",6,0)
    panelWidgets.lock:SetScript("OnClick",function()SetLocked(not settings.locked);RefreshPanel()end)
    local test=MakeButton(panel,"APERÇU 10 S",126); test:SetPoint("LEFT",panelWidgets.lock,"RIGHT",6,0)
    test:SetScript("OnClick",function()testUntil=GetTime()+10;UpdateVisuals();panel:Hide()end)

    panelWidgets.moduleRows={}
    local moduleNames={"procs","resource","target","coverage"}
    local rowIndex,name
    for rowIndex,name in ipairs(moduleNames) do
        local moduleName=name
        local row=CreateFrame("Frame",nil,panel); row:SetWidth(464); row:SetHeight(58); row:SetPoint("TOPLEFT",18,-190-(rowIndex-1)*62)
        row:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); row:SetBackdropColor(0.03,0.05,0.08,0.88); row:SetBackdropBorderColor(0.12,0.22,0.30,0.9)
        row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.label:SetPoint("TOPLEFT",10,-8)
        row.value=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.value:SetPoint("BOTTOMLEFT",10,8); row.value:SetTextColor(0.72,0.78,0.84)
        row.toggle=MakeButton(row,"ON",46,20); row.toggle:SetPoint("RIGHT",row,"RIGHT",-8,0); row.toggle:SetScript("OnClick",function()settings.modules[moduleName].enabled=not settings.modules[moduleName].enabled;UpdateVisuals();RefreshPanel()end)
        row.alphaPlus=MakeButton(row,"A+",36,20); row.alphaPlus:SetPoint("RIGHT",row.toggle,"LEFT",-4,0); row.alphaPlus:SetScript("OnClick",function()AdjustModule(moduleName,"alpha",0.1)end)
        row.alphaMinus=MakeButton(row,"A-",36,20); row.alphaMinus:SetPoint("RIGHT",row.alphaPlus,"LEFT",-4,0); row.alphaMinus:SetScript("OnClick",function()AdjustModule(moduleName,"alpha",-0.1)end)
        row.scalePlus=MakeButton(row,"+",30,20); row.scalePlus:SetPoint("RIGHT",row.alphaMinus,"LEFT",-4,0); row.scalePlus:SetScript("OnClick",function()AdjustModule(moduleName,"scale",0.1)end)
        row.scaleMinus=MakeButton(row,"-",30,20); row.scaleMinus:SetPoint("RIGHT",row.scalePlus,"LEFT",-4,0); row.scaleMinus:SetScript("OnClick",function()AdjustModule(moduleName,"scale",-0.1)end)
        panelWidgets.moduleRows[moduleName]=row
    end

    panelWidgets.ignored=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); panelWidgets.ignored:SetPoint("TOPLEFT",18,-454); panelWidgets.ignored:SetWidth(300); panelWidgets.ignored:SetJustifyH("LEFT"); panelWidgets.ignored:SetTextColor(0.72,0.78,0.84)
    panelWidgets.mechanicRows={}
    local learnedIndex
    for learnedIndex=1,3 do
        local learned=MakeButton(panel,"",292,20);learned:SetPoint("TOPLEFT",18,-472-(learnedIndex-1)*22)
        learned:SetScript("OnClick",function(self)
            if not self.mechanicKey then return end
            if settings.ignored[self.mechanicKey] then settings.ignored[self.mechanicKey]=nil
            else settings.ignored[self.mechanicKey]={name=self.mechanicName,ignoredAt=time and time() or 0} end
            updateDirty=true;RefreshPanel()
        end)
        panelWidgets.mechanicRows[learnedIndex]=learned
    end
    local reactivate=MakeButton(panel,"RÉACTIVER TOUS",142); reactivate:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-18,-472)
    reactivate:SetScript("OnClick",function()settings.ignored={};updateDirty=true;RefreshPanel();Chat("mecanismes ignores reactives.")end)
    local scan=MakeButton(panel,"RESCANNER",108); scan:SetPoint("BOTTOMLEFT",18,18); scan:SetScript("OnClick",function()FullScan("scan manuel",false);RefreshPanel()end)
    local reset=MakeButton(panel,"RESET CLASSE",126); reset:SetPoint("LEFT",scan,"RIGHT",8,0); reset:SetScript("OnClick",function()ResetLayout();RefreshPanel()end)
    local done=MakeButton(panel,"TERMINÉ",110); done:SetPoint("BOTTOMRIGHT",-18,18); done:SetScript("OnClick",function()panel:Hide()end)
    local footer=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); footer:SetPoint("BOTTOM",0,48); footer:SetText("Aucune rotation • aucun sort lancé • clic droit sur une alerte pour l'ignorer"); footer:SetTextColor(0.45,0.62,0.70)
    panel:Hide()
end

local function TogglePanel()
    if panel:IsShown() then panel:Hide() else RefreshPanel();panel:Show() end
end

local function MinimapPosition()
    local angle=math.rad(tonumber(db.minimapAngle) or 215)
    minimapButton:ClearAllPoints();minimapButton:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*80,math.sin(angle)*80)
end

local function CreateMinimapButton()
    minimapButton=CreateFrame("Button","CoAEssentialAssistantMinimapButton",Minimap)
    minimapButton:SetWidth(31);minimapButton:SetHeight(31);minimapButton:SetFrameStrata("MEDIUM");minimapButton:SetMovable(true);minimapButton:RegisterForDrag("LeftButton")
    local icon=minimapButton:CreateTexture(nil,"BACKGROUND");icon:SetWidth(20);icon:SetHeight(20);icon:SetPoint("CENTER",0,1);icon:SetTexture("Interface\\Icons\\Spell_Arcane_Arcane01");icon:SetTexCoord(0.08,0.92,0.08,0.92)
    local border=minimapButton:CreateTexture(nil,"OVERLAY");border:SetWidth(53);border:SetHeight(53);border:SetPoint("TOPLEFT");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local highlight=minimapButton:CreateTexture(nil,"HIGHLIGHT");highlight:SetWidth(31);highlight:SetHeight(31);highlight:SetPoint("CENTER");highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");highlight:SetBlendMode("ADD")
    minimapButton:SetScript("OnClick",function(_,button)if button=="RightButton"then SetLocked(not settings.locked);RefreshPanel()else TogglePanel()end end)
    minimapButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    minimapButton:SetScript("OnDragStart",function(self)self:SetScript("OnUpdate",function()
        local mx,my=Minimap:GetCenter();local cx,cy=GetCursorPosition();local scale=UIParent:GetEffectiveScale();cx,cy=cx/scale,cy/scale
        db.minimapAngle=math.deg(SafeAtan2(cy-my,cx-mx));MinimapPosition()
    end)end)
    minimapButton:SetScript("OnDragStop",function(self)self:SetScript("OnUpdate",nil)end)
    minimapButton:SetScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:AddLine("CoA Essentiel",theme.accent[1],theme.accent[2],theme.accent[3]);GameTooltip:AddLine("Clic : réglages",1,1,1);GameTooltip:AddLine("Clic droit : déplacer/verrouiller",0.8,0.8,0.8);GameTooltip:Show()end)
    minimapButton:SetScript("OnLeave",function()GameTooltip:Hide()end)
    MinimapPosition()
end

local function UpdateMinimap()
    if not minimapButton then return end
    -- Ce bouton reste volontairement autonome : les movers du UI Manager ne
    -- doivent jamais retirer l'acces aux reglages de cet assistant.
    if db.minimap then minimapButton:Show() else minimapButton:Hide() end
end

local function HandleSlash(message)
    local command=Lower(Trim(message))
    if command=="" then TogglePanel()
    elseif command=="unlock" then SetLocked(false)
    elseif command=="lock" then SetLocked(true)
    elseif command=="test" then testUntil=GetTime()+10;UpdateVisuals()
    elseif command=="scan" then FullScan("scan manuel",false)
    elseif command=="profile" then db.profileMode=db.profileMode=="GLOBAL" and "CHARACTER" or "GLOBAL";SelectSettings();ApplyTheme();UpdateVisuals();Chat("profil "..db.profileMode..".")
    elseif command=="sound" then db.sound=not db.sound;Chat("son "..(db.sound and "ON" or "OFF")..".")
    elseif command=="rotation" then ToggleRotationHUDPolicy()
    elseif command=="reset" then ResetLayout()
    elseif command=="status" then Chat(character.className.." / "..character.specName.." niv. "..tostring(character.level).." • "..tostring(#spellOrder).." sorts • "..tostring(talentCount).." talents • "..tostring(#currentSignals).." signal(s)")
    else Chat("/cea : unlock, lock, test, scan, profile, sound, rotation, reset, status") end
    RefreshPanel()
end

SLASH_COAESSENTIALASSISTANT1="/cea"
SLASH_COAESSENTIALASSISTANT2="/essentiel"
SlashCmdList.COAESSENTIALASSISTANT=HandleSlash

CoAEssentialAssistantAPI=CoAEssentialAssistantAPI or {}
function CoAEssentialAssistantAPI:Toggle() TogglePanel() end
function CoAEssentialAssistantAPI:Show() RefreshPanel();panel:Show() end
function CoAEssentialAssistantAPI:SetHubManaged(value) hubManaged=value and true or false;UpdateMinimap() end
function CoAEssentialAssistantAPI:Refresh() FullScan("API",true) end
function CoAEssentialAssistantAPI:GetStatus()
    return {version=VERSION,className=character.className,specName=character.specName,level=character.level,role=character.role,signals=#currentSignals,delegated=specialistDelegated,locked=settings and settings.locked}
end

local eventFrame=CreateFrame("Frame")
for _,event in ipairs({
    "ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEVEL_UP","SPELLS_CHANGED","LEARNED_SPELL_IN_TAB",
    "CHARACTER_POINTS_CHANGED","PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_SPECIALIZATION_CHANGED",
    "UNIT_AURA","PLAYER_TARGET_CHANGED","UNIT_POWER","UNIT_DISPLAYPOWER","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_SUCCEEDED"
}) do pcall(eventFrame.RegisterEvent,eventFrame,event) end

eventFrame:SetScript("OnEvent",function(_,event,...)
    local first=...
    if event=="ADDON_LOADED" and first==ADDON_NAME then
        EnsureDatabase();character=ResolveCharacter();theme=DATA.themes[character.className] or theme;SelectSettings();CreateVisuals();ApplyTheme();CreatePanel();CreateMinimapButton();UpdateMinimap()
    elseif event=="PLAYER_LOGIN" then
        FullScan("connexion",true);ApplyCompanionPolicy();UpdateMinimap()
        Chat("v"..VERSION.." active : procs essentiels uniquement, disposition "..tostring(theme.layout)..".")
    elseif event=="UNIT_AURA" then
        if first=="player" or first=="target" or first==nil then updateDirty=true end
        if first=="player" or first==nil or Contains(first,"party") or Contains(first,"raid") then coverageDirty=true end
    elseif event=="UNIT_POWER" or event=="UNIT_DISPLAYPOWER" then
        if first=="player" or first==nil then updateDirty=true end
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        if first=="player" or first==nil then updateDirty=true end
    elseif event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_REGEN_ENABLED" then updateDirty=true;coverageDirty=true
    else
        updateDirty=true
        coverageDirty=true
        if event=="PLAYER_LEVEL_UP" or event=="SPELLS_CHANGED" or event=="CHARACTER_POINTS_CHANGED" or event=="PLAYER_TALENT_UPDATE" or event=="ACTIVE_TALENT_GROUP_CHANGED" or event=="PLAYER_SPECIALIZATION_CHANGED" or event=="PLAYER_ENTERING_WORLD" then
            ScheduleFullScan(Lower(event))
        end
    end
end)

eventFrame:SetScript("OnUpdate",function(_,elapsed)
    elapsedUpdate=elapsedUpdate+(tonumber(elapsed) or 0)
    elapsedCoverage=elapsedCoverage+(tonumber(elapsed) or 0)
    elapsedClock=elapsedClock+(tonumber(elapsed) or 0)
    if fullScanAt and GetTime()>=fullScanAt then
        local reason=fullScanReason
        fullScanAt=nil;fullScanReason=nil
        FullScan(reason,true);ApplyCompanionPolicy()
    end
    if elapsedUpdate>=0.15 then
        elapsedUpdate=0
        if updateDirty and settings then ScanSignals();ReadResource();updateDirty=false end
        UpdateVisuals()
    end
    local raidCount=GetNumRaidMembers and tonumber(GetNumRaidMembers()) or 0
    local coverageInterval=raidCount>0 and 0.90 or 0.40
    if elapsedCoverage>=coverageInterval then
        elapsedCoverage=0
        if coverageDirty and settings then ScanCoverage();coverageDirty=false;UpdateVisuals() end
    end
    if elapsedClock>=1 then elapsedClock=0; if panel and panel:IsShown() then RefreshPanel() end end
end)
