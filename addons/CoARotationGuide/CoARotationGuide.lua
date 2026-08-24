local addonName = ...
local DATA = CoARotationGuideData or { profiles = {}, aliases = {}, curated = {}, sources = {} }
local PROGRESSION = CoAProgressionGuideData or { bands = {}, sources = {} }

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
local scheduledScanReason = nil
local scheduledScanPasses = 0
local lastCharacterFingerprint = nil
local monitorAt = 0
local lastScanReason = "chargement"
local adaptiveTalentCount = 0
local activeTalentSource = "talents classiques"
local scannerTooltip
local updatePopup
local sessionUpdatePrompted = false

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

local function Shorten(value, limit)
    local text = Trim(value)
    limit = tonumber(limit) or 160
    if string.len(text) <= limit then return text end
    return string.sub(text, 1, math.max(1, limit - 3)) .. "..."
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
    if type(CoARotationGuideDB.updateAcknowledged) ~= "table" then CoARotationGuideDB.updateAcknowledged = {} end
    if type(CoARotationGuideDB.characters) ~= "table" then CoARotationGuideDB.characters = {} end
end

local function CharacterKey()
    local realm = GetRealmName and GetRealmName() or "royaume"
    local name = UnitName and UnitName("player") or "personnage"
    return tostring(realm or "royaume") .. ":" .. tostring(name or "personnage")
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
    adaptiveTalentCount = 0
    activeTalentSource = "talents classiques"
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        local tab
        for tab = 1, GetNumTalentTabs() do
            local talentCount = tonumber(GetNumTalents(tab)) or 0
            local index
            for index = 1, talentCount do
                local ok, name, icon, tier, column, rank = pcall(GetTalentInfo, tab, index)
                rank = ok and tonumber(rank) or 0
                if ok and name and rank and rank > 0 then
                    local talent = { name = name, icon = icon, tier = tier, column = column, rank = rank, tab = tab, source = "classic" }
                    activeTalents[Lower(name)] = talent
                    table.insert(activeTalentList, talent)
                end
            end
        end
    end

    -- Les arbres CoA ne remontent pas toujours par GetTalentInfo sur le client
    -- 3.3.5. Le Loot Decider interroge l'API C_CharacterAdvancement et expose
    -- une photographie stable : on la reutilise sans creer de dependance dure.
    if type(CoALootDeciderAPI) == "table" and type(CoALootDeciderAPI.GetAdaptiveBuild) == "function" then
        local ok, adaptive = pcall(CoALootDeciderAPI.GetAdaptiveBuild)
        if ok and type(adaptive) == "table" then
            adaptiveTalentCount = tonumber(adaptive.selectedCount) or 0
            local _, name
            for _, name in ipairs(adaptive.selectedNames or {}) do
                local key = Lower(name)
                if key ~= "" and not activeTalents[key] then
                    local talent = { name = name, rank = 1, source = "coa" }
                    activeTalents[key] = talent
                    table.insert(activeTalentList, talent)
                end
            end
            if adaptiveTalentCount > 0 then activeTalentSource = "arbres CoA" end
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
    local orderKeys = {}
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
                local key = Lower(name)
                if not spellbook[key] then table.insert(orderKeys, key) end
                -- Les rangs d'un meme sort peuvent tous apparaitre dans le
                -- spellbook CoA. Le dernier index est le rang actuellement le
                -- plus eleve ; il remplace l'ancien sans dupliquer la rotation.
                if not spellbook[key] or index >= (spellbook[key].index or 0) then spellbook[key] = spell end
            end
        end
    end
    local _, key
    for _, key in ipairs(orderKeys) do
        if spellbook[key] then table.insert(spellOrder, spellbook[key]) end
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
    if c.execute then return "Garde " .. spell.name .. " pour la fin, quand la cible est vraiment affaiblie." end
    if c.builder and not c.spender then return "Reviens sur " .. spell.name .. " quand ta ressource baisse ; évite simplement de le lancer si tu es déjà au maximum." end
    if c.spender then return "Quand la ressource est prête, transforme-la avec " .. spell.name .. ". À vide, passe ton chemin pour l'instant." end
    if role == "HEALER" and c.absorb then return "Pose " .. spell.name .. " juste avant les dégâts annoncés : après l'impact, le bouclier arrive trop tard." end
    if role == "HEALER" and c.hot then return "Entretiens " .. spell.name .. " sur la personne qui va continuer à prendre des dégâts, pas au hasard sur tout le groupe." end
    if role == "HEALER" and c.heal then return "Sors " .. spell.name .. " pour réparer une vraie perte de vie. Si tout le monde va bien, garde ton mana." end
    if role == "TANK" and c.mitigation then return "Garde " .. spell.name .. " pour le prochain coup dangereux ; ce n'est pas un bouton à vider dès qu'il s'allume." end
    if c.dot then return "Pose " .. spell.name .. " assez tôt pour qu'il ait le temps de travailler, puis laisse-le respirer au lieu de l'écraser tout de suite." end
    if c.summon then return "Fais entrer " .. spell.name .. " assez tôt : plus l'invocation reste active, plus elle rembourse son lancement." end
    if c.buff then return "Ouvre ta fenêtre avec " .. spell.name .. ", avant les sorts qui doivent réellement en profiter." end
    if context == "AOE" and c.aoe then return "Attends que les ennemis soient bien regroupés, puis lance " .. spell.name .. " au cœur du pack." end
    if c.direct then
        if position == 1 then return "Si la cible est à portée, commence par " .. spell.name .. "." end
        return "Si les choix placés au-dessus ne sont pas prêts, " .. spell.name .. " est ton prochain bouton propre."
    end
    if entry.curated then return spell.name .. " a sa place ici. S'il n'est pas prêt, ne reste pas à l'attendre : descends d'une ligne." end
    return "Garde " .. spell.name .. " sous la main quand son effet correspond vraiment à ce qui se passe."
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
        return "Avec " .. entry.talentName .. " dans tes talents, ce sort vaut davantage pour ton personnage qu'il ne vaudrait dans une liste générique."
    end
    if c.execute then return "Il devient vraiment rentable sur une cible basse en vie. Avant ça, tes attaques habituelles font mieux le travail." end
    if c.builder and not c.spender then
        if nextEntry and nextEntry.spell.categories.spender then
            return "Il remet assez de carburant pour préparer " .. nextEntry.spell.name .. ". Les deux sorts forment le petit aller-retour de ta rotation."
        end
        return "C'est ton moyen de remettre du carburant dans le cycle. Barre pleine, tu ne gagnerais rien à insister dessus."
    end
    if c.spender then
        if previousEntry and previousEntry.spell.categories.builder then
            return previousEntry.spell.name .. " vient de préparer la ressource : " .. spell.name .. " est la façon naturelle de la convertir maintenant."
        end
        return "C'est une dépense, pas un générateur. Elle a donc du sens après la préparation, jamais au début avec une barre vide."
    end
    if c.dot then return "Plus il est posé tôt, plus il a le temps de faire son travail. Le rafraîchir trop vite revient à jeter la fin de l'effet précédent." end
    if c.debuff then return "Il prépare la cible. Tes attaques suivantes arrivent ainsi sur un ennemi déjà affaibli, et non dans le vide."
    end
    if c.buff then return "Le bonus doit couvrir tes gros sorts. Le lancer après eux, ce serait ouvrir le parapluie une fois l'averse terminée."
    end
    if c.summon then return "Une invocation lancée tôt continue d'agir pendant que tu joues le reste. Chaque seconde gagnée lui donne un peu plus de valeur." end
    if role == "HEALER" and c.absorb then return "Un bouclier empêche des dégâts ; après le choc, il ne peut plus rendre les points de vie déjà perdus."
    end
    if role == "HEALER" and c.hot then return "Le soin agit petit à petit. Installe-le pendant que la situation est encore stable, pas quand la cible est déjà au bord du sol."
    end
    if role == "HEALER" and c.heal then return "C'est ta réponse à une vraie blessure. Sans vie à rendre, le meilleur choix reste souvent de ne rien dépenser."
    end
    if role == "TANK" and c.mitigation then return "La mitigation vaut surtout au moment du gros coup. La lancer pendant une accalmie gaspille une partie de sa durée."
    end
    if context == "AOE" and c.aoe then return "Sur plusieurs ennemis regroupés, chaque lancement touche assez de cibles pour dépasser une attaque purement monocible."
    end
    if c.direct then return "C'est ton choix sans détour : des dégâts tout de suite, pendant que les effets plus importants placés au-dessus reviennent."
    end
    return "Son effet colle à ton rôle et au contexte choisi. Je le garde toutefois comme conseil prudent, faute de source assez précise pour être catégorique."
