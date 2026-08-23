local addonName = ...
local DATA = CoARotationGuideData or { profiles = {}, aliases = {}, curated = {}, sources = {} }

local guideFrame
local minimapButton
local rows = {}
local buttons = {}
local spellbook = {}
local spellOrder = {}
local activeTalents = {}
local activeTalentList = {}
local currentCharacter = {}
local currentGuide = nil
local hubManaged = false
local viewMode = "GUIDE"
local scheduledScanAt = nil
local scannerTooltip

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66CoA Rotation Guide:|r " .. tostring(message))
    end
end

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function Trim(value)
    return string.gsub(string.gsub(tostring(value or ""), "^%s+", ""), "%s+$", "")
end

local function Contains(text, fragment)
    return string.find(text or "", fragment, 1, true) ~= nil
end

local function ContainsAny(text, fragments)
    local _, fragment
    for _, fragment in ipairs(fragments) do
        if Contains(text, fragment) then return true end
    end
    return false
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function AngleFromDelta(x, y)
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

local function EnsureDatabase()
    CoARotationGuideDB = CoARotationGuideDB or {}
    if CoARotationGuideDB.context ~= "AOE" then CoARotationGuideDB.context = "ST" end
    if CoARotationGuideDB.content ~= "GROUP" then CoARotationGuideDB.content = "SOLO" end
    CoARotationGuideDB.position = CoARotationGuideDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    CoARotationGuideDB.minimap = CoARotationGuideDB.minimap or {}
    if type(CoARotationGuideDB.minimap.angle) ~= "number" then CoARotationGuideDB.minimap.angle = 2.65 end
    if type(CoARotationGuideDB.minimap.hidden) ~= "boolean" then CoARotationGuideDB.minimap.hidden = false end
    if type(CoARotationGuideDB.showPreparation) ~= "boolean" then CoARotationGuideDB.showPreparation = true end
end

local function SavePosition()
    if not guideFrame then return end
    EnsureDatabase()
    local point, _, relativePoint, x, y = guideFrame:GetPoint(1)
    CoARotationGuideDB.position = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = tonumber(x) or 0,
        y = tonumber(y) or 0
    }
end

local function RestorePosition()
    if not guideFrame then return end
    EnsureDatabase()
    local position = CoARotationGuideDB.position
    guideFrame:ClearAllPoints()
    guideFrame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or position.point or "CENTER", position.x or 0, position.y or 0)
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
    local resolved = DATA.aliases and DATA.aliases[key] or key
    return DATA.profiles and DATA.profiles[resolved] or nil, resolved
end

local function ResolveActiveSpecialization()
    local className, classToken = UnitClass("player")
    className = className or classToken or "Classe inconnue"
    local resolved = {
        className = className,
        classToken = classToken or "UNKNOWN",
        specName = "Avant specialisation",
        role = "DAMAGE",
        source = "niveau/talents"
    }

    if type(C_ClassInfo) == "table"
        and type(C_ClassInfo.GetAllSpecs) == "function"
        and type(C_ClassInfo.GetSpecInfo) == "function"
        and type(GetSpecialization) == "function"
    then
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
                    resolved.specInfo = specInfo
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
    if bestName then resolved.specName = bestName end
    local profile = ResolveProfile(resolved.className, resolved.specName)
    if profile then resolved.role = profile.role end
    return resolved
end

local function ScanTalents()
    activeTalents = {}
    activeTalentList = {}
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo then return end
    local tab
    for tab = 1, GetNumTalentTabs() do
        local talentCount = tonumber(GetNumTalents(tab)) or 0
        local index
        for index = 1, talentCount do
            local ok, name, icon, tier, column, rank = pcall(GetTalentInfo, tab, index)
            rank = ok and tonumber(rank) or 0
            if ok and name and rank and rank > 0 then
                local talent = { name = name, icon = icon, tier = tier, column = column, rank = rank, tab = tab }
                activeTalents[Lower(name)] = talent
                table.insert(activeTalentList, talent)
            end
        end
    end
end

