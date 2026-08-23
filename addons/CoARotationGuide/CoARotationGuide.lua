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
local viewMode = "LEARN"
local guidePage = 1
local PAGE_SIZE = 5
local MAX_ENTRIES = 15
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

local function NameInList(list, spellName)
    local _, name
    for _, name in ipairs(list or {}) do
        if Lower(name) == Lower(spellName) then return true end
    end
    return false
end

local function InstructionFor(entry, position, role, context)
    local spell = entry.spell
    local c = spell.categories
    if c.execute then return "A faire : garde " .. spell.name .. " pour une cible vraiment affaiblie." end
    if c.builder and not c.spender then return "A faire : utilise " .. spell.name .. " pour remonter ta ressource sans la faire deborder." end
    if c.spender then return "A faire : depense avec " .. spell.name .. " seulement quand la ressource est prete." end
    if role == "HEALER" and c.absorb then return "A faire : pose " .. spell.name .. " juste avant les degats previsibles." end
    if role == "HEALER" and c.hot then return "A faire : entretiens " .. spell.name .. " sur la cible qui va continuer a prendre des degats." end
    if role == "HEALER" and c.heal then return "A faire : lance " .. spell.name .. " sur la cible qui en a besoin, pas juste parce qu'il est disponible." end
    if role == "TANK" and c.mitigation then return "A faire : garde " .. spell.name .. " pour le prochain vrai choc." end
    if c.dot then return "A faire : pose " .. spell.name .. " assez tot et laisse-le aller au bout." end
    if c.summon then return "A faire : installe " .. spell.name .. " assez tot pour qu'il travaille vraiment." end
    if c.buff then return "A faire : active " .. spell.name .. " avant les sorts qui doivent profiter de sa fenetre." end
    if context == "AOE" and c.aoe then return "A faire : lance " .. spell.name .. " quand le pack est bien regroupe." end
    if c.direct then
        if position == 1 then return "A faire : commence par " .. spell.name .. " si la cible est valide et a portee." end
        return "A faire : prends " .. spell.name .. " des que les etapes au-dessus ne sont pas disponibles."
    end
    if entry.curated then return "A faire : utilise " .. spell.name .. " ici ; s'il n'est pas disponible, passe a la suite." end
    return "A faire : utilise " .. spell.name .. " quand son effet correspond a la situation."
end

local function CuratedExplanation(curated, context, spellName)
    if not curated or not curated.explanations then return nil end
    local contextExplanations = curated.explanations[Lower(context)]
    return contextExplanations and contextExplanations[spellName] or nil
end

local function GenericWhy(entry, previousEntry, nextEntry, role, context)
    local spell = entry.spell
    local c = spell.categories
    if entry.talentName then
        return "Ton talent " .. entry.talentName .. " renforce directement ce choix, donc il remonte dans la priorite."
    end
    if c.execute then return "Sa valeur depend d'une cible basse en vie ; avant ca, un sort regulier fait mieux le travail." end
    if c.builder and not c.spender then
        if nextEntry and nextEntry.spell.categories.spender then
            return "Il fabrique la ressource que " .. nextEntry.spell.name .. " depensera juste apres."
        end
        return "Il remet du carburant dans le cycle ; l'utiliser barre pleine serait du gaspillage."
    end
    if c.spender then
        if previousEntry and previousEntry.spell.categories.builder then
            return previousEntry.spell.name .. " a prepare la ressource ; c'est maintenant le bon moment de la convertir en effet utile."
        end
        return "C'est une depense, donc elle vient apres la preparation de la ressource et non au debut a vide."
    end
    if c.dot then return "Le poser tot lui laisse assez de temps pour faire tous ses ticks ; le rafraichir trop vite jette une partie de sa valeur." end
    if c.debuff then return "Il prepare ou affaiblit la cible, ce qui donne plus de sens aux attaques placees derriere." end
    if c.buff then return "Le bonus doit etre actif avant tes gros sorts. Le lancer apres eux reviendrait a rater ta propre fenetre."
    end
    if c.summon then return "Une invocation posee tot continue d'agir pendant que tu utilises les autres sorts : autant la faire travailler tout de suite." end
    if role == "HEALER" and c.absorb then return "Un bouclier evite les degats ; apres le choc, il arrive forcement trop tard pour cette partie."
    end
    if role == "HEALER" and c.hot then return "Le soin agit dans le temps, donc il vaut mieux l'installer avant que la cible tombe trop bas."
    end
    if role == "HEALER" and c.heal then return "Il sert a repondre a un vrai manque de vie ; sans blessure, garde plutot ton mana."
    end
    if role == "TANK" and c.mitigation then return "La mitigation gagne sa valeur sur un coup dangereux. La lancer sans menace reelle gaspille sa duree."
    end
    if context == "AOE" and c.aoe then return "Plusieurs ennemis sont concernes, donc son rendement depasse celui d'une attaque purement monocible."
    end
    if c.direct then return "C'est un bouton de pression immediate : il remplit le trou quand les effets plus importants au-dessus ne sont pas disponibles."
    end
    return "Son tooltip correspond au role et au contexte choisis, mais l'addon le garde en choix adaptatif prudent."