end

local function GenericAfter(entry, nextEntry)
    if not nextEntry then return "Après ça, jette de nouveau un œil en haut de la liste : on suit une priorité, pas une macro apprise par cœur." end
    local current = entry.spell.categories
    local nextCategories = nextEntry.spell.categories
    local nextName = nextEntry.spell.name
    if current.builder and nextCategories.spender then return "Dès que la ressource suffit, regarde " .. nextName .. " : c'est généralement là que la préparation paie." end
    if (current.dot or current.debuff) and (nextCategories.direct or nextCategories.spender) then return "La cible est maintenant préparée ; enchaîne avec " .. nextName .. " pendant que l'effet est encore utile." end
    if current.buff then return "Profite de la fenêtre avec " .. nextName .. " avant que le bonus ne disparaisse." end
    if current.summon then return "Laisse l'invocation travailler et poursuis avec " .. nextName .. "." end
    if current.execute then return "Si la cible n'est pas encore assez basse, saute cette ligne et reviens sur " .. nextName .. "." end
    return "Ensuite, regarde " .. nextName .. ". S'il n'est pas prêt non plus, continue sans attendre vers le bas."
end

local function ExplainEntry(entry, previousEntry, nextEntry, curated, context)
    local exact = CuratedExplanation(curated, context, entry.spell.name)
    local why = exact and exact.why or GenericWhy(entry, previousEntry, nextEntry, currentCharacter.role, context)
    local after = exact and exact.after or GenericAfter(entry, nextEntry)
    entry.explanation = "Pourquoi ça marche : " .. why .. "  Et juste après : " .. after
    entry.explanationKind = exact and "GUIDE VÉRIFIÉ" or "REPÈRE PRUDENT"
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
        talentCount = math.max(#activeTalentList, adaptiveTalentCount)
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
        return { title = "On pose les bases", text = "À ce niveau, ton personnage n'a encore qu'une partie de ses outils. Cherche surtout un bouton fiable, une façon de te protéger et une position confortable.", exercise = "Sur les prochains combats, essaie simplement de reconnaître ton attaque principale sans regarder toutes tes barres. Le reste arrivera progressivement." }
    elseif level < 20 then
        return { title = "Tu découvres vraiment la spécialisation", text = "Le style commence à apparaître, mais inutile d'apprendre quinze boutons d'un coup. Comprends d'abord comment tu entres dans le combat et ce qui fait monter ou descendre ta ressource.", exercise = "Joue quelques combats avec les trois premières priorités seulement. Quand leur enchaînement devient naturel, ajoute la suivante." }
    elseif level < 30 then
        return { title = "Ton kit commence à tenir debout", text = "Tu as désormais assez de sorts pour voir une vraie boucle : tu prépares, tu construis, puis tu dépenses. Les effets à entretenir viennent se glisser autour de ce noyau.", exercise = "Pendant quelques combats, surveille surtout ta ressource. Essaie de ne pas arriver à vide au mauvais moment, ni de rester bloqué au maximum." }
    elseif level < 40 then
        return { title = "La boucle complète est presque là", text = "Entre les niveaux 30 et 39, le jeu prend sa forme normale : une préparation courte, une ouverture propre, puis une boucle qui change selon le nombre d'ennemis.", exercise = "Répète la même ouverture sur quelques monstres, puis reviens en haut de la priorité après chaque grosse dépense. C'est là que les bons réflexes se créent." }
    elseif level < 50 then
        return { title = "Tu rends le jeu plus propre", text = "Le cœur de la spécialisation est là. Le progrès vient maintenant du bon timing : aligner les vrais cooldowns et savoir interrompre la boucle quand le groupe a besoin de toi.", exercise = "Cherche surtout la régularité : moins de boutons pressés par réflexe, une ressource plus stable et des effets importants entretenus sans panique." }
    end
    return { title = "Tu peux maintenant affiner", text = "Ton kit est avancé. La différence se joue sur le timing, la durée de vie des cibles et le choix d'une vraie fenêtre pour tes gros cooldowns.", exercise = "Compare tes choix en ST et en AOE, puis repère les combats où il vaut mieux garder une rafale quelques secondes plutôt que la lancer par habitude." }
end

local function EntryByCategory(guide, category)
    local _, entry
    for _, entry in ipairs(guide.entries or {}) do
        if entry.spell.categories[category] then return entry end
    end
    return nil
end

local function SequenceSentence(guide, first, count)
    local names = {}
    local index
    for index = first or 1, math.min(#guide.entries, (first or 1) + (count or 3) - 1) do
        table.insert(names, guide.entries[index].spell.name)
    end
    if #names == 0 then return "Je n'ai pas encore assez de sorts fiables pour raconter un enchaînement propre." end
    if #names == 1 then return "Pour l'instant, ton point de repère est " .. names[1] .. "." end
    if #names == 2 then return "Commence par " .. names[1] .. ", puis passe sur " .. names[2] .. "." end
    local ending = names[#names]
    table.remove(names, #names)
    return "Commence par " .. table.concat(names, ", enchaîne avec ") .. ", puis termine ce passage avec " .. ending .. "."
end

local function NaturalList(values, emptyText)
    local names = {}
    local _, value
    for _, value in ipairs(values or {}) do table.insert(names, tostring(value)) end
    if #names == 0 then return emptyText or "Rien de particulier avec les sorts appris pour l'instant" end
    if #names == 1 then return names[1] end
    local ending = names[#names]
    table.remove(names, #names)
    return table.concat(names, ", ") .. " puis " .. ending
end

local function ProgressionBand(level)
    local _, band
    for _, band in ipairs(PROGRESSION.bands or {}) do
        if (tonumber(level) or 0) <= (tonumber(band.maximum) or 999) then return band end
    end
    return {
        title = "Continuer a faire progresser ton personnage",
        goal = "Choisis un objectif atteignable, mesure le resultat, puis monte d'un cran.",
        activity = "Le contenu termine regulierement vaut mieux qu'une difficulte trop haute abandonnee en route.",
        checkpoint = "Actualise le guide apres un changement important de build."
    }
end

local function LootProfileSummary()
    if type(CoALootDeciderAPI) ~= "table" or type(CoALootDeciderAPI.GetProfile) ~= "function" then
        return "Le Loot Decider n'est pas charge. Active-le pour obtenir ici les statistiques exactes de ce personnage.",
            "L'addon de rotation ne devine pas la valeur des objets : il laisse cette comparaison au moteur de butin."
    end
    local ok, lootProfile = pcall(CoALootDeciderAPI.GetProfile)
    if ok and type(lootProfile) == "table" and tonumber(lootProfile.level) ~= tonumber(currentCharacter.level)
        and type(CoALootDeciderAPI.RefreshProfile) == "function"
    then
        pcall(CoALootDeciderAPI.RefreshProfile)
        ok, lootProfile = pcall(CoALootDeciderAPI.GetProfile)
    end
    if not ok or type(lootProfile) ~= "table" or not lootProfile.valid then
        return "Le profil de stuff n'est pas encore pret. Ouvre le Loot Decider ou clique sur ACTUALISER, puis reviens ici.",
            "Aucun achat ne devrait etre conseille tant que la classe et la specialisation ne sont pas reconnues."
    end
    local display = {}
    if type(CoALootDeciderAPI.GetDisplayStats) == "function" then
        local displayOK, values = pcall(CoALootDeciderAPI.GetDisplayStats)
        if displayOK and type(values) == "table" then display = values end
    end
    local ranked = {}
    local stat, weight
    for stat, weight in pairs(lootProfile.weights or {}) do
        weight = tonumber(weight) or 0
        if weight > 0 then table.insert(ranked, { name = display[stat] or stat, weight = weight }) end
    end
    table.sort(ranked, function(a, b) return a.weight > b.weight end)
    local labels = {}
    local index
    for index = 1, math.min(4, #ranked) do table.insert(labels, ranked[index].name) end
    local priority = #labels > 0 and table.concat(labels, " > ") or "profil reconnu, priorites en cours de calcul"
    local weapon = ""
    if lootProfile.weaponRule and lootProfile.weaponRule.preferTwoHand then weapon = " Arme : deux mains preferee."
    elseif lootProfile.weaponRule and lootProfile.weaponRule.speed == "fast" then weapon = " Arme : vitesse rapide preferee."
    elseif lootProfile.weaponRule and lootProfile.weaponRule.speed == "slow" then weapon = " Arme : vitesse lente preferee." end
    local adaptive = lootProfile.adaptive or {}
    local details = "Profil " .. tostring(lootProfile.className or "?") .. " - " .. tostring(lootProfile.specName or "?")
        .. ", niveau " .. tostring(lootProfile.level or currentCharacter.level or "?") .. "."
    if tonumber(adaptive.selectedCount) and tonumber(adaptive.selectedCount) > 0 then
        details = details .. " " .. tostring(adaptive.selectedCount) .. " talent(s) CoA participent au calcul."
    end
    return "Priorite actuelle : " .. priority .. "." .. weapon, details
end

local function ProgressionCards(guide, preparation)
    local band = ProgressionBand(currentCharacter.level)
    local lootBody, lootWhy = LootProfileSummary()
    local cards = {
        {
            icon = "Interface\\Icons\\INV_Misc_Map_01",
            title = "1. Ton prochain objectif",
            body = band.goal,
            why = "Le guide vient de relire ton niveau et ton spellbook : ce conseil avance donc avec le personnage.",
            badge = band.title,
            color = { 0.48, 0.90, 0.55 }
        },
        {
            icon = "Interface\\Icons\\INV_Misc_Book_09",
            title = "2. Quoi faire maintenant",
            body = band.activity,
            why = currentCharacter.level >= 60
                and "Commence par une difficulte que le groupe termine proprement ; les caches et les coins viennent des Mythiques acheves, pas des tentatives abandonnees."
                or "Pendant le leveling, progresser regulierement et apprendre le kit rapporte plus qu'une optimisation couteuse tous les cinq niveaux.",
            badge = currentCharacter.level >= 60 and "ENDGAME" or ("NIVEAU " .. tostring(currentCharacter.level)),
            color = { 0.35, 0.78, 1.00 }
        },
        {
            icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
            title = "3. Avant de partir",
            body = preparation,
            why = "Ce sont uniquement les preparations connues dans ton spellbook. Si la liste change apres un niveau, l'actualisation automatique la remplacera.",
            badge = "BUFFS / OUTILS",
            color = { 0.86, 0.66, 0.25 }
        },
        {
            icon = "Interface\\Icons\\INV_Chest_Chain_05",
            title = "4. Quel stuff chercher",
            body = lootBody,
            why = lootWhy,
            badge = "PROFIL LIVE",
            color = { 0.72, 0.48, 1.00 }
        }
    }
    if currentCharacter.level >= 60 then
        table.insert(cards, {
            icon = "Interface\\Icons\\INV_Misc_Coin_01",
            title = "5. Mythiques, caches et Edrim Skysong",
            body = "Forme un groupe, va a l'entree du donjon et active la keystone. Termine les objectifs de boss et de trash : la fin donne des caches et des Mythic Coins.",
            why = "Edrim gere achats, ameliorations, keystone et recyclage. Compare chaque objet avant ; les couts affiches par le PNJ font foi.",
            badge = "CONFIRME + JEU",
            color = { 1.00, 0.62, 0.22 }
        })
    else
        table.insert(cards, {
            icon = "Interface\\Icons\\INV_Misc_Note_06",
            title = "5. Le prochain palier",
            body = band.checkpoint,
            why = "Tu n'as rien a regler manuellement : gain de niveau, nouveau sort et talent declenchent plusieurs lectures espacees du personnage.",
            badge = "AUTOMATIQUE",
            color = { 1.00, 0.62, 0.22 }
        })
    end
    return cards, band
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
        resource = builder.spell.name .. " remplit ta ressource, tandis que " .. spender.spell.name .. " la transforme en résultat concret. Ton rythme vient de cet aller-retour."
    elseif role == "HEALER" then
        resource = "Ton mana doit tenir tout le combat. Prépare les dégâts prévisibles, puis soigne ce qui a réellement été perdu au lieu de remplir les barres par nervosité."
    elseif role == "TANK" then
        resource = "Ta vraie ressource, c'est aussi le temps. Garde la mitigation pour le choc qui compte et stabilise les ennemis pendant les moments plus calmes."
    else
        resource = "Prépare d'abord la cible ou ta propre fenêtre, puis transforme cette préparation en dégâts. Appuyer plus vite ne remplace pas le bon ordre."
    end
    local golden
    if role == "HEALER" then golden = "Tu ne soignes pas une liste de boutons, tu soignes une situation : protège avant le choc et rends la vie seulement quand elle manque."
    elseif role == "TANK" then golden = "Reste en vie, stabilise le pack, puis cherche les dégâts. Dans cet ordre-là, les combats deviennent beaucoup plus simples."
    elseif role == "SUPPORT" then golden = "Place ton utilitaire juste avant que le groupe en profite, puis continue ta pression sans sacrifier la prochaine aide importante."
    else golden = "Prends le premier choix dont les conditions sont remplies. Si ce n'est pas le cas, descends d'une ligne au lieu d'attendre en regardant le bouton."
    end
    return {
        identity = guide.profile and guide.profile.style or "Ton spellbook determine ce que tu peux vraiment jouer aujourd'hui.",
        resource = resource,
        opening = SequenceSentence(guide, 1, 3),
        loop = "Une fois ce passage terminé, reviens au début et reprends le premier sort réellement disponible. La cible et la ressource peuvent changer l'ordre à chaque tour.",
        goldenRule = golden,
        mistake = "Réciter la liste comme une macro. La cible, la ressource et les cooldowns ont toujours le dernier mot."
    }
end

local function TeachingFor(guide)
    local fallback = GenericTeaching(guide)
    local exact = guide.curated and guide.curated.teaching or nil
    if not exact then return fallback end
    return {
        identity = exact.identity or fallback.identity,
        resource = exact.resource or fallback.resource,
        opening = exact.opening or fallback.opening,
        loop = exact.loop or fallback.loop,
        goldenRule = exact.goldenRule or fallback.goldenRule,
        mistake = exact.mistake or fallback.mistake
    }
end

local function UpdateIdentity(item, index)
    return tostring(item and item.id or (item and item.updatedAt) or index or "update")
end

local function UpdateSearchText(item)
    local parts = { item.title, item.friendly, item.officialNote }
    local _, tag
    for _, tag in ipairs(item.tags or {}) do table.insert(parts, tag) end
    return Lower(table.concat(parts, " "))
end

local function UpdateMatchesCharacter(item)
    if type(item) ~= "table" then return false end
    local searchable = UpdateSearchText(item)
    if searchable == "" then return false end
    if Contains(searchable, Lower(currentCharacter.className)) or Contains(searchable, Lower(currentCharacter.specName)) then return true end
    local _, spell
    for _, spell in ipairs(spellOrder) do
        local name = Lower(spell.name)
        if string.len(name) >= 5 and Contains(searchable, name) then return true end
    end
    return ContainsAny(searchable, { "all classes", "toutes les classes", "global class", "specialization system" })
end

local function RelevantUpdates()
    local relevant = {}
    local feed = CoARotationUpdateFeed
    local _, item
    for _, item in ipairs(type(feed) == "table" and type(feed.items) == "table" and feed.items or {}) do
        if UpdateMatchesCharacter(item) then table.insert(relevant, item) end
    end
    return relevant
end

local function UpdateAcknowledgements()
    EnsureDatabase()
    local profileKey = tostring(currentCharacter.profileKey or currentCharacter.className or "GLOBAL")
    if type(CoARotationGuideDB.updateAcknowledged[profileKey]) ~= "table" then
        CoARotationGuideDB.updateAcknowledged[profileKey] = {}
    end
    return CoARotationGuideDB.updateAcknowledged[profileKey]
end

local function UnreadUpdateCount(items)
    local seen = UpdateAcknowledgements()
    local count, index = 0, 0
    for index = 1, #(items or {}) do
        if not seen[UpdateIdentity(items[index], index)] then count = count + 1 end
    end
    return count
end

local function AcknowledgeUpdates(items)
    local seen = UpdateAcknowledgements()
    local index
    for index = 1, #(items or {}) do seen[UpdateIdentity(items[index], index)] = true end
end

local function SetRow(row, icon, title, body, explanation, badge, badgeColor, spell)
    row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.title:SetText(title or "")
    row.body:SetText(body or "")
    row.why:SetText(explanation or "")
    row.badge:SetText(badge or "")
    row.spell = spell
    row.update = nil
    local color = badgeColor or { 0.45, 0.82, 1 }
    row.badge:SetTextColor(color[1], color[2], color[3])
    row.title:SetTextColor(color[1], color[2], color[3])
    if row.accent then row.accent:SetVertexColor(color[1], color[2], color[3], 0.95) end
    row:Show()
end

local function HideRows()
    local _, row
    for _, row in ipairs(rows) do row.spell = nil; row.update = nil; row:Hide() end
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
    buttons.progression:SetText(viewMode == "PROGRESSION" and "• PROGRESSION •" or "PROGRESSION")
    local unread = UnreadUpdateCount(RelevantUpdates())
    local updateLabel = unread > 0 and ("ACTUS (" .. tostring(unread) .. ")") or "ACTUS"
    buttons.updates:SetText(viewMode == "UPDATES" and ("• " .. updateLabel .. " •") or updateLabel)
    buttons.sources:SetText(viewMode == "SOURCES" and "• SOURCES •" or "SOURCES")
end

local function RefreshPagination(guide, updateCount)
    if not buttons.previous or not buttons.next or not guideFrame.page then return end
    if viewMode ~= "ROTATION" and viewMode ~= "UPDATES" then
        buttons.previous:Hide()
        buttons.next:Hide()
        guideFrame.page:Hide()
        return
    end
    buttons.previous:Show()
    buttons.next:Show()
    guideFrame.page:Show()
    local totalItems = viewMode == "UPDATES" and (tonumber(updateCount) or 0) or #guide.entries
    local totalPages = math.max(1, math.ceil(totalItems / PAGE_SIZE))
    guidePage = Clamp(guidePage, 1, totalPages)
    if totalItems == 0 then
        guideFrame.page:SetText(viewMode == "UPDATES" and "Aucune actualité pertinente" or "Aucune étape fiable")
    else
        local label = viewMode == "UPDATES" and "Actualités " or "Étapes "
        guideFrame.page:SetText(label .. tostring((guidePage - 1) * PAGE_SIZE + 1) .. "-" .. tostring(math.min(guidePage * PAGE_SIZE, totalItems)) .. " / " .. tostring(totalItems))
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
    local preparation = NaturalList(guide.preparation, "Rien de particulier avec les sorts actuellement appris")
    guideFrame.character:SetText(currentCharacter.className .. "  •  " .. currentCharacter.specName .. "  •  niveau " .. tostring(currentCharacter.level) .. "  •  " .. RoleLabel(currentCharacter.role))
    guideFrame.stage:SetText(chapter.title .. "  •  " .. guide.stage)
    if guideFrame.sync then
        guideFrame.sync:SetText("AUTO  •  " .. tostring(guide.spellCount) .. " sorts  •  " .. tostring(guide.talentCount) .. " talents")
    end
    if guideFrame.planBox then guideFrame.planBox:SetBackdropBorderColor(roleColor[1], roleColor[2], roleColor[3], 0.95) end
    RefreshButtons()
    HideRows()

    if viewMode == "UPDATES" then
        local relevant = RelevantUpdates()
        AcknowledgeUpdates(relevant)
        RefreshButtons()
        RefreshPagination(guide, #relevant)
        guideFrame.plan:SetText("Ce qui a changé pour ton personnage\nLe manager lit les sources Ascension, puis le guide ne garde ici que ce qui ressemble à ta classe, ta spécialisation ou un sort appris.")
        guideFrame.preparation:SetText(#relevant > 0 and "Je te préviens d'abord ; je ne change jamais ta rotation en silence avant une vérification." or "Aucune note récente ne semble concerner ce personnage.")
        if #relevant == 0 then
            SetRow(rows[1], "Interface\\Icons\\INV_Misc_Note_06", "Rien à signaler pour l'instant", "La veille fonctionne, mais aucun changement récent ne correspond à ton personnage actuel.",
                "Ouvre le manager de temps en temps : World of Warcraft 3.3.5 ne peut pas consulter Internet tout seul.", "À JOUR", { 0.48, 0.90, 0.55 })
        else
            local firstUpdate = (guidePage - 1) * PAGE_SIZE + 1
            local rowIndex
            for rowIndex = 1, PAGE_SIZE do
                local item = relevant[firstUpdate + rowIndex - 1]
                if item and rows[rowIndex] then
                    SetRow(rows[rowIndex], "Interface\\Icons\\INV_Misc_Note_05", tostring(item.kind or "Mise à jour") .. "  •  " .. string.sub(tostring(item.updatedAt or ""), 1, 10),
                        Shorten(item.friendly, 175), "Note officielle : " .. Shorten(item.officialNote, 145), "ASCENSION", { 1.00, 0.62, 0.22 })
                    rows[rowIndex].update = item
                end
            end
        end
        local feed = CoARotationUpdateFeed or {}
        guideFrame.source:SetText("Veille synchronisée : " .. tostring(feed.generatedAt or "jamais") .. "  •  source : " .. tostring(feed.sourceUrl or "https://ascension.gg/en/changelog/4"))
        return
    end

    if viewMode == "SOURCES" then
        guideFrame.plan:SetText("D'où viennent les conseils ?\nJe recoupe les guides, le changelog officiel et surtout ton vrai spellbook. Quand une partie reste incertaine, je te le dis au lieu de la présenter comme une vérité.")
        guideFrame.preparation:SetText("La règle reste simple : ton personnage passe avant la théorie. Un sort absent de ton spellbook ne doit jamais apparaître dans ton parcours.")
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

    if viewMode == "PROGRESSION" then
        local cards, band = ProgressionCards(guide, preparation)
        guideFrame.plan:SetText("Voila quoi faire maintenant, sans te noyer dans tout l'endgame.\nLe parcours suit automatiquement ton niveau ; le profil de stuff vient directement du Loot Decider quand il est actif.")
        guideFrame.preparation:SetText(tostring(band.title) .. "  •  lecture automatique : " .. tostring(guide.spellCount) .. " sorts et " .. tostring(guide.talentCount) .. " talents.")
        local index, card
        for index, card in ipairs(cards) do
            if rows[index] then SetRow(rows[index], card.icon, card.title, card.body, card.why, card.badge, card.color) end
        end
        if currentCharacter.level >= 60 then
            guideFrame.source:SetText("Progression 60 : Ascension Mythic+ + Edrim Skysong + informations affichees par le PNJ  •  donnees " .. tostring(PROGRESSION.sourceDate or "?"))
        else
            guideFrame.source:SetText("Parcours de leveling hors ligne  •  prochain rescannage automatique au niveau, sort ou talent suivant")
        end
        RefreshPagination(guide)
        return
    end

    if viewMode == "LEARN" then
        guideFrame.plan:SetText("On va prendre le temps de comprendre ton personnage.\nPas de pavé théorique : d'abord l'idée générale, ensuite le déroulé d'un combat, puis les détails quand tu en as besoin.")
        guideFrame.preparation:SetText("À ton niveau : " .. chapter.title .. ". Lis un bloc, essaie-le en jeu, puis reviens quand le geste devient naturel.")
        SetRow(rows[1], "Interface\\Icons\\INV_Misc_Book_09", "1. Voilà ce que tu joues vraiment", teaching.identity,
            "Si tu ne gardes qu'une image en tête : " .. tostring(guide.plan), "L'IDÉE GÉNÉRALE", roleColor)
        SetRow(rows[2], "Interface\\Icons\\INV_Misc_Rune_06", "2. Le moteur de ton gameplay", teaching.resource,
            "C'est ce mouvement-là qu'il faut sentir en combat. Les noms de sorts viendront beaucoup plus facilement une fois le rythme compris.", "TON RYTHME", { 0.35, 0.78, 1.00 })
        SetRow(rows[3], guide.entries[1] and guide.entries[1].spell.icon, "3. À quoi ressemble un combat", teaching.opening,
            "Une fois lancé : " .. teaching.loop, "LE DÉROULÉ", { 1.00, 0.72, 0.22 }, guide.entries[1] and guide.entries[1].spell)
        SetRow(rows[4], "Interface\\Icons\\INV_Misc_Map_01", "4. Ce que tu peux travailler maintenant", chapter.text,
            "Essaie ça : " .. chapter.exercise, "NIVEAU " .. tostring(currentCharacter.level), { 0.48, 0.90, 0.55 })
        SetRow(rows[5], "Interface\\Icons\\INV_Misc_Note_06", "5. Le conseil que je te donnerais avant de partir", teaching.goldenRule,
            "Le piège le plus courant : " .. teaching.mistake, "À RETENIR", { 1.00, 0.48, 0.30 })
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
            resourceBody = "Quand la ressource baisse, reviens sur " .. builder.spell.name .. ". Quand elle est prête, " .. spender.spell.name .. " te permet de la convertir."
        else
            resourceBody = teaching.resource
        end
        guideFrame.plan:SetText("Aucun combat ne se déroule exactement comme sur une fiche.\nCette page t'aide à reconnaître les moments où tu dois sortir de la boucle, régler le problème, puis reprendre sans paniquer.")
        guideFrame.preparation:SetText("Avant le pull : " .. preparation)
        SetRow(rows[1], "Interface\\Icons\\INV_Misc_Food_64", "Avant le combat", preparation,
            "Fais cette preparation avant le pull. Une fois le combat lance, ne remets pas un buff deja actif au milieu de ta pression.", "PREPARATION", { 0.86, 0.66, 0.25 })
        SetRow(rows[2], guide.entries[1] and guide.entries[1].spell.icon, "Les premières secondes du combat", teaching.opening,
            "Après cette mise en place, arrête de réciter : " .. teaching.loop, "OUVERTURE", roleColor, guide.entries[1] and guide.entries[1].spell)
        SetRow(rows[3], builder and builder.spell.icon or spender and spender.spell.icon, "Quand ta ressource change", resourceBody,
            "Cherche un rythme souple : reconstruire avant la panne, puis dépenser avant de rester bloqué au maximum.", "RESSOURCE", { 0.35, 0.78, 1.00 }, builder and builder.spell or spender and spender.spell)
        SetRow(rows[4], aoe and aoe.spell.icon, "Une cible ou plusieurs ?", aoe and ("Sur un pack stable, regarde " .. aoe.spell.name .. ". En monocible, reste sur les priorites ST.") or "Aucun sort de zone fiable n'est encore appris.",
            "À partir de trois ennemis vraiment regroupés, l'AOE devient généralement intéressante. S'ils sont dispersés ou presque morts, reste sur un choix simple.", "ST / AOE", { 0.72, 0.48, 1.00 }, aoe and aoe.spell)
        SetRow(rows[5], "Interface\\Icons\\Spell_Holy_FlashHeal", "Quand il faut casser la rotation", emergency,
            "Soin, défensif, interruption ou exécution : tu les sors parce que le combat le demande. Une fois le problème réglé, reviens tranquillement au début de la priorité.", "RÉACTION", { 1.00, 0.48, 0.30 })
        guideFrame.source:SetText("Situations adaptees a ton niveau et a ton spellbook • la page ROTATION reste ton fil conducteur")
        RefreshPagination(guide)
        return
    end

    guideFrame.plan:SetText("Voici ta priorité du moment.\nLis-la comme une série de questions : le premier choix est-il prêt et utile maintenant ? Sinon, passe au suivant sans rester bloqué.")
    guideFrame.preparation:SetText("Avant le combat : " .. preparation .. ". Les soins et défensifs de réaction restent volontairement dans SITUATIONS.")
    RefreshPagination(guide)
    local first = (guidePage - 1) * PAGE_SIZE + 1
    local rowIndex
    for rowIndex = 1, PAGE_SIZE do
        local index = first + rowIndex - 1
        local entry = guide.entries[index]
        if entry then
            local badge = entry.curated and "GUIDE VÉRIFIÉ" or "SELON TES SORTS"
            local color = entry.curated and { 0.35, 1, 0.45 } or { 0.40, 0.78, 1 }
            if entry.talentName then badge = "AVEC " .. string.upper(entry.talentName) end
            if not entry.curated and not entry.talentName then badge = "REPÈRE PRUDENT" end
            SetRow(rows[rowIndex], entry.spell.icon, tostring(index) .. ".  " .. entry.spell.name, entry.instruction, entry.explanation, badge, color, entry.spell)
        end
    end
    if #guide.entries == 0 and rows[1] then
        SetRow(rows[1], nil, "Aucune suggestion fiable", "Ouvre ton spellbook, apprends au moins une capacite active, puis clique sur ACTUALISER.", "Je prefere ne rien inventer plutot que de te donner un mauvais ordre.", "PRUDENT", { 1, 0.55, 0.25 })
    end
    local quality = guide.curated and guide.curated.quality or "Classement adaptatif prudent"
    guideFrame.source:SetText(quality .. "  •  " .. tostring(guide.spellCount) .. " sorts  •  " .. tostring(guide.talentCount) .. " talents  •  " .. tostring(guide.talentRules) .. " priorite(s) talent")
end

local function OpenUpdatePage()
    guidePage = 1
    viewMode = "UPDATES"
    RefreshDisplay()
    if guideFrame then guideFrame:Show() end
    if updatePopup then updatePopup:Hide() end
end

local function PromptForRelevantUpdates()
    if sessionUpdatePrompted or not updatePopup then return end
    local relevant = RelevantUpdates()
    local unread = UnreadUpdateCount(relevant)
    if unread <= 0 then return end
    sessionUpdatePrompted = true
    local first = relevant[1]
    updatePopup.message:SetText(tostring(unread) .. " changement(s) Ascension peuvent concerner "
        .. tostring(currentCharacter.className) .. " - " .. tostring(currentCharacter.specName) .. ".\n\n"
        .. Shorten(first and first.friendly or "Le guide a reçu de nouvelles notes officielles.", 210))
    updatePopup:Show()
    Chat(tostring(unread) .. " mise(s) à jour Ascension semblent concerner ton personnage. Ouvre /rotation actus pour les lire.")
    if CoAMessageCenter and type(CoAMessageCenter.AddMessage) == "function" then
        CoAMessageCenter:AddMessage("CoA Rotation Guide", tostring(unread) .. " changement(s) Ascension à vérifier pour "
            .. tostring(currentCharacter.className) .. " - " .. tostring(currentCharacter.specName) .. ".", "warning")
    end
end

local function SpellbookSlotCount()
    if not GetNumSpellTabs or not GetSpellTabInfo then return 0 end
    local total, tab = 0, 0
    for tab = 1, GetNumSpellTabs() do
        local _, _, _, count = GetSpellTabInfo(tab)
        total = total + (tonumber(count) or 0)
    end
    return total
end

local function CharacterFingerprint()
    local className = UnitClass and UnitClass("player") or "?"
    local level = UnitLevel and UnitLevel("player") or 0
    local spec = "?"
    if type(GetSpecialization) == "function" then
        local ok, value = pcall(GetSpecialization)
        if ok and value then spec = tostring(value) end
    end
    local adaptiveSignature = ""
    if type(CoALootDeciderAPI) == "table" and type(CoALootDeciderAPI.GetAdaptiveBuild) == "function" then
        local ok, adaptive = pcall(CoALootDeciderAPI.GetAdaptiveBuild)
        if ok and type(adaptive) == "table" then
            adaptiveSignature = tostring(adaptive.signature or adaptive.selectedCount or "")
        end
    end
    return table.concat({ tostring(className), tostring(level), tostring(spec), tostring(SpellbookSlotCount()), adaptiveSignature }, "|")
end

local function SaveCharacterSnapshot(reason)
    EnsureDatabase()
    local guide = currentGuide or {}
    CoARotationGuideDB.characters[CharacterKey()] = {
        className = currentCharacter.className,
        specName = currentCharacter.specName,
        level = currentCharacter.level,
        spellCount = guide.spellCount or #spellOrder,
        talentCount = guide.talentCount or math.max(#activeTalentList, adaptiveTalentCount),
        talentSource = activeTalentSource,
        reason = reason or "scan",
        scannedAt = type(time) == "function" and time() or (GetTime and GetTime() or 0)
    }
end

local function FullScan(silent, reason)
    lastScanReason = reason or lastScanReason or "scan"
    ScanTalents()
    ScanSpellbook()
    RefreshDisplay()
    lastCharacterFingerprint = CharacterFingerprint()
    SaveCharacterSnapshot(lastScanReason)
    PromptForRelevantUpdates()
    if not silent then
        Chat(tostring(#spellOrder) .. " sorts et " .. tostring(#activeTalentList) .. " talents lus pour " .. tostring(currentCharacter.className) .. " - " .. tostring(currentCharacter.specName) .. ".")
        Chat("Guide actualise automatiquement au niveau " .. tostring(currentCharacter.level) .. " (" .. tostring(lastScanReason) .. ").")
    end
end

local function ScheduleScan(delay, reason, passes)
    scheduledScanAt = (GetTime and GetTime() or 0) + (tonumber(delay) or 0.4)
    scheduledScanReason = reason or scheduledScanReason or "changement detecte"
    scheduledScanPasses = math.max(tonumber(passes) or 0, scheduledScanPasses or 0)
end

local function ToggleGuide()
    if not guideFrame then return end
    if guideFrame:IsShown() then
        SavePosition()
        guideFrame:Hide()
    else
        viewMode = "LEARN"
        FullScan(true, "ouverture du guide")
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
    guideFrame:SetHeight(748)
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
    header:SetHeight(64)
    header:SetFrameLevel(guideFrame:GetFrameLevel() + 1)
    header:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    header:SetBackdropColor(0.035, 0.075, 0.12, 0.98)
    header:SetBackdropBorderColor(0.30, 0.70, 0.86, 0.95)
    local headerAccent = header:CreateTexture(nil, "OVERLAY")
    headerAccent:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    headerAccent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 5, 5)
    headerAccent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -5, 5)
    headerAccent:SetHeight(2)
    headerAccent:SetVertexColor(1.00, 0.66, 0.18, 0.95)

    local close = CreateFrame("Button", nil, guideFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", guideFrame, "TOPRIGHT", -4, -4)
    close:SetFrameLevel(header:GetFrameLevel() + 1)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 12, -9)
    title:SetText("CoA  •  Ton guide de specialisation")
    title:SetTextColor(1.00, 0.82, 0.20)

    guideFrame.character = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    guideFrame.character:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 12, 13)
    guideFrame.character:SetWidth(620)
    guideFrame.character:SetJustifyH("LEFT")
    guideFrame.character:SetTextColor(0.92, 0.96, 1.00)

    guideFrame.sync = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guideFrame.sync:SetPoint("TOPRIGHT", header, "TOPRIGHT", -38, -13)
    guideFrame.sync:SetWidth(250)
    guideFrame.sync:SetJustifyH("RIGHT")
    guideFrame.sync:SetTextColor(0.42, 0.95, 0.65)

    guideFrame.stage = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    guideFrame.stage:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -77)
    guideFrame.stage:SetWidth(640)
    guideFrame.stage:SetJustifyH("LEFT")
    guideFrame.stage:SetTextColor(0.68, 0.76, 0.86)

    buttons.learn = MakeButton(nil, "COMPRENDRE", 110, 18, -96)
    buttons.rotation = MakeButton(nil, "ROTATION", 92, 132, -96)
    buttons.situations = MakeButton(nil, "SITUATIONS", 105, 228, -96)
    buttons.progression = MakeButton(nil, "PROGRESSION", 116, 337, -96)
    buttons.updates = MakeButton(nil, "ACTUS", 91, 457, -96)
    buttons.sources = MakeButton(nil, "SOURCES", 110, 552, -96)

    buttons.solo = MakeButton(nil, "SOLO", 78, 18, -124)
    buttons.group = MakeButton(nil, "GROUPE", 82, 100, -124)
    buttons.st = MakeButton(nil, "ST", 68, 186, -124)
    buttons.aoe = MakeButton(nil, "AOE", 72, 258, -124)
    buttons.refresh = MakeButton(nil, "ACTUALISER MAINTENANT", 157, 505, -124)

    buttons.learn:SetScript("OnClick", function() guidePage = 1; viewMode = "LEARN"; RefreshDisplay() end)
    buttons.rotation:SetScript("OnClick", function() guidePage = 1; viewMode = "ROTATION"; RefreshDisplay() end)
    buttons.situations:SetScript("OnClick", function() guidePage = 1; viewMode = "SITUATIONS"; RefreshDisplay() end)
    buttons.progression:SetScript("OnClick", function() guidePage = 1; viewMode = "PROGRESSION"; FullScan(true, "ouverture progression") end)
    buttons.updates:SetScript("OnClick", OpenUpdatePage)
    buttons.sources:SetScript("OnClick", function() guidePage = 1; viewMode = "SOURCES"; RefreshDisplay() end)
    buttons.solo:SetScript("OnClick", function() CoARotationGuideDB.content = "SOLO"; guidePage = 1; RefreshDisplay() end)
    buttons.group:SetScript("OnClick", function() CoARotationGuideDB.content = "GROUP"; guidePage = 1; RefreshDisplay() end)
    buttons.st:SetScript("OnClick", function() CoARotationGuideDB.context = "ST"; guidePage = 1; RefreshDisplay() end)
    buttons.aoe:SetScript("OnClick", function() CoARotationGuideDB.context = "AOE"; guidePage = 1; RefreshDisplay() end)
    buttons.refresh:SetScript("OnClick", function() guidePage = 1; FullScan(false, "bouton Actualiser") end)

    local contextHint = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    contextHint:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 344, -130)
    contextHint:SetWidth(150)
    contextHint:SetJustifyH("RIGHT")
    contextHint:SetText("Contexte du guide")

    local planBox = CreateFrame("Frame", nil, guideFrame)
    planBox:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -154)
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
    prepBox:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -208)
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
        row:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 18, -254 - (rowIndex - 1) * 84)
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
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.update then
                GameTooltip:AddLine(tostring(self.update.kind or "Mise à jour Ascension"), 1, 0.75, 0.2)
                GameTooltip:AddLine(tostring(self.update.friendly or ""), 1, 1, 1, true)
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("Note officielle", 0.45, 0.82, 1)
                GameTooltip:AddLine(tostring(self.update.officialNote or ""), 0.85, 0.88, 0.92, true)
                GameTooltip:AddLine(tostring(self.update.sourceUrl or ""), 0.55, 0.65, 0.75, true)
            elseif self.spell and GameTooltip.SetSpellBookItem then
                pcall(GameTooltip.SetSpellBookItem, GameTooltip, self.spell.index, BOOKTYPE_SPELL or "spell")
            elseif self.spell then
                GameTooltip:AddLine(self.spell.name, 1, 0.82, 0)
                GameTooltip:AddLine(self.spell.tooltip or "", 1, 1, 1, true)
            else
                return
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

    updatePopup = CreateFrame("Frame", "CoARotationGuideUpdatePopup", UIParent)
    updatePopup:SetWidth(470)
    updatePopup:SetHeight(178)
    updatePopup:SetPoint("TOP", UIParent, "TOP", 0, -120)
    updatePopup:SetFrameStrata("DIALOG")
    updatePopup:SetClampedToScreen(true)
    updatePopup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    updatePopup:SetBackdropColor(0.055, 0.035, 0.015, 0.98)
    updatePopup:SetBackdropBorderColor(1.00, 0.62, 0.18, 1.00)
    local updateTitle = updatePopup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    updateTitle:SetPoint("TOP", updatePopup, "TOP", 0, -18)
    updateTitle:SetText("Le jeu a changé depuis ton dernier passage")
    updateTitle:SetTextColor(1.00, 0.78, 0.22)
    updatePopup.message = updatePopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    updatePopup.message:SetPoint("TOPLEFT", updatePopup, "TOPLEFT", 24, -48)
    updatePopup.message:SetWidth(422)
    updatePopup.message:SetJustifyH("LEFT")
    local readUpdates = CreateFrame("Button", nil, updatePopup, "UIPanelButtonTemplate")
    readUpdates:SetWidth(170)
    readUpdates:SetHeight(24)
    readUpdates:SetPoint("BOTTOMLEFT", updatePopup, "BOTTOMLEFT", 45, 18)
    readUpdates:SetText("VOIR CE QUI A CHANGÉ")
    readUpdates:SetScript("OnClick", OpenUpdatePage)
    local later = CreateFrame("Button", nil, updatePopup, "UIPanelButtonTemplate")
    later:SetWidth(150)
    later:SetHeight(24)
    later:SetPoint("BOTTOMRIGHT", updatePopup, "BOTTOMRIGHT", -45, 18)
    later:SetText("PLUS TARD")
    later:SetScript("OnClick", function() updatePopup:Hide() end)
    updatePopup:Hide()

    if UISpecialFrames then table.insert(UISpecialFrames, "CoARotationGuideFrame") end
    RestorePosition()
end

local function PrintStatus()
    BuildGuide()
    Chat(tostring(currentCharacter.className) .. " - " .. tostring(currentCharacter.specName)
        .. ", niveau " .. tostring(currentCharacter.level)
        .. ", " .. tostring(#spellOrder) .. " sorts, " .. tostring(math.max(#activeTalentList, adaptiveTalentCount)) .. " talents (" .. tostring(activeTalentSource) .. ").")
    Chat("Contexte " .. tostring(CoARotationGuideDB.content) .. "/" .. tostring(CoARotationGuideDB.context)
        .. " ; profil " .. tostring(currentGuide and currentGuide.profileKey or "inconnu") .. ".")
end

local function SlashHandler(message)
    EnsureDatabase()
    local command = Lower(Trim(message))
    if command == "" or command == "show" or command == "open" then
        ToggleGuide()
    elseif command == "scan" or command == "refresh" then
        FullScan(false, "commande manuelle")
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
    elseif command == "progression" or command == "progres" or command == "stuff" then
        guidePage = 1; viewMode = "PROGRESSION"; FullScan(true, "commande progression"); guideFrame:Show()
    elseif command == "actus" or command == "updates" or command == "maj" then
        OpenUpdatePage()
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
        Chat("/rotation | comprendre | pourquoi | situations | progression | actus | scan | status | st | aoe | solo | groupe | sources | minimap | reset")
    end
end

CoARotationGuideAPI = CoARotationGuideAPI or {}
function CoARotationGuideAPI:Toggle() ToggleGuide() end
function CoARotationGuideAPI:Show()
    if guideFrame and not guideFrame:IsShown() then FullScan(true, "ouverture API"); guideFrame:Show() end
end
function CoARotationGuideAPI:SetHubManaged(value)
    hubManaged = value and true or false
    UpdateMinimapVisibility()
end
function CoARotationGuideAPI:Refresh() FullScan(true, "actualisation API") end

SLASH_COAROTATIONGUIDE1 = "/rotation"
SLASH_COAROTATIONGUIDE2 = "/crg"
SlashCmdList.COAROTATIONGUIDE = SlashHandler

BuildInterface()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
if eventFrame.RegisterEvent then
    pcall(eventFrame.RegisterEvent, eventFrame, "CHARACTER_POINTS_CHANGED")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT")
    pcall(eventFrame.RegisterEvent, eventFrame, "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED")
end
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        EnsureDatabase()
        RestorePosition()
        BuildMinimapButton()
        ScheduleScan(0.6, "chargement de l'addon", 1)
    elseif event == "ADDON_LOADED" then
        if CoAUIManagerPanel then hubManaged = true; UpdateMinimapVisibility() end
    elseif event == "PLAYER_LOGIN" then
        if CoAUIManagerPanel then hubManaged = true end
        PositionMinimapButton()
        UpdateMinimapVisibility()
        ScheduleScan(0.8, "connexion du personnage", 2)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ScheduleScan(0.7, "entree dans le monde", 1)
    elseif event == "PLAYER_LEVEL_UP" then
        ScheduleScan(0.35, "gain de niveau", 2)
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        ScheduleScan(0.35, "spellbook modifie", 2)
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "CHARACTER_POINTS_CHANGED"
        or event == "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT"
        or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED"
    then
        ScheduleScan(0.35, "talents ou specialisation modifies", 2)
    else
        ScheduleScan(0.45, tostring(event), 1)
    end
end)
eventFrame:SetScript("OnUpdate", function()
    local now = GetTime and GetTime() or 0
    if scheduledScanAt and now >= scheduledScanAt then
        local reason = scheduledScanReason or "changement detecte"
        local remainingPasses = scheduledScanPasses or 0
        scheduledScanAt = nil
        scheduledScanReason = nil
        scheduledScanPasses = 0
        FullScan(true, reason)
        if remainingPasses > 0 then
            local delay = remainingPasses > 1 and 1.25 or 2.5
            ScheduleScan(delay, reason .. " - verification", remainingPasses - 1)
        end
    elseif now >= monitorAt then
        monitorAt = now + 4
        local fingerprint = CharacterFingerprint()
        if lastCharacterFingerprint and fingerprint ~= lastCharacterFingerprint then
            ScheduleScan(0.15, "evolution detectee automatiquement", 1)
        elseif not lastCharacterFingerprint then
            lastCharacterFingerprint = fingerprint
        end
    end
end)