local function TooltipText(spellIndex, book)
    if not scannerTooltip then return "" end
    scannerTooltip:ClearLines()
    local success = false
    if scannerTooltip.SetSpellBookItem then
        success = pcall(scannerTooltip.SetSpellBookItem, scannerTooltip, spellIndex, book)
    end
    if not success and scannerTooltip.SetSpell then
        success = pcall(scannerTooltip.SetSpell, scannerTooltip, spellIndex, book)
    end
    if not success then return "" end
    local text = ""
    local line
    for line = 1, 20 do
        local left = _G["CoARotationGuideScannerTooltipTextLeft" .. line]
        local right = _G["CoARotationGuideScannerTooltipTextRight" .. line]
        if left and left.GetText and left:GetText() then text = text .. " " .. left:GetText() end
        if right and right.GetText and right:GetText() then text = text .. " " .. right:GetText() end
    end
    scannerTooltip:Hide()
    return Trim(text)
end

local function ClassifySpell(spell)
    local name = Lower(spell.name)
    local tooltip = Lower(spell.tooltip)
    local combined = name .. " " .. tooltip
    local categories = {}

    categories.heal = ContainsAny(combined, { " heal", "heals", "healing", "soigne", "rend ", "mending", "repair shot" })
    categories.absorb = ContainsAny(combined, { "absorb", "shield", "barrier", "bouclier", "absorbe" })
    categories.mitigation = categories.absorb or ContainsAny(combined, { "damage taken", "reduces damage", "block", "parry", "armor", "ironfur", "brace", "formation", "degats subis", "reduit les degats" })
    categories.summon = ContainsAny(combined, { "summon", "raises ", "raise:", "animate:", "invoque", "call ", "build:", "turret", "elemental", "companion" })
    categories.dot = ContainsAny(combined, { "damage every", "damage over", "each sec", "every 2 sec", "every 3 sec", "plague", "poison", "venom", "corruption", "bleed", "blight", "burning", "curse", "degats toutes", "degats pendant" })
    categories.hot = categories.heal and ContainsAny(combined, { "every", "over ", "each sec", "toutes", "pendant", "black blood" })
    categories.aoe = ContainsAny(combined, { "nearby enem", "all enem", "up to ", "within ", "around ", "area", "cone", "chain", "nearby allies", "party", "raid", "storm", "nova", "rain", "sweep", "volley", "whirl", "explosion", "swarm", "eruption", "wave", "barrage", "slam", "ritual", "ennemis proches", "allies proches", "groupe" })
    categories.execute = ContainsAny(combined, { "below 35", "below 30", "below 25", "below 20", "execute", "decapitate", "finishing", "cible a moins" })
    categories.combo = ContainsAny(combined, { "combo", "sequence", "after casting", "after using", "next ability", "chaine", "apres avoir" })
    categories.builder = ContainsAny(combined, { "generate", "generates", "gain static", "grants static", "runic power", "solar power", "deathfire", "holy rune", "felfury", "scrap", "ammunition", "sanity", "insanity", "glacial tap", "runic harvest", "solar invocation" })
        and not ContainsAny(combined, { "consume", "spend", "cost per", "each extra" })
    categories.spender = ContainsAny(combined, { "consume", "consumes", "spend", "spends", "each extra point", "remaining energy", "command: undead", "entropic slam", "hammer of twilight", "radiant conversion" })
    categories.debuff = categories.dot or ContainsAny(combined, { "reduces the target", "weakens", "vulnerable", "slows", "disease", "hex", "malediction", "affaiblit", "ralentit" })
    categories.buff = ContainsAny(combined, { "increases your", "increases the", "grants you", "empowers", "stance", "presence", "vow of", "formation", "ward", "whispers", "reinforcement", "augmente", "confere" })

    local hasDamageText = ContainsAny(combined, { " damage", "weapon damage", "damaging", "degats", "attaque" })
    local damageName = ContainsAny(name, { "strike", "shot", "blast", "bolt", "slash", "slam", "sweep", "ram", "swarm", "plague", "harvest", "pulverize", "justice", "execution", "retribution", "attack" })
    categories.direct = (hasDamageText or damageName) and not categories.dot
    spell.categories = categories