end

local function GenericAfter(entry, nextEntry)
    if not nextEntry then return "Puis repars tout en haut : la liste est une priorite, pas une macro figee." end
    local current = entry.spell.categories
    local nextCategories = nextEntry.spell.categories
    local nextName = nextEntry.spell.name
    if current.builder and nextCategories.spender then return "Puis passe a " .. nextName .. " quand la ressource suffit." end
    if (current.dot or current.debuff) and (nextCategories.direct or nextCategories.spender) then return "Puis enchaine avec " .. nextName .. " pendant que la cible est preparee." end
    if current.buff then return "Puis lance " .. nextName .. " avant que la fenetre ne tombe." end
    if current.summon then return "Puis passe a " .. nextName .. " pendant que l'invocation travaille en parallele." end
    if current.execute then return "Si la condition d'execution n'est pas remplie, saute cette ligne et prends " .. nextName .. "." end
    return "Puis regarde " .. nextName .. " ; s'il n'est pas disponible, continue simplement vers le bas."
end

local function ExplainEntry(entry, previousEntry, nextEntry, curated, context)
    local exact = CuratedExplanation(curated, context, entry.spell.name)
    local why = exact and exact.why or GenericWhy(entry, previousEntry, nextEntry, currentCharacter.role, context)
    local after = exact and exact.after or GenericAfter(entry, nextEntry)
    entry.explanation = "Pourquoi ici ? " .. why .. "  " .. after
    entry.explanationKind = exact and "EXPLIQUE" or "DEDUIT DU TOOLTIP"
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
        if curated and NameInList(curated.situational, spell.name) then return end
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
        if a.curated and b.curated and a.curatedRank ~= b.curatedRank then return a.curatedRank < b.curatedRank end
        if a.curated ~= b.curated then return a.curated end
        if a.score == b.score then return a.spell.name < b.spell.name end
        return a.score > b.score
    end)

    local selected = {}
    local index
    for index = 1, math.min(MAX_ENTRIES, #candidates) do
        local entry = candidates[index]
        entry.instruction = InstructionFor(entry, index, currentCharacter.role, context)
        table.insert(selected, entry)
    end
    for index = 1, #selected do
        ExplainEntry(selected[index], selected[index - 1], selected[index + 1], curated, context)
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
        plan = profile and profile.style or "Lis la priorite de haut en bas et utilise seulement les sorts adaptes a la situation.",
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

local function RoleColor(role)
    if role == "HEALER" then return { 0.25, 0.88, 0.62 } end
    if role == "TANK" then return { 0.32, 0.62, 1.00 } end
    if role == "SUPPORT" then return { 0.72, 0.48, 1.00 } end
    return { 1.00, 0.70, 0.22 }
end

local function LevelChapter(level)
    if level < 10 then
        return { title = "Les fondations", text = "Pour l'instant, fais simple : une action principale, une reponse defensive et aucune ressource gaspillee.", exercise = "Apprends a reconnaitre ton premier bouton fiable et a rester bien place. La specialisation complete viendra ensuite." }
    elseif level < 20 then
        return { title = "Tu decouvres la specialisation", text = "Ton objectif n'est pas de memoriser quinze sorts. Comprends d'abord l'ouverture et la ressource principale.", exercise = "Travaille seulement les trois premieres priorites apprises jusqu'a pouvoir les expliquer sans regarder la liste." }
    elseif level < 30 then
        return { title = "Ton kit prend forme", text = "Ajoute maintenant les effets a entretenir et la premiere vraie boucle generateur vers depensier.", exercise = "Sur quelques combats, surveille surtout ta ressource : ni vide au mauvais moment, ni bloquee au maximum." }
    elseif level < 40 then
        return { title = "La boucle complete arrive", text = "Entre les niveaux 30 et 39, ton jeu devient coherent : preparation, ouverture, boucle, puis adaptation ST ou AOE.", exercise = "Repete une ouverture propre, puis reviens en haut de la priorite apres chaque depense. C'est le bon moment pour prendre de bonnes habitudes." }
    elseif level < 50 then
        return { title = "Tu consolides", text = "Le coeur du gameplay est la. Tu dois maintenant aligner tes cooldowns et savoir quand interrompre la boucle pour aider le groupe.", exercise = "Cherche la regularite : meme ressource bien geree, memes effets maintenus, moins de boutons presses par reflexe." }
    end
    return { title = "Tu optimises", text = "Ton kit est avance. La difference se fait sur le timing, la duree de vie des cibles et l'alignement des vraies fenetres fortes.", exercise = "Compare ST et AOE, apprends les exceptions du combat et garde tes gros cooldowns pour une fenetre qui durera assez longtemps." }
end

local function EntryByCategory(guide, category)
    local _, entry
    for _, entry in ipairs(guide.entries or {}) do
        if entry.spell.categories[category] then return entry end
    end
    return nil
end

local function EntryNames(guide, first, count)
    local names = {}
    local index
    for index = first or 1, math.min(#guide.entries, (first or 1) + (count or 3) - 1) do
        table.insert(names, guide.entries[index].spell.name)
    end
    return #names > 0 and table.concat(names, "  ->  ") or "Aucun enchainement fiable detecte pour le moment"
end

local function SituationalNames(curated)
    local names = {}
    local _, name
    for _, name in ipairs(curated and curated.situational or {}) do
        if spellbook[Lower(name)] then table.insert(names, name) end
    end
    return names
end

local function GenericTeaching(guide)
    local builder = EntryByCategory(guide, "builder")
    local spender = EntryByCategory(guide, "spender")
    local role = currentCharacter.role
    local resource
    if builder and spender then
        resource = builder.spell.name .. " construit ta ressource ; " .. spender.spell.name .. " la depense. Le jeu consiste surtout a passer de l'un a l'autre sans gaspiller."
    elseif role == "HEALER" then
        resource = "Ton mana appartient au combat entier. Un soin sans degats a reparer est une depense inutile ; anticipe, puis reagis."
    elseif role == "TANK" then
        resource = "Ta vraie ressource, c'est aussi le temps : garde la mitigation pour le choc qui compte et maintiens les ennemis sous controle entre deux dangers."
    else
        resource = "Utilise les outils du haut pour preparer la cible, puis tes impacts directs pour convertir cette preparation en degats."
    end
    local golden
    if role == "HEALER" then golden = "Soigne une situation, pas un ordre de boutons : protections avant le choc, soins directs apres une vraie perte de vie."
    elseif role == "TANK" then golden = "Survis d'abord, stabilise le pack ensuite, puis cherche les degats. Un tank mort ne termine aucune rotation."
    elseif role == "SUPPORT" then golden = "Place l'utilitaire avant la fenetre du groupe, puis continue ta pression sans sacrifier la prochaine aide importante."
    else golden = "La premiere ligne disponible gagne. Si sa condition n'est pas remplie, descends ; ne reste jamais bloque a attendre un seul bouton."
    end
    return {
        identity = guide.profile and guide.profile.style or "Ton spellbook determine ce que tu peux vraiment jouer aujourd'hui.",
        resource = resource,
        goldenRule = golden,
        mistake = "Reciter la liste comme une macro. La cible, la ressource et les cooldowns ont toujours le dernier mot."
    }
end

local function TeachingFor(guide)
    return guide.curated and guide.curated.teaching or GenericTeaching(guide)
end

local function SetRow(row, icon, title, body, explanation, badge, badgeColor, spell)
    row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.title:SetText(title or "")
    row.body:SetText(body or "")
    row.why:SetText(explanation or "")
    row.badge:SetText(badge or "")
    row.spell = spell
    local color = badgeColor or { 0.45, 0.82, 1 }
    row.badge:SetTextColor(color[1], color[2], color[3])
    row.title:SetTextColor(color[1], color[2], color[3])
    if row.accent then row.accent:SetVertexColor(color[1], color[2], color[3], 0.95) end
    row:Show()
end

local function HideRows()
    local _, row
    for _, row in ipairs(rows) do row.spell = nil; row:Hide() end
end

local function RefreshButtons()
    if not buttons.st then return end
    buttons.st:SetText(CoARotationGuideDB.context == "ST" and "ST : ACTIF" or "ST")
    buttons.aoe:SetText(CoARotationGuideDB.context == "AOE" and "AOE : ACTIF" or "AOE")
    buttons.solo:SetText(CoARotationGuideDB.content == "SOLO" and "SOLO : ACTIF" or "SOLO")
    buttons.group:SetText(CoARotationGuideDB.content == "GROUP" and "GROUPE : ACTIF" or "GROUPE")
    buttons.learn:SetText(viewMode == "LEARN" and "• COMPRENDRE •" or "COMPRENDRE")
    buttons.rotation:SetText(viewMode == "ROTATION" and "• ROTATION •" or "ROTATION")
    buttons.situations:SetText(viewMode == "SITUATIONS" and "• SITUATIONS •" or "SITUATIONS")
    buttons.sources:SetText(viewMode == "SOURCES" and "• SOURCES •" or "SOURCES")
end

local function RefreshPagination(guide)
    if not buttons.previous or not buttons.next or not guideFrame.page then return end
    if viewMode ~= "ROTATION" then
        buttons.previous:Hide()
        buttons.next:Hide()
        guideFrame.page:Hide()
        return
    end
    buttons.previous:Show()
    buttons.next:Show()
    guideFrame.page:Show()
    local totalPages = math.max(1, math.ceil(#guide.entries / PAGE_SIZE))
    guidePage = Clamp(guidePage, 1, totalPages)
    if #guide.entries == 0 then
        guideFrame.page:SetText("Aucune etape fiable")
    else
        guideFrame.page:SetText("Etapes " .. tostring((guidePage - 1) * PAGE_SIZE + 1) .. "-" .. tostring(math.min(guidePage * PAGE_SIZE, #guide.entries)) .. " / " .. tostring(#guide.entries))
    end
    if guidePage <= 1 then buttons.previous:Disable() else buttons.previous:Enable() end
    if guidePage >= totalPages then buttons.next:Disable() else buttons.next:Enable() end
end

local function RefreshDisplay()
    if not guideFrame then return end
    EnsureDatabase()
    local guide = BuildGuide()
    local roleColor = RoleColor(currentCharacter.role)
    local chapter = LevelChapter(currentCharacter.level)
    local teaching = TeachingFor(guide)
    local preparation = #guide.preparation > 0 and table.concat(guide.preparation, "  ->  ") or "Rien de particulier avec les sorts actuellement appris"
    guideFrame.character:SetText(currentCharacter.className .. "  •  " .. currentCharacter.specName .. "  •  niveau " .. tostring(currentCharacter.level) .. "  •  " .. RoleLabel(currentCharacter.role))
    guideFrame.stage:SetText(chapter.title .. "  •  " .. guide.stage)
    if guideFrame.planBox then guideFrame.planBox:SetBackdropBorderColor(roleColor[1], roleColor[2], roleColor[3], 0.95) end
    RefreshButtons()
    HideRows()

    if viewMode == "SOURCES" then
        guideFrame.plan:SetText("D'ou viennent les conseils ?\nJe recoupe les guides, le changelog officiel et surtout ton vrai spellbook. Une approximation reste toujours etiquetee comme telle.")
        guideFrame.preparation:SetText("Methode : le spellbook du personnage reste la source de verite ; les guides ne servent qu'a ordonner ce qui est vraiment appris.")
        local index, source
        for index, source in ipairs(DATA.sources or {}) do
            if rows[index] then
                local body = source.url == "local://player" and "Lecture directe en jeu, sans connexion reseau." or source.url
                SetRow(rows[index], "Interface\\Icons\\INV_Misc_Book_09", source.name, body, "Pourquoi cette source ? Elle permet de recouper les conseils sans remplacer ce que ton personnage connait vraiment.", source.kind, { 0.80, 0.65, 0.25 })
            end
        end
        if rows[5] and guide.curated and guide.curated.source then
            local exactSources = guide.curated.source
            if guide.curated.secondarySource then exactSources = exactSources .. "  |  " .. guide.curated.secondarySource end
            SetRow(rows[5], "Interface\\Icons\\INV_Misc_Map_01", "Guide exact du profil actif", exactSources, "Cette priorite est expliquee et filtree par ton niveau, tes talents et les sorts reellement appris.", guide.curated.quality or "SOURCE", { 0.35, 1, 0.45 })
        elseif rows[5] then
            SetRow(rows[5], "Interface\\Icons\\INV_Misc_Note_06", "Regle de prudence", "Aucun guide exact assez fiable n'est embarque pour ce profil.", "L'addon explique alors une priorite deduite des tooltips et l'etiquette clairement comme adaptative.", "GARDE-FOU", { 1, 0.55, 0.25 })
        end
        guideFrame.source:SetText("Banque hors ligne : " .. tostring(DATA.sourceDate or "?") .. "  •  talents : " .. tostring(DATA.talentPatch or "?") .. "  •  changelog officiel lu jusqu'au : " .. tostring(DATA.officialPatchThrough or "?"))
        RefreshPagination(guide)
        return
    end

    if viewMode == "LEARN" then
        guideFrame.plan:SetText("Bienvenue dans ta specialisation.\nIci, on commence par comprendre le plan de jeu ; la liste de boutons vient seulement apres.")
        guideFrame.preparation:SetText("Ton cap actuel : " .. chapter.title .. ". Avance bloc par bloc, sans essayer de tout retenir en une fois.")
        SetRow(rows[1], "Interface\\Icons\\INV_Misc_Book_09", "1. Ta specialisation, en une phrase", teaching.identity,
            "En clair : " .. tostring(guide.plan), "TON IDENTITE", roleColor)
        SetRow(rows[2], "Interface\\Icons\\INV_Misc_Rune_06", "2. Le moteur de ton gameplay", teaching.resource,
            "C'est ce mecanisme que tu dois regarder pendant le combat, bien avant de chercher a reciter tous les sorts.", "RESSOURCE / RYTHME", { 0.35, 0.78, 1.00 })
        SetRow(rows[3], guide.entries[1] and guide.entries[1].spell.icon, "3. Ta boucle avec les sorts appris", EntryNames(guide, 1, 4),
            "Commence par comprendre ce petit chemin. Si un sort n'est pas disponible, descends dans la priorite puis repars au debut.", "TA BOUCLE ACTUELLE", { 1.00, 0.72, 0.22 }, guide.entries[1] and guide.entries[1].spell)
        SetRow(rows[4], "Interface\\Icons\\INV_Misc_Map_01", "4. Ton objectif au niveau " .. tostring(currentCharacter.level), chapter.text,
            "Petit exercice : " .. chapter.exercise, "PROGRESSION", { 0.48, 0.90, 0.55 })
        SetRow(rows[5], "Interface\\Icons\\INV_Misc_Note_06", "5. La regle d'or", teaching.goldenRule,
            "Le piege classique : " .. teaching.mistake, "A RETENIR", { 1.00, 0.48, 0.30 })
        guideFrame.source:SetText("Parcours personnalise • " .. tostring(guide.spellCount) .. " sorts appris • " .. tostring(guide.talentCount) .. " talents actifs • passe ensuite dans ROTATION")
        RefreshPagination(guide)
        return
    end

    if viewMode == "SITUATIONS" then
        local builder = EntryByCategory(guide, "builder")
        local spender = EntryByCategory(guide, "spender")
        local aoe = EntryByCategory(guide, "aoe")
        local execute = EntryByCategory(guide, "execute")
        local situational = SituationalNames(guide.curated)
        local emergency = #situational > 0 and table.concat(situational, "  /  ") or execute and execute.spell.name or "Ton soin, defensif ou controle appris le plus adapte"
        local resourceBody
        if builder and spender then
            resourceBody = "Ressource basse : " .. builder.spell.name .. ".  Ressource prete : " .. spender.spell.name .. "."
        else
            resourceBody = teaching.resource
        end
        guideFrame.plan:SetText("Un bon joueur ne suit pas la meme ligne dans toutes les situations.\nCette page t'apprend quand sortir de la boucle, puis comment y revenir proprement.")
        guideFrame.preparation:SetText("Avant le pull : " .. preparation)
        SetRow(rows[1], "Interface\\Icons\\INV_Misc_Food_64", "Avant le combat", preparation,
            "Fais cette preparation avant le pull. Une fois le combat lance, ne remets pas un buff deja actif au milieu de ta pression.", "PREPARATION", { 0.86, 0.66, 0.25 })
        SetRow(rows[2], guide.entries[1] and guide.entries[1].spell.icon, "Ton ouverture avec ce que tu connais", EntryNames(guide, 1, 3),
            "L'ouverture installe le combat. Apres ces premieres actions, ne continue pas comme une macro : repasse sur la priorite normale.", "OUVERTURE", roleColor, guide.entries[1] and guide.entries[1].spell)
        SetRow(rows[3], builder and builder.spell.icon or spender and spender.spell.icon, "Quand ta ressource change", resourceBody,
            "Le but est simple : reconstruire sans deborder, depenser sans tomber a vide au mauvais moment.", "RESSOURCE", { 0.35, 0.78, 1.00 }, builder and builder.spell or spender and spender.spell)
        SetRow(rows[4], aoe and aoe.spell.icon, "Une cible ou plusieurs ?", aoe and ("Sur un pack stable, regarde " .. aoe.spell.name .. ". En monocible, reste sur les priorites ST.") or "Aucun sort de zone fiable n'est encore appris.",
            "A partir de trois ennemis regroupes, le mode AOE devient generalement interessant. S'ils sont disperses ou vont mourir tout de suite, reste simple.", "ST / AOE", { 0.72, 0.48, 1.00 }, aoe and aoe.spell)
        SetRow(rows[5], "Interface\\Icons\\Spell_Holy_FlashHeal", "Quand il faut casser la rotation", emergency,
            "Soin, defensif, interruption ou execution : utilise-les parce que la situation le demande. Une fois le probleme regle, repars en haut de la priorite.", "REACTION", { 1.00, 0.48, 0.30 })
        guideFrame.source:SetText("Situations adaptees a ton niveau et a ton spellbook • la page ROTATION reste ton fil conducteur")
        RefreshPagination(guide)
        return
    end

    guideFrame.plan:SetText("Ta rotation, tranquillement.\nLis de haut en bas : prends le premier sort disponible dont la condition est remplie, puis repars en haut.")
    guideFrame.preparation:SetText("Preparation separee : " .. preparation .. ". Les soins et defensifs reactifs sont ranges dans SITUATIONS.")
    RefreshPagination(guide)
    local first = (guidePage - 1) * PAGE_SIZE + 1
    local rowIndex
    for rowIndex = 1, PAGE_SIZE do
        local index = first + rowIndex - 1
        local entry = guide.entries[index]
        if entry then
            local badge = entry.curated and "SOURCE" or "ADAPTATIF"
            local color = entry.curated and { 0.35, 1, 0.45 } or { 0.40, 0.78, 1 }
            if entry.talentName then badge = "TALENT : " .. string.upper(entry.talentName) end
            if not entry.curated and not entry.talentName then badge = "ADAPTATIF • TOOLTIP" end
            SetRow(rows[rowIndex], entry.spell.icon, tostring(index) .. ".  " .. entry.spell.name, entry.instruction, entry.explanation, badge, color, entry.spell)
        end
    end
    if #guide.entries == 0 and rows[1] then
        SetRow(rows[1], nil, "Aucune suggestion fiable", "Ouvre ton spellbook, apprends au moins une capacite active, puis clique sur ACTUALISER.", "Je prefere ne rien inventer plutot que de te donner un mauvais ordre.", "PRUDENT", { 1, 0.55, 0.25 })
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
        viewMode = "LEARN"
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

local function MakeButton(name, text, width, x, y)
    local button = CreateFrame("Button", name, guideFrame, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(23)
    button:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", x, y or -88)
    button:SetText(text)
    return button
end

local function BuildInterface()
    scannerTooltip = CreateFrame("GameTooltip", "CoARotationGuideScannerTooltip", UIParent, "GameTooltipTemplate")
    scannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scannerTooltip:Hide()

    guideFrame = CreateFrame("Frame", "CoARotationGuideFrame", UIParent)
    guideFrame:SetWidth(680)
    guideFrame:SetHeight(720)
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

    local header = CreateFrame("Frame", nil, guideFrame)
    header:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 8, -8)
    header:SetWidth(664)
    header:SetHeight(62)
    header:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    header:SetBackdropColor(0.11, 0.065, 0.025, 0.94)
    header:SetBackdropBorderColor(0.82, 0.58, 0.20, 0.95)

    local close = CreateFrame("Button", nil, guideFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", guideFrame, "TOPRIGHT", -4, -4)

    local title = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -15)
    title:SetText("CoA • Ton guide de specialisation")
    title:SetTextColor(1, 0.82, 0.16)

    guideFrame.character = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    guideFrame.character:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -43)
    guideFrame.character:SetWidth(640)
    guideFrame.character:SetJustifyH("LEFT")

    guideFrame.stage = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    guideFrame.stage:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -64)
    guideFrame.stage:SetWidth(640)
    guideFrame.stage:SetJustifyH("LEFT")

    buttons.learn = MakeButton(nil, "COMPRENDRE", 145, 18, -80)
    buttons.rotation = MakeButton(nil, "ROTATION", 125, 168, -80)
    buttons.situations = MakeButton(nil, "SITUATIONS", 135, 298, -80)
    buttons.sources = MakeButton(nil, "SOURCES", 105, 438, -80)
    buttons.refresh = MakeButton(nil, "ACTUALISER", 114, 548, -80)

    buttons.solo = MakeButton(nil, "SOLO", 78, 18, -108)
    buttons.group = MakeButton(nil, "GROUPE", 82, 100, -108)
    buttons.st = MakeButton(nil, "ST", 68, 186, -108)
    buttons.aoe = MakeButton(nil, "AOE", 72, 258, -108)

    buttons.learn:SetScript("OnClick", function() guidePage = 1; viewMode = "LEARN"; RefreshDisplay() end)
    buttons.rotation:SetScript("OnClick", function() guidePage = 1; viewMode = "ROTATION"; RefreshDisplay() end)
    buttons.situations:SetScript("OnClick", function() guidePage = 1; viewMode = "SITUATIONS"; RefreshDisplay() end)
    buttons.sources:SetScript("OnClick", function() guidePage = 1; viewMode = "SOURCES"; RefreshDisplay() end)
    buttons.solo:SetScript("OnClick", function() CoARotationGuideDB.content = "SOLO"; guidePage = 1; RefreshDisplay() end)
    buttons.group:SetScript("OnClick", function() CoARotationGuideDB.content = "GROUP"; guidePage = 1; RefreshDisplay() end)
    buttons.st:SetScript("OnClick", function() CoARotationGuideDB.context = "ST"; guidePage = 1; RefreshDisplay() end)
    buttons.aoe:SetScript("OnClick", function() CoARotationGuideDB.context = "AOE"; guidePage = 1; RefreshDisplay() end)
    buttons.refresh:SetScript("OnClick", function() guidePage = 1; FullScan(false) end)

    local contextHint = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    contextHint:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 344, -114)
    contextHint:SetWidth(318)
    contextHint:SetJustifyH("RIGHT")
    contextHint:SetText("Choisis ton contexte ; le guide s'adapte tout de suite.")

    local planBox = CreateFrame("Frame", nil, guideFrame)
    planBox:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -140)
    planBox:SetWidth(644)
    planBox:SetHeight(48)
    planBox:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
    planBox:SetBackdropColor(0.025, 0.09, 0.12, 0.88)
    planBox:SetBackdropBorderColor(0.20, 0.62, 0.72, 0.9)
    guideFrame.planBox = planBox
    guideFrame.plan = planBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guideFrame.plan:SetPoint("TOPLEFT", planBox, "TOPLEFT", 10, -7)
    guideFrame.plan:SetWidth(624)
    guideFrame.plan:SetJustifyH("LEFT")

    local prepBox = CreateFrame("Frame", nil, guideFrame)
    prepBox:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -194)
    prepBox:SetWidth(644)
    prepBox:SetHeight(38)
    prepBox:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
    prepBox:SetBackdropColor(0.10, 0.075, 0.025, 0.80)
    prepBox:SetBackdropBorderColor(0.60, 0.42, 0.15, 0.9)
    guideFrame.preparation = prepBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guideFrame.preparation:SetPoint("LEFT", prepBox, "LEFT", 10, 0)
    guideFrame.preparation:SetWidth(624)
    guideFrame.preparation:SetJustifyH("LEFT")

    local rowIndex
    for rowIndex = 1, PAGE_SIZE do
        local row = CreateFrame("Frame", nil, guideFrame)
        row:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -240 - (rowIndex - 1) * 84)
        row:SetWidth(644)
        row:SetHeight(78)
        row:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8 })
        row:SetBackdropColor(rowIndex % 2 == 0 and 0.035 or 0.045, 0.065, 0.095, 0.82)
        row:SetBackdropBorderColor(0.20, 0.36, 0.52, 0.75)
        row.accent = row:CreateTexture(nil, "OVERLAY")
        row.accent:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -4)
        row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 4)
        row.accent:SetWidth(4)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(42)
        row.icon:SetHeight(42)
        row.icon:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 58, -6)
        row.title:SetWidth(370)
        row.title:SetJustifyH("LEFT")
        row.body = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.body:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
        row.body:SetWidth(578)
        row.body:SetJustifyH("LEFT")
        row.why = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.why:SetPoint("TOPLEFT", row.body, "BOTTOMLEFT", 0, -2)
        row.why:SetWidth(578)
        row.why:SetJustifyH("LEFT")
        row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
        row.badge:SetWidth(205)
        row.badge:SetJustifyH("RIGHT")
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if not self.spell then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetSpellBookItem then
                pcall(GameTooltip.SetSpellBookItem, GameTooltip, self.spell.index, BOOKTYPE_SPELL or "spell")
            else
                GameTooltip:AddLine(self.spell.name, 1, 0.82, 0)
                GameTooltip:AddLine(self.spell.tooltip or "", 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
        table.insert(rows, row)
    end

    buttons.previous = CreateFrame("Button", nil, guideFrame, "UIPanelButtonTemplate")
    buttons.previous:SetWidth(105)
    buttons.previous:SetHeight(22)
    buttons.previous:SetPoint("BOTTOMLEFT", guideFrame, "BOTTOMLEFT", 18, 32)
    buttons.previous:SetText("< PRECEDENT")
    buttons.previous:SetScript("OnClick", function() guidePage = math.max(1, guidePage - 1); RefreshDisplay() end)

    buttons.next = CreateFrame("Button", nil, guideFrame, "UIPanelButtonTemplate")
    buttons.next:SetWidth(105)
    buttons.next:SetHeight(22)
    buttons.next:SetPoint("BOTTOMRIGHT", guideFrame, "BOTTOMRIGHT", -18, 32)
    buttons.next:SetText("SUIVANT >")
    buttons.next:SetScript("OnClick", function() guidePage = guidePage + 1; RefreshDisplay() end)

    guideFrame.page = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guideFrame.page:SetPoint("BOTTOM", guideFrame, "BOTTOM", 0, 39)
    guideFrame.page:SetWidth(300)
    guideFrame.page:SetJustifyH("CENTER")

    guideFrame.source = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    guideFrame.source:SetPoint("BOTTOMLEFT", guideFrame, "BOTTOMLEFT", 18, 14)
    guideFrame.source:SetWidth(644)
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
        CoARotationGuideDB.context = "ST"; guidePage = 1; viewMode = "ROTATION"; RefreshDisplay(); guideFrame:Show()
    elseif command == "aoe" then
        CoARotationGuideDB.context = "AOE"; guidePage = 1; viewMode = "ROTATION"; RefreshDisplay(); guideFrame:Show()
    elseif command == "solo" then
        CoARotationGuideDB.content = "SOLO"; guidePage = 1; viewMode = "ROTATION"; RefreshDisplay(); guideFrame:Show()
    elseif command == "group" or command == "groupe" then
        CoARotationGuideDB.content = "GROUP"; guidePage = 1; viewMode = "ROTATION"; RefreshDisplay(); guideFrame:Show()
    elseif command == "why" or command == "pourquoi" then
        guidePage = 1; viewMode = "ROTATION"; RefreshDisplay(); guideFrame:Show()
    elseif command == "learn" or command == "comprendre" or command == "guide" then
        guidePage = 1; viewMode = "LEARN"; RefreshDisplay(); guideFrame:Show()
    elseif command == "situation" or command == "situations" then
        guidePage = 1; viewMode = "SITUATIONS"; RefreshDisplay(); guideFrame:Show()
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
        Chat("/rotation | comprendre | pourquoi | situations | scan | status | st | aoe | solo | groupe | sources | minimap | reset")
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