end

local function ScanSpellbook()
    spellbook = {}
    spellOrder = {}
    local book = BOOKTYPE_SPELL or "spell"
    if not GetNumSpellTabs or not GetSpellTabInfo or not GetSpellName then return end
    local tab
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        local index
        for index = (tonumber(offset) or 0) + 1, (tonumber(offset) or 0) + (tonumber(count) or 0) do
            local name, rank = GetSpellName(index, book)
            if name then
                local passive = false
                if IsPassiveSpell then
                    local ok, result = pcall(IsPassiveSpell, index, book)
                    passive = ok and result and true or false
                end
                local icon
                if GetSpellInfo then
                    local ok, _, _, texture = pcall(GetSpellInfo, index, book)
                    if ok then icon = texture end
                end
                if not icon and GetSpellTexture then
                    local ok, texture = pcall(GetSpellTexture, index, book)
                    if ok then icon = texture end
                end
                local spell = {
                    name = name,
                    rank = rank or "",
                    index = index,
                    icon = icon,
                    passive = passive,
                    tooltip = TooltipText(index, book)
                }
                ClassifySpell(spell)
                spellbook[Lower(name)] = spell
                table.insert(spellOrder, spell)
            end
        end
    end
end

local function FocusBonus(profile, spell)
    if not profile or not profile.focus then return 0 end
    local bonus = 0
    local index, category
    for index, category in ipairs(profile.focus) do
        if spell.categories[category] then
            local value = 70 - index * 10
            if value > bonus then bonus = value end
        end
    end
    return bonus
end

local function BaseScore(spell, role, context, content)
    local c = spell.categories
    local score = 5
    if role == "HEALER" then
        if c.heal then score = score + 80 end
        if c.hot then score = score + 25 end
        if c.absorb then score = score + 45 end
        if content == "GROUP" and c.aoe then score = score + 50 end
        if c.direct and not c.heal then score = score + 12 end
    elseif role == "TANK" then
        if c.mitigation then score = score + 85 end
        if c.absorb then score = score + 30 end
        if c.heal then score = score + 28 end
        if c.direct then score = score + 30 end
        if c.aoe then score = score + 35 end
    elseif role == "SUPPORT" then
        if c.buff then score = score + 85 end
        if c.debuff then score = score + 45 end
        if c.direct then score = score + 25 end
        if c.aoe then score = score + 25 end
    else
        if c.direct then score = score + 65 end
        if c.dot then score = score + 48 end
        if c.builder then score = score + 42 end
        if c.spender then score = score + 58 end
        if c.execute then score = score + 45 end
        if c.summon then score = score + 22 end
    end
    if context == "AOE" then
        if c.aoe then score = score + 75 else score = score - 18 end
    elseif c.aoe then
        score = score - 12
    end
    return score
end

local function TalentPromotion(curated, spellName)
    if not curated or not curated.talentPromotions then return 0, nil end
    local talentName, promoted
    for talentName, promoted in pairs(curated.talentPromotions) do
        if activeTalents[Lower(talentName)] then
            local _, name
            for _, name in ipairs(promoted) do
                if Lower(name) == Lower(spellName) then return 140, talentName end
            end
        end
    end
    return 0, nil
end

local function InstructionFor(entry, position, role, context)
    local spell = entry.spell
    local c = spell.categories
    if c.execute then return "Garde " .. spell.name .. " pour une cible affaiblie ; la lancer trop tot gaspille sa valeur." end
    if c.builder and not c.spender then return "Utilise " .. spell.name .. " pour remonter ta ressource, sans la laisser deborder." end
    if c.spender then return "Depense avec " .. spell.name .. " quand la ressource est prete ; evite de le forcer a vide." end
    if role == "HEALER" and c.absorb then return "Pose " .. spell.name .. " avant les degats previsibles, pas apres le choc." end
    if role == "HEALER" and c.hot then return "Entretiens " .. spell.name .. " sur la cible exposee, puis passe au soin suivant." end
    if role == "HEALER" and c.heal then return "Utilise " .. spell.name .. " sur la cible qui en a vraiment besoin ; garde ton mana sous controle." end
    if role == "TANK" and c.mitigation then return "Active " .. spell.name .. " pour le prochain gros coup, pas simplement des qu'il s'allume." end
    if c.dot then return "Pose " .. spell.name .. " assez tot pour qu'il dure, puis ne le renouvelle pas trop vite." end
    if c.summon then return "Installe " .. spell.name .. " pour cette phase et laisse l'invocation travailler avant de la remplacer." end
    if c.buff then return "Place " .. spell.name .. " dans ta preparation ou ta fenetre forte, puis enchaine." end
    if context == "AOE" and c.aoe then return "Sur le pack regroupe, " .. Lower(position == 1 and "commence avec " or "enchaîne avec ") .. spell.name .. "." end
    if c.direct then
        if position == 1 then return "Commence avec " .. spell.name .. " si la cible est valide et a portee." end
        return "Enchaine avec " .. spell.name .. " des qu'il est disponible, puis poursuis la priorite."
    end
    if entry.curated then return "Utilise " .. spell.name .. " a cette etape ; s'il est indisponible, passe proprement a la suite." end
    return "Integre " .. spell.name .. " ici si son effet correspond bien a la situation presente."
end

local function BuildPreparation(curated)
    if not curated or not curated.maintenance or not CoARotationGuideDB.showPreparation then return {} end
    local available = {}
    local _, name
    for _, name in ipairs(curated.maintenance) do
        if spellbook[Lower(name)] then table.insert(available, name) end
        if #available >= 3 then break end
    end
    return available
end

local function BuildGuide()
    EnsureDatabase()
    currentCharacter = ResolveActiveSpecialization()
    currentCharacter.level = UnitLevel("player") or 0
    local profile, profileKey = ResolveProfile(currentCharacter.className, currentCharacter.specName)
    currentCharacter.profileKey = profileKey
    if profile then currentCharacter.role = profile.role end
    local curated = DATA.curated and DATA.curated[profileKey] or nil
    local candidates = {}
    local added = {}
    local context = CoARotationGuideDB.context
    local content = CoARotationGuideDB.content
    local sourcedCount = 0
    local talentRules = 0

    local function AddCandidate(spell, curatedRank)
        if not spell or spell.passive or added[Lower(spell.name)] then return end
        local useful = false
        local _, value
        for _, value in pairs(spell.categories) do if value then useful = true break end end
        if not useful and not curatedRank then return end
        local promotion, talentName = TalentPromotion(curated, spell.name)
        local score = BaseScore(spell, currentCharacter.role, context, content)
            + FocusBonus(profile, spell) + promotion
        if curatedRank then
            score = score + 1800 - curatedRank * 35
            sourcedCount = sourcedCount + 1
        end
        if talentName then talentRules = talentRules + 1 end
        added[Lower(spell.name)] = true
        table.insert(candidates, {
            spell = spell,
            score = score,
            curated = curatedRank and true or false,
            curatedRank = curatedRank,
            talentName = talentName
        })
    end

    if curated then
        local sequence = context == "AOE" and curated.aoe or curated.st
        local rank, name
        for rank, name in ipairs(sequence or {}) do AddCandidate(spellbook[Lower(name)], rank) end
    end
    local _, spell
    for _, spell in ipairs(spellOrder) do AddCandidate(spell, nil) end

    table.sort(candidates, function(a, b)
        if a.score == b.score then return a.spell.name < b.spell.name end
        return a.score > b.score
    end)

    local selected = {}
    local index
    for index = 1, math.min(6, #candidates) do
        local entry = candidates[index]
        entry.instruction = InstructionFor(entry, index, currentCharacter.role, context)
        table.insert(selected, entry)
    end

    local stage
    if currentCharacter.level < 10 then
        stage = "Avant le niveau 10 : on reste simple et on n'affiche que les capacites deja apprises."
    elseif currentCharacter.level < 30 then
        stage = "Progression : la rotation grandit avec ton spellbook ; aucun sort futur n'est invente."
    else
        stage = "Kit principal disponible : la priorite est filtree par tes talents et tes sorts actuels."
    end

    currentGuide = {
        profile = profile,
        profileKey = profileKey,
        curated = curated,
        entries = selected,
        preparation = BuildPreparation(curated),
        sourcedCount = sourcedCount,
        talentRules = talentRules,
        stage = stage,
        spellCount = #spellOrder,
        talentCount = #activeTalentList
    }
    return currentGuide
end

local function RoleLabel(role)
    if role == "HEALER" then return "SOIGNEUR" end
    if role == "TANK" then return "TANK" end
    if role == "SUPPORT" then return "SOUTIEN" end
    return "DEGATS"
end

local function SetRow(row, icon, title, body, badge, badgeColor)
    row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.title:SetText(title or "")
    row.body:SetText(body or "")
    row.badge:SetText(badge or "")
    local color = badgeColor or { 0.45, 0.82, 1 }
    row.badge:SetTextColor(color[1], color[2], color[3])
    row:Show()
end

local function HideRows()
    local _, row
    for _, row in ipairs(rows) do row:Hide() end
end

local function RefreshButtons()
    if not buttons.st then return end
    buttons.st:SetText(CoARotationGuideDB.context == "ST" and "ST : ACTIF" or "ST")
    buttons.aoe:SetText(CoARotationGuideDB.context == "AOE" and "AOE : ACTIF" or "AOE")
    buttons.solo:SetText(CoARotationGuideDB.content == "SOLO" and "SOLO : ACTIF" or "SOLO")
    buttons.group:SetText(CoARotationGuideDB.content == "GROUP" and "GROUPE : ACTIF" or "GROUPE")
    buttons.sources:SetText(viewMode == "SOURCES" and "RETOUR GUIDE" or "METHODE")
end

local function RefreshDisplay()
    if not guideFrame then return end
    EnsureDatabase()
    local guide = BuildGuide()
    guideFrame.character:SetText(currentCharacter.className .. "  •  " .. currentCharacter.specName .. "  •  niveau " .. tostring(currentCharacter.level) .. "  •  " .. RoleLabel(currentCharacter.role))
    guideFrame.stage:SetText(guide.stage)
    RefreshButtons()
    HideRows()

    if viewMode == "SOURCES" then
        guideFrame.preparation:SetText("Methode : le spellbook du personnage reste la source de verite ; les guides ne servent qu'a ordonner ce qui est vraiment appris.")
        local index, source
        for index, source in ipairs(DATA.sources or {}) do
            if rows[index] then
                local body = source.url == "local://player" and "Lecture directe en jeu, sans connexion reseau." or source.url
                SetRow(rows[index], "Interface\\Icons\\INV_Misc_Book_09", source.name, body, source.kind, { 0.80, 0.65, 0.25 })
            end
        end
        if rows[5] then
            SetRow(rows[5], "Interface\\Icons\\INV_Misc_Note_06", "Regle de prudence", "Si un guide est ancien ou incomplet, l'addon passe en classement adaptatif et le signale. Il ne transforme jamais une approximation en certitude.", "GARDE-FOU", { 1, 0.55, 0.25 })
        end
        if rows[6] and guide.curated and guide.curated.source then
            local exactSources = guide.curated.source
            if guide.curated.secondarySource then exactSources = exactSources .. "  |  " .. guide.curated.secondarySource end
            SetRow(rows[6], "Interface\\Icons\\INV_Misc_Map_01", "Guide exact du profil actif", exactSources, guide.curated.quality or "SOURCE", { 0.35, 1, 0.45 })
        end
        guideFrame.source:SetText("Banque hors ligne : " .. tostring(DATA.sourceDate or "?") .. "  •  patch talents : " .. tostring(DATA.talentPatch or "?"))
        return
    end

    local prep = "Preparation separee : aucune maintenance necessaire detectee."
    if #guide.preparation > 0 then prep = "Avant le combat : " .. table.concat(guide.preparation, "  ->  ") end
    guideFrame.preparation:SetText(prep)

    local index, entry
    for index, entry in ipairs(guide.entries) do
        local badge = entry.curated and "SOURCE" or "ADAPTATIF"
        local color = entry.curated and { 0.35, 1, 0.45 } or { 0.40, 0.78, 1 }
        if entry.talentName then badge = "TALENT : " .. string.upper(entry.talentName) end
        SetRow(rows[index], entry.spell.icon, tostring(index) .. ".  " .. entry.spell.name, entry.instruction, badge, color)
    end
    if #guide.entries == 0 and rows[1] then
        SetRow(rows[1], nil, "Aucune suggestion fiable", "Ouvre ton spellbook, apprends au moins une capacite active, puis clique sur ACTUALISER.", "PRUDENT", { 1, 0.55, 0.25 })
    end

    local quality = guide.curated and guide.curated.quality or "Classement adaptatif prudent"
    guideFrame.source:SetText(quality .. "  •  " .. tostring(guide.spellCount) .. " sorts  •  " .. tostring(guide.talentCount) .. " talents  •  " .. tostring(guide.talentRules) .. " priorite(s) talent")
end

local function FullScan(silent)
    ScanTalents()
    ScanSpellbook()
    RefreshDisplay()
    if not silent then
        Chat(tostring(#spellOrder) .. " sorts et " .. tostring(#activeTalentList) .. " talents lus pour " .. tostring(currentCharacter.className) .. " - " .. tostring(currentCharacter.specName) .. ".")
    end
end

local function ScheduleScan(delay)
    scheduledScanAt = (GetTime and GetTime() or 0) + (tonumber(delay) or 0.4)
end

local function ToggleGuide()
    if not guideFrame then return end
    if guideFrame:IsShown() then
        SavePosition()
        guideFrame:Hide()
    else
        viewMode = "GUIDE"
        FullScan(true)
        guideFrame:Show()
    end
end

local function PositionMinimapButton()
    if not minimapButton then return end
    EnsureDatabase()
    minimapButton:ClearAllPoints()
    local angle = CoARotationGuideDB.minimap.angle or 2.65
    local radius = 82
    if Minimap then
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    else
        minimapButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -190, -32)
    end
end

local function UpdateMinimapVisibility()
    if not minimapButton then return end
    EnsureDatabase()
    if hubManaged or CoARotationGuideDB.minimap.hidden then minimapButton:Hide() else minimapButton:Show() end
end

local function BuildMinimapButton()
    if minimapButton then return end
    minimapButton = CreateFrame("Button", "CoARotationGuideMinimapButton", UIParent)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -6)
    icon:SetPoint("BOTTOMRIGHT", minimapButton, "BOTTOMRIGHT", -7, 6)
    minimapButton.icon = icon
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("CENTER", minimapButton, "CENTER", 10, -10)
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    highlight:SetPoint("BOTTOMRIGHT", minimapButton, "BOTTOMRIGHT", 0, 0)

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            CoARotationGuideDB.minimap.hidden = true
            UpdateMinimapVisibility()
            Chat("Bouton masque. /rotation minimap pour le reafficher.")
        else
            ToggleGuide()
        end
    end)
    minimapButton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", function()
        if not Minimap then return end
        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cursorX, cursorY = cursorX / scale, cursorY / scale
        local minimapX, minimapY = Minimap:GetCenter()
        if minimapX and minimapY then
            CoARotationGuideDB.minimap.angle = AngleFromDelta(cursorX - minimapX, cursorY - minimapY)
            PositionMinimapButton()
        end
    end) end)
    minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("CoA Rotation Guide", 1, 0.82, 0)
        GameTooltip:AddLine("Clic : ouvrir le guide", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : masquer ce bouton", 0.75, 0.85, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PositionMinimapButton()
    UpdateMinimapVisibility()
end

local function MakeButton(name, text, width, x)
    local button = CreateFrame("Button", name, guideFrame, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(23)
    button:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", x, -88)
    button:SetText(text)
    return button
end

local function BuildInterface()
    scannerTooltip = CreateFrame("GameTooltip", "CoARotationGuideScannerTooltip", UIParent, "GameTooltipTemplate")
    scannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scannerTooltip:Hide()

    guideFrame = CreateFrame("Frame", "CoARotationGuideFrame", UIParent)
    guideFrame:SetWidth(650)
    guideFrame:SetHeight(555)
    guideFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    guideFrame:SetFrameStrata("DIALOG")
    guideFrame:SetMovable(true)
    guideFrame:EnableMouse(true)
    guideFrame:RegisterForDrag("LeftButton")
    guideFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    guideFrame:SetBackdropColor(0.025, 0.035, 0.06, 0.98)
    guideFrame:SetBackdropBorderColor(0.75, 0.55, 0.22, 0.95)
    guideFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    guideFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    guideFrame:Hide()

    local close = CreateFrame("Button", nil, guideFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", guideFrame, "TOPRIGHT", -4, -4)

    local title = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -15)
    title:SetText("CoA • Guide de Rotation")
    title:SetTextColor(1, 0.82, 0.16)

    guideFrame.character = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    guideFrame.character:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -43)
    guideFrame.character:SetWidth(610)
    guideFrame.character:SetJustifyH("LEFT")

    guideFrame.stage = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    guideFrame.stage:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -64)
    guideFrame.stage:SetWidth(610)
    guideFrame.stage:SetJustifyH("LEFT")

    buttons.solo = MakeButton(nil, "SOLO", 78, 18)
    buttons.group = MakeButton(nil, "GROUPE", 82, 100)
    buttons.st = MakeButton(nil, "ST", 68, 186)
    buttons.aoe = MakeButton(nil, "AOE", 72, 258)
    buttons.refresh = MakeButton(nil, "ACTUALISER", 102, 334)
    buttons.sources = MakeButton(nil, "METHODE", 112, 440)

    buttons.solo:SetScript("OnClick", function() CoARotationGuideDB.content = "SOLO"; viewMode = "GUIDE"; RefreshDisplay() end)
    buttons.group:SetScript("OnClick", function() CoARotationGuideDB.content = "GROUP"; viewMode = "GUIDE"; RefreshDisplay() end)
    buttons.st:SetScript("OnClick", function() CoARotationGuideDB.context = "ST"; viewMode = "GUIDE"; RefreshDisplay() end)
    buttons.aoe:SetScript("OnClick", function() CoARotationGuideDB.context = "AOE"; viewMode = "GUIDE"; RefreshDisplay() end)
    buttons.refresh:SetScript("OnClick", function() viewMode = "GUIDE"; FullScan(false) end)
    buttons.sources:SetScript("OnClick", function() viewMode = viewMode == "SOURCES" and "GUIDE" or "SOURCES"; RefreshDisplay() end)

    local prepBox = CreateFrame("Frame", nil, guideFrame)
    prepBox:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -122)
    prepBox:SetWidth(614)
    prepBox:SetHeight(34)
    prepBox:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
    prepBox:SetBackdropColor(0.10, 0.075, 0.025, 0.80)
    prepBox:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.9)
    guideFrame.preparation = prepBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guideFrame.preparation:SetPoint("LEFT", prepBox, "LEFT", 10, 0)
    guideFrame.preparation:SetWidth(594)
    guideFrame.preparation:SetJustifyH("LEFT")

    local rowIndex
    for rowIndex = 1, 6 do
        local row = CreateFrame("Frame", nil, guideFrame)
        row:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -164 - (rowIndex - 1) * 57)
        row:SetWidth(614)
        row:SetHeight(51)
        row:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
        row:SetBackdropColor(rowIndex % 2 == 0 and 0.035 or 0.045, 0.065, 0.095, 0.82)
        row:SetBackdropBorderColor(0.20, 0.36, 0.52, 0.75)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(38)
        row.icon:SetHeight(38)
        row.icon:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 53, -7)
        row.title:SetWidth(350)
        row.title:SetJustifyH("LEFT")
        row.body = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.body:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.body:SetWidth(548)
        row.body:SetJustifyH("LEFT")
        row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
        row.badge:SetWidth(195)
        row.badge:SetJustifyH("RIGHT")
        row:Hide()
        table.insert(rows, row)
    end

    guideFrame.source = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    guideFrame.source:SetPoint("BOTTOMLEFT", guideFrame, "BOTTOMLEFT", 18, 14)
    guideFrame.source:SetWidth(614)
    guideFrame.source:SetJustifyH("LEFT")

    if UISpecialFrames then table.insert(UISpecialFrames, "CoARotationGuideFrame") end
    RestorePosition()
end

local function PrintStatus()
    BuildGuide()
    Chat(tostring(currentCharacter.className) .. " - " .. tostring(currentCharacter.specName)
        .. ", niveau " .. tostring(currentCharacter.level)
        .. ", " .. tostring(#spellOrder) .. " sorts, " .. tostring(#activeTalentList) .. " talents.")
    Chat("Contexte " .. tostring(CoARotationGuideDB.content) .. "/" .. tostring(CoARotationGuideDB.context)
        .. " ; profil " .. tostring(currentGuide and currentGuide.profileKey or "inconnu") .. ".")
end

local function SlashHandler(message)
    EnsureDatabase()
    local command = Lower(Trim(message))
    if command == "" or command == "show" or command == "open" then
        ToggleGuide()
    elseif command == "scan" or command == "refresh" then
        FullScan(false)
    elseif command == "st" then
        CoARotationGuideDB.context = "ST"; viewMode = "GUIDE"; RefreshDisplay(); guideFrame:Show()
    elseif command == "aoe" then
        CoARotationGuideDB.context = "AOE"; viewMode = "GUIDE"; RefreshDisplay(); guideFrame:Show()
    elseif command == "solo" then
        CoARotationGuideDB.content = "SOLO"; viewMode = "GUIDE"; RefreshDisplay(); guideFrame:Show()
    elseif command == "group" or command == "groupe" then
        CoARotationGuideDB.content = "GROUP"; viewMode = "GUIDE"; RefreshDisplay(); guideFrame:Show()
    elseif command == "sources" or command == "method" or command == "methode" then
        viewMode = "SOURCES"; RefreshDisplay(); guideFrame:Show()
    elseif command == "status" then
        PrintStatus()
    elseif command == "minimap" then
        CoARotationGuideDB.minimap.hidden = false; hubManaged = false; PositionMinimapButton(); UpdateMinimapVisibility()
    elseif command == "reset" then
        CoARotationGuideDB.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
        CoARotationGuideDB.minimap.angle = 2.65
        RestorePosition(); PositionMinimapButton(); Chat("Positions reinitialisees.")
    else
        Chat("/rotation | scan | status | st | aoe | solo | groupe | sources | minimap | reset")
    end
end

CoARotationGuideAPI = CoARotationGuideAPI or {}
function CoARotationGuideAPI:Toggle() ToggleGuide() end
function CoARotationGuideAPI:Show()
    if guideFrame and not guideFrame:IsShown() then FullScan(true); guideFrame:Show() end
end
function CoARotationGuideAPI:SetHubManaged(value)
    hubManaged = value and true or false
    UpdateMinimapVisibility()
end
function CoARotationGuideAPI:Refresh() FullScan(true) end

SLASH_COAROTATIONGUIDE1 = "/rotation"
SLASH_COAROTATIONGUIDE2 = "/crg"
SlashCmdList.COAROTATIONGUIDE = SlashHandler

BuildInterface()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        EnsureDatabase()
        RestorePosition()
        BuildMinimapButton()
        ScheduleScan(0.6)
    elseif event == "ADDON_LOADED" then
        if CoAUIManagerPanel then hubManaged = true; UpdateMinimapVisibility() end
    elseif event == "PLAYER_LOGIN" then
        if CoAUIManagerPanel then hubManaged = true end
        PositionMinimapButton()
        UpdateMinimapVisibility()
        ScheduleScan(0.8)
    else
        ScheduleScan(0.35)
    end
end)
eventFrame:SetScript("OnUpdate", function()
    if scheduledScanAt and GetTime() >= scheduledScanAt then
        scheduledScanAt = nil
        FullScan(true)
    end
end)
