-- Loot Advisor for Warmane Icecrown / WotLK 3.3.5a.
-- Loaded after CoALootDecider.lua and intentionally uses only Lua 5.1 APIs.

local api = CoALootDeciderAPI
if not api then return end

local REFRESH_DELAY = 0.40
local PAINTS_PER_FRAME = 4
local MAX_BAG_BUTTONS = 36
local MAX_CONTAINER_FRAMES = 13
local MERCHANT_PAGE_SIZE = 10
local LOOT_MINIMAP_DEFAULT_ANGLE = 2.75

local refreshPending = false
local refreshElapsed = 0
local bankOpen = false
local merchantOpen = false
local overlays = {}
local tooltipHooks = {}
local analysisCache = {}
local visibilityHooks = {}
local adiBagsHooked = false
local adiBagsListener = {}
local minimapButton = nil
local profileRefreshPending = false
local bagRefreshPending = false
local paintQueue = {}
local paintIndex = 1
local windowRefreshPending = false

local SLOT_NAMES = {
    INVTYPE_HEAD = "Tete",
    INVTYPE_NECK = "Cou",
    INVTYPE_SHOULDER = "Epaules",
    INVTYPE_BODY = "Chemise",
    INVTYPE_CHEST = "Torse",
    INVTYPE_ROBE = "Torse",
    INVTYPE_WAIST = "Ceinture",
    INVTYPE_LEGS = "Jambes",
    INVTYPE_FEET = "Pieds",
    INVTYPE_WRIST = "Poignets",
    INVTYPE_HAND = "Mains",
    INVTYPE_FINGER = "Anneau",
    INVTYPE_TRINKET = "Bijou",
    INVTYPE_CLOAK = "Dos",
    INVTYPE_WEAPON = "Arme 1M",
    INVTYPE_SHIELD = "Bouclier",
    INVTYPE_2HWEAPON = "Arme 2M",
    INVTYPE_WEAPONMAINHAND = "Main droite",
    INVTYPE_WEAPONOFFHAND = "Main gauche",
    INVTYPE_HOLDABLE = "Tenu en main gauche",
    INVTYPE_RANGED = "Distance",
    INVTYPE_RANGEDRIGHT = "Distance",
    INVTYPE_THROWN = "Arme de jet",
    INVTYPE_RELIC = "Relique",
    INVTYPE_BAG = "Sac"
}

local SLOT_ORDER = {
    "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
    "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
    "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER",
    "INVTYPE_TRINKET", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
    "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD",
    "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN", "INVTYPE_RELIC", "INVTYPE_BAG"
}

local SLOT_RANK = {}
local orderIndex, orderKey
for orderIndex, orderKey in ipairs(SLOT_ORDER) do SLOT_RANK[orderKey] = orderIndex end

local SLOT_GROUP = {
    INVTYPE_ROBE = "INVTYPE_CHEST",
    INVTYPE_RANGEDRIGHT = "INVTYPE_RANGED",
    INVTYPE_THROWN = "INVTYPE_RANGED"
}

local function EnsureSettings()
    CoALootDeciderDB = CoALootDeciderDB or {}
    CoALootDeciderDB.advisor = CoALootDeciderDB.advisor or {}
    CoALootDeciderDB.minimap = CoALootDeciderDB.minimap or {}
    if type(CoALootDeciderDB.minimap.angle) ~= "number" then
        CoALootDeciderDB.minimap.angle = LOOT_MINIMAP_DEFAULT_ANGLE
    end
    if type(CoALootDeciderDB.minimap.hidden) ~= "boolean" then
        CoALootDeciderDB.minimap.hidden = false
    end
    local settings = CoALootDeciderDB.advisor
    if settings.enabled == nil then settings.enabled = true end
    if settings.visualVersion ~= 3 then settings.visualVersion = 3 end
    if settings.showDowngrades == nil then settings.showDowngrades = false end
    if settings.showAllCandidates == nil then settings.showAllCandidates = false end
    if settings.tooltip == nil then settings.tooltip = true end
    if settings.sortMode ~= "slot" and settings.sortMode ~= "gain" then settings.sortMode = "gain" end
    if settings.viewMode ~= "gear" and settings.viewMode ~= "history" then settings.viewMode = "gear" end
    return settings
end

local function ShortPercent(value)
    value = tonumber(value) or 0
    if value > 99 then return "+99%" end
    if value < -99 then return "-99%" end
    if value > 0 then return "+" .. api.Round(value, 0) .. "%" end
    return api.Round(value, 0) .. "%"
end

local function Analyze(link, excludeOwnedCopy)
    if not link then return nil end
    local settings = EnsureSettings()
    if not settings.enabled then return nil end
    local cacheKey = tostring(link) .. (excludeOwnedCopy and ":owned" or ":external")
    if analysisCache[cacheKey] then return analysisCache[cacheKey] end
    local analysis = api.AnalyzeItem(link, false, excludeOwnedCopy and true or false)
    if analysis then analysisCache[cacheKey] = analysis end
    return analysis
end

local function EnsureOverlay(button)
    if not button then return nil end
    if overlays[button] then return overlays[button] end

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel((button.GetFrameLevel and button:GetFrameLevel() or 1) + 8)
    overlay:EnableMouse(false)

    overlay.border = overlay:CreateTexture(nil, "OVERLAY")
    overlay.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    overlay.border:SetBlendMode("ADD")
    overlay.border:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    overlay.border:SetWidth(42)
    overlay.border:SetHeight(42)

    overlay.marker = CreateFrame("Frame", nil, overlay)
    overlay.marker:SetWidth(15)
    overlay.marker:SetHeight(15)
    overlay.marker:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 2, 2)
    overlay.markerBg = overlay.marker:CreateTexture(nil, "BACKGROUND")
    overlay.markerBg:SetAllPoints(overlay.marker)
    overlay.markerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    overlay.markerText = overlay.marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    overlay.markerText:SetPoint("CENTER", overlay.marker, "CENTER", 0, 0)
    overlay.markerText:SetTextColor(1, 1, 1)

    overlay.badge = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    overlay.badge:SetPoint("BOTTOM", overlay, "BOTTOM", 0, -1)
    overlay.badge:SetTextColor(1, 1, 1)

    overlay:Hide()
    overlays[button] = overlay
    return overlay
end

local function SetOverlayState(overlay, marker, percent, red, green, blue)
    overlay.border:SetVertexColor(red, green, blue)
    overlay.markerBg:SetVertexColor(red * 0.45, green * 0.45, blue * 0.45, 0.95)
    overlay.markerText:SetText(marker)
    overlay.badge:SetText(percent or "")
    overlay:Show()
end

local function PaintButton(button, link, excludeOwnedCopy)
    local overlay = EnsureOverlay(button)
    if not overlay then return end
    overlay:Hide()
    if not link then return end

    local analysis = Analyze(link, excludeOwnedCopy)
    if not analysis or (analysis.nonEquipable and not analysis.lockedChest) then return end
    if analysis.lockedChest then
        SetOverlayState(overlay, "+", "COFFRE", 0.20, 0.75, 1.00)
        return
    end
    if analysis.manual then
        SetOverlayState(overlay, "?", "", 1.00, 0.75, 0.10)
        return
    end
    if not analysis.candidateScore then
        if analysis.incompatible and EnsureSettings().showDowngrades then
            SetOverlayState(overlay, "x", "", 0.95, 0.20, 0.20)
        end
        return
    end
    if analysis.forcedDowngrade then
        if EnsureSettings().showDowngrades then
            SetOverlayState(overlay, "-", "DPS", 1.00, 0.18, 0.18)
        end
        return
    end

    if analysis.need then
        local badge = analysis.bagUpgrade and ("+" .. tostring(analysis.slotGain or 0))
            or ShortPercent(analysis.percent)
        SetOverlayState(overlay, "+", badge, 0.15, 1.00, 0.25)
    elseif (tonumber(analysis.percent) or 0) > 0 then
        SetOverlayState(overlay, "~", ShortPercent(analysis.percent), 1.00, 0.75, 0.10)
    elseif EnsureSettings().showDowngrades and (tonumber(analysis.percent) or 0) < -0.5 then
        SetOverlayState(overlay, "-", ShortPercent(analysis.percent), 1.00, 0.18, 0.18)
    else
        return
    end
end

local function QueuePaint(button, link, excludeOwnedCopy)
    if not button then return end
    local overlay = EnsureOverlay(button)
    if overlay then overlay:Hide() end
    table.insert(paintQueue, {
        button = button,
        link = link,
        excludeOwnedCopy = excludeOwnedCopy and true or false
    })
end

local function UpdateBagButtons()
    local frameIndex, itemIndex
    for frameIndex = 1, MAX_CONTAINER_FRAMES do
        local container = _G["ContainerFrame" .. frameIndex]
        if container and (not container.IsShown or container:IsShown()) then
            for itemIndex = 1, MAX_BAG_BUTTONS do
                local button = _G["ContainerFrame" .. frameIndex .. "Item" .. itemIndex]
                if button then
                    local bag = container.GetID and container:GetID() or nil
                    local slot = button.GetID and button:GetID() or nil
                    local link = bag and slot and GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
                    QueuePaint(button, link, true)
                end
            end
        end
    end
end

local function MerchantIndex(buttonIndex)
    local page = MerchantFrame and tonumber(MerchantFrame.page) or 1
    return ((page or 1) - 1) * MERCHANT_PAGE_SIZE + buttonIndex
end

local function UpdateMerchantButtons()
    local buttonIndex
    for buttonIndex = 1, MERCHANT_PAGE_SIZE do
        local button = _G["MerchantItem" .. buttonIndex .. "ItemButton"]
        local link = merchantOpen and GetMerchantItemLink
            and GetMerchantItemLink(MerchantIndex(buttonIndex)) or nil
        if button then QueuePaint(button, link, false) end
    end
end

local function UpdateLootButtons()
    local index
    for index = 1, 8 do
        local button = _G["LootButton" .. index]
        local slot = button and button.GetID and button:GetID() or index
        local link = button and GetLootSlotLink and GetLootSlotLink(slot) or nil
        if button then QueuePaint(button, link, false) end
    end
end

local function WeightedStatDifferences(analysis)
    local result = {}
    local profile = api.GetProfile()
    local display = api.GetDisplayStats()
    if not profile or not profile.weights then return result end

    local seen = {}
    local key, weight
    for key, weight in pairs(profile.weights) do
        if weight > 0 and not seen[key] then
            seen[key] = true
            local candidateValue = tonumber(analysis.candidate.stats and analysis.candidate.stats[key]) or 0
            local currentValue = tonumber(analysis.currentStats and analysis.currentStats[key]) or 0
            local difference = candidateValue - currentValue
            if difference ~= 0 then
                table.insert(result, {
                    key = key,
                    name = display[key] or key,
                    value = difference,
                    weight = weight,
                    weighted = difference * weight,
                    impact = math.abs(difference * weight)
                })
            end
        end
    end
    table.sort(result, function(left, right) return left.impact > right.impact end)
    return result
end

local function IgnoredCandidateStats(analysis)
    local result = {}
    local profile = api.GetProfile()
    local display = api.GetDisplayStats()
    if not profile or not profile.weights or not analysis or not analysis.candidate then return result end
    local key, value
    for key, value in pairs(analysis.candidate.stats or {}) do
        value = tonumber(value) or 0
        if value > 0 and (tonumber(profile.weights[key]) or 0) <= 0 then
            table.insert(result, (display[key] or key) .. " " .. tostring(value))
        end
    end
    table.sort(result)
    return result
end

local function TooltipOwnedBagItem(link)
    if not link or type(GetMouseFocus) ~= "function" then return false end
    local focus = GetMouseFocus()
    if not focus or not focus.GetID or not focus.GetParent then return false end
    local parent = focus:GetParent()
    local bag = focus.bag or (parent and parent.GetID and parent:GetID() or nil)
    local slot = focus.slot or focus:GetID()
    if bag == nil or slot == nil or type(GetContainerItemLink) ~= "function" then return false end
    local ok, focusedLink = pcall(GetContainerItemLink, bag, slot)
    return ok and focusedLink == link
end

local function AddTooltipAnalysis(tooltip)
    local settings = EnsureSettings()
    if not settings.enabled or not settings.tooltip then return end
    if tooltip.CoALootAdvisorBusy then return end
    if type(tooltip.GetItem) ~= "function" then return end

    local _, link = tooltip:GetItem()
    local detailed = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() or false
    if not link or (tooltip.CoALootAdvisorLink == link
        and tooltip.CoALootAdvisorDetailed == detailed) then return end
    tooltip.CoALootAdvisorBusy = true
    local analysis = Analyze(link, TooltipOwnedBagItem(link))
    if not analysis then
        tooltip.CoALootAdvisorBusy = false
        return
    end
    if analysis.nonEquipable and not analysis.lockedChest then
        tooltip.CoALootAdvisorBusy = false
        return
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Loot Advisor - Warmane", 0.40, 0.85, 1.00)
    local profile = api.GetProfile()
    if profile and profile.valid then
        tooltip:AddLine(profile.className .. " - " .. profile.specName, 0.70, 0.70, 0.70)
        if profile.adaptive then
            tooltip:AddLine("Profil adaptatif : " .. tostring(profile.adaptive.confidence or "basse")
                .. " ; " .. tostring(profile.adaptive.selectedCount or 0) .. " talents ; niveau "
                .. tostring(profile.adaptive.level or "?"), 0.45, 0.82, 1.00)
        end
    end

    if analysis.lockedChest then
        local verdict = analysis.need and "À RÉCUPÉRER" or "RÈGLE COFFRE DÉSACTIVÉE"
        tooltip:AddLine(verdict, analysis.need and 0.20 or 1.00, analysis.need and 1.00 or 0.35, 0.35)
        tooltip:AddLine(analysis.reason or "Coffre verrouillé", 0.65, 0.82, 1.00, true)
    elseif analysis.manual then
        tooltip:AddDoubleLine("VERIFICATION MANUELLE", ShortPercent(analysis.percent),
            1.00, 0.75, 0.10, 1.00, 0.75, 0.10)
        tooltip:AddLine(analysis.reason or "Effet non chiffre", 1.00, 0.82, 0.35, true)
    elseif analysis.bagUpgrade and analysis.candidateScore then
        local gain = tonumber(analysis.slotGain) or 0
        local verdict = gain > 0 and "SAC PLUS GRAND" or (gain == 0 and "CAPACITÉ IDENTIQUE" or "SAC PLUS PETIT")
        local red, green, blue = gain > 0 and 0.20 or 1.00, gain > 0 and 1.00 or 0.55, gain > 0 and 0.30 or 0.25
        tooltip:AddDoubleLine(verdict, (gain > 0 and "+" or "") .. tostring(gain) .. " place(s)",
            red, green, blue, red, green, blue)
        tooltip:AddDoubleLine("Capacité", tostring(analysis.bagCapacity or 0)
            .. " contre " .. tostring(analysis.currentBagCapacity or 0), 0.80, 0.85, 0.95, 1, 1, 1)
    elseif not analysis.candidateScore then
        tooltip:AddLine("INCOMPATIBLE", 1.00, 0.20, 0.20)
        tooltip:AddLine(analysis.reason or "Comparaison impossible", 1.00, 0.55, 0.55, true)
        if profile and profile.armorRule then
            tooltip:AddDoubleLine("Armure attendue", tostring(profile.armorRule.label),
                0.75, 0.75, 0.75, 0.95, 0.95, 0.95)
        end
    else
        local positive = analysis.need
        local partial = not positive and not analysis.forcedDowngrade
            and (tonumber(analysis.percent) or 0) > 0
        local red, green, blue = 1.00, 0.25, 0.25
        local verdict = analysis.forcedDowngrade and "DPS ARME TROP FAIBLE" or "MOINS BON"
        if positive then
            red, green, blue = 0.20, 1.00, 0.30
            verdict = "AMELIORATION"
        elseif partial then
            red, green, blue = 1.00, 0.75, 0.10
            verdict = "GAIN SOUS LE SEUIL"
        elseif math.abs(tonumber(analysis.percent) or 0) < 0.5 then
            red, green, blue = 0.75, 0.75, 0.75
            verdict = "EQUIVALENT"
        end
        tooltip:AddDoubleLine(verdict, ShortPercent(analysis.percent),
            red, green, blue, red, green, blue)
        tooltip:AddDoubleLine("Score", api.Round(analysis.candidateScore, 1)
            .. "  /  " .. api.Round(analysis.currentScore, 1), 0.85, 0.85, 0.85, 1, 1, 1)
    end

    if analysis.currentLink then
        tooltip:AddLine("Remplace : " .. analysis.currentLink, 0.75, 0.75, 0.75)
    elseif analysis.bagUpgrade and analysis.candidateScore and not analysis.manual
        and tonumber(analysis.currentBagCapacity) == 0 then
        tooltip:AddLine("Remplit un emplacement de sac disponible", 0.20, 1.00, 0.30)
    elseif analysis.candidateScore then
        tooltip:AddLine("Emplacement actuellement vide", 0.20, 1.00, 0.30)
    end

    if analysis.candidateScore and not analysis.bagUpgrade then
        tooltip:AddDoubleLine("Adequation", tostring(analysis.fitScore or 0) .. "/100 "
                .. tostring(analysis.fitTier or ""),
            0.70, 0.82, 1.00, 0.85, 0.90, 1.00)
        if analysis.armorRuleLabel then
            tooltip:AddDoubleLine("Armure attendue", tostring(analysis.armorRuleLabel),
                0.75, 0.75, 0.75, 0.95, 0.95, 0.95)
        end
        if analysis.primaryFitScore ~= nil and tonumber(analysis.primaryFitScore) < 55 then
            tooltip:AddDoubleLine("Affinite stat principale", tostring(analysis.primaryFitScore) .. "/100",
                0.75, 0.75, 0.75, 1.00, 0.75, 0.10)
        end
        local differences = WeightedStatDifferences(analysis)
        local parts = {}
        local index, stat
        for index, stat in ipairs(differences) do
            if index > 4 then break end
            local prefix = stat.value > 0 and "+" or ""
            table.insert(parts, prefix .. stat.value .. " " .. stat.name)
        end
        if #parts > 0 then
            tooltip:AddLine("Ce qui change : " .. table.concat(parts, "  "), 0.82, 0.82, 0.82, true)
        end
        tooltip:AddLine("Pourquoi : " .. tostring(analysis.reason or "comparaison par statistiques utiles"),
            0.65, 0.88, 1.00, true)
        tooltip:AddLine("Confiance : " .. tostring(analysis.confidence or "inconnue"), 0.55, 0.75, 0.90)

        if detailed then
            tooltip:AddLine(" ")
            tooltip:AddLine("Détail du calcul", 1.00, 0.82, 0.20)
            local detailIndex, stat
            for detailIndex, stat in ipairs(differences) do
                if detailIndex > 6 then break end
                local prefix = stat.value > 0 and "+" or ""
                local weightedPrefix = stat.weighted > 0 and "+" or ""
                tooltip:AddDoubleLine(prefix .. stat.value .. " " .. stat.name,
                    "poids " .. api.Round(stat.weight, 2) .. " = " .. weightedPrefix
                        .. api.Round(stat.weighted, 1) .. " points",
                    stat.value > 0 and 0.35 or 1.00, stat.value > 0 and 1.00 or 0.35, 0.35,
                    0.78, 0.78, 0.78)
            end
            local ignored = IgnoredCandidateStats(analysis)
            if #ignored > 0 then
                local ignoredText = {}
                for detailIndex = 1, math.min(#ignored, 4) do table.insert(ignoredText, ignored[detailIndex]) end
                tooltip:AddLine("Non valorisé pour ta spé : " .. table.concat(ignoredText, ", "),
                    1.00, 0.55, 0.35, true)
            end
            tooltip:AddDoubleLine("Gain nécessaire pour NEED",
                tostring(api.Round(analysis.effectiveThreshold or analysis.threshold or 0, 1)) .. "%",
                0.70, 0.70, 0.70, 1.00, 0.82, 0.20)
        else
            tooltip:AddLine("Maintiens MAJ pour afficher le calcul détaillé.", 0.55, 0.75, 0.90)
        end
    elseif analysis.bagUpgrade and not analysis.manual then
        tooltip:AddLine("Pourquoi : " .. tostring(analysis.reason or "comparaison de capacité"),
            0.65, 0.88, 1.00, true)
    end

    tooltip.CoALootAdvisorLink = link
    tooltip.CoALootAdvisorDetailed = detailed
    tooltip.CoALootAdvisorBusy = false
    tooltip:Show()
end

-- Un hook de tooltip ne doit jamais pouvoir casser le tooltip natif. Certaines
-- versions 3.3.5 propagent les erreurs d'un HookScript jusque dans FrameXML ; on
-- libère donc toujours notre verrou sans effacer ni masquer le contenu du jeu.
local function SafeAddTooltipAnalysis(tooltip)
    local ok = pcall(AddTooltipAnalysis, tooltip)
    if not ok then
        tooltip.CoALootAdvisorBusy = nil
        tooltip.CoALootAdvisorLink = nil
        tooltip.CoALootAdvisorDetailed = nil
    end
end

local function ClearTooltipAnalysis(tooltip)
    tooltip.CoALootAdvisorLink = nil
    tooltip.CoALootAdvisorBusy = nil
    tooltip.CoALootAdvisorDetailed = nil
    tooltip.CoALootAdvisorDetailElapsed = nil
end

local function HookTooltip(tooltip)
    if not tooltip or tooltipHooks[tooltip] or not tooltip.HookScript then return end
    tooltip:HookScript("OnTooltipSetItem", SafeAddTooltipAnalysis)
    tooltip:HookScript("OnTooltipCleared", ClearTooltipAnalysis)
    tooltipHooks[tooltip] = true
end

local function HookAdiBags()
    if adiBagsHooked or not LibStub then return end
    local eventLibrary = LibStub("AceEvent-3.0", true) or LibStub("ABEvent-1.0", true)
    if not eventLibrary or type(eventLibrary.RegisterMessage) ~= "function" then return end
    local success = pcall(eventLibrary.RegisterMessage, adiBagsListener, "AdiBags_UpdateButton",
        function(_, button)
            if not button then return end
            local link = button.itemLink
            if not link and button.GetItemLink then link = button:GetItemLink() end
            if not link and button.bag and button.slot and GetContainerItemLink then
                link = GetContainerItemLink(button.bag, button.slot)
            end
            QueuePaint(button, link)
        end)
    adiBagsHooked = success and true or false
end

local function RequestRefresh()
    refreshPending = true
    refreshElapsed = 0
end

local function HookVisibility(frame)
    if not frame or visibilityHooks[frame] or not frame.HookScript then return end
    frame:HookScript("OnShow", RequestRefresh)
    visibilityHooks[frame] = true
end

local function HookSourceFrames()
    local frameIndex
    for frameIndex = 1, MAX_CONTAINER_FRAMES do HookVisibility(_G["ContainerFrame" .. frameIndex]) end
    HookVisibility(MerchantFrame)
    HookVisibility(LootFrame)
    HookVisibility(MerchantNextPageButton)
    HookVisibility(MerchantPrevPageButton)
    if MerchantNextPageButton and not visibilityHooks.MerchantNextPageClick then
        MerchantNextPageButton:HookScript("OnClick", RequestRefresh)
        visibilityHooks.MerchantNextPageClick = true
    end
    if MerchantPrevPageButton and not visibilityHooks.MerchantPrevPageClick then
        MerchantPrevPageButton:HookScript("OnClick", RequestRefresh)
        visibilityHooks.MerchantPrevPageClick = true
    end
end

local advisorWindow = CreateFrame("Frame", "CoALootAdvisorWindow", UIParent)
advisorWindow:SetWidth(620)
advisorWindow:SetHeight(455)
advisorWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
advisorWindow:SetFrameStrata("DIALOG")
advisorWindow:SetMovable(true)
advisorWindow:EnableMouse(true)
advisorWindow:RegisterForDrag("LeftButton")
advisorWindow:SetScript("OnDragStart", function(self) self:StartMoving() end)
advisorWindow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local centerX, centerY = self:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if centerX and centerY and parentX and parentY then
        local settings = EnsureSettings()
        settings.windowX = centerX - parentX
        settings.windowY = centerY - parentY
    end
end)
advisorWindow:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
advisorWindow:Hide()

advisorWindow.title = advisorWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
advisorWindow.title:SetPoint("TOP", advisorWindow, "TOP", 0, -15)
advisorWindow.title:SetText("Loot Decider • Warmane")

advisorWindow.close = CreateFrame("Button", nil, advisorWindow, "UIPanelCloseButton")
advisorWindow.close:SetPoint("TOPRIGHT", advisorWindow, "TOPRIGHT", -6, -6)

advisorWindow.profileTitle = advisorWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
advisorWindow.profileTitle:SetPoint("TOPLEFT", advisorWindow, "TOPLEFT", 22, -43)
advisorWindow.profileTitle:SetWidth(575)
advisorWindow.profileTitle:SetJustifyH("LEFT")
advisorWindow.profileTitle:SetTextColor(0.35, 0.88, 1.00)

advisorWindow.status = advisorWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
advisorWindow.status:SetPoint("TOPLEFT", advisorWindow, "TOPLEFT", 22, -62)
advisorWindow.status:SetWidth(575)
advisorWindow.status:SetJustifyH("LEFT")

advisorWindow.rows = {}
local rowIndex
for rowIndex = 1, 13 do
    local row = CreateFrame("Button", nil, advisorWindow)
    row:SetWidth(575)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", advisorWindow, "TOPLEFT", 22, -86 - ((rowIndex - 1) * 24))

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints(row)
    row.background:SetTexture("Interface\\Buttons\\WHITE8X8")
    if rowIndex % 2 == 0 then
        row.background:SetVertexColor(0.08, 0.16, 0.22, 0.32)
    else
        row.background:SetVertexColor(0.02, 0.05, 0.08, 0.18)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(20)
    row.icon:SetHeight(20)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.slot:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.slot:SetWidth(82)
    row.slot:SetJustifyH("LEFT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.slot, "RIGHT", 3, 0)
    row.name:SetWidth(310)
    row.name:SetJustifyH("LEFT")

    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.source:SetPoint("LEFT", row.name, "RIGHT", 3, 0)
    row.source:SetWidth(80)
    row.source:SetJustifyH("LEFT")

    row.delta = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.delta:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.delta:SetWidth(70)
    row.delta:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        if not self.itemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        if self.historyEntry then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Décision enregistrée", 0.40, 0.85, 1.00)
            GameTooltip:AddDoubleLine(tostring(self.historyEntry.decision or "?"),
                self.historyEntry.automatic and "Automatique" or "Conseil",
                1.00, 0.82, 0.20, 0.70, 0.70, 0.70)
            if self.historyEntry.reason then GameTooltip:AddLine(self.historyEntry.reason, 0.82, 0.82, 0.82, true) end
            if self.historyEntry.confidence then
                GameTooltip:AddLine("Confiance : " .. tostring(self.historyEntry.confidence), 0.55, 0.75, 0.90)
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.itemLink and HandleModifiedItemClick then HandleModifiedItemClick(self.itemLink) end
    end)
    row:Hide()
    advisorWindow.rows[rowIndex] = row
end

advisorWindow.refresh = CreateFrame("Button", nil, advisorWindow, "UIPanelButtonTemplate")
advisorWindow.refresh:SetWidth(120)
advisorWindow.refresh:SetHeight(24)
advisorWindow.refresh:SetPoint("BOTTOMLEFT", advisorWindow, "BOTTOMLEFT", 22, 18)
advisorWindow.refresh:SetText("Actualiser")

advisorWindow.mode = CreateFrame("Button", nil, advisorWindow, "UIPanelButtonTemplate")
advisorWindow.mode:SetWidth(130)
advisorWindow.mode:SetHeight(24)
advisorWindow.mode:SetPoint("LEFT", advisorWindow.refresh, "RIGHT", 8, 0)
advisorWindow.mode:SetText("Voir tout")

advisorWindow.sort = CreateFrame("Button", nil, advisorWindow, "UIPanelButtonTemplate")
advisorWindow.sort:SetWidth(105)
advisorWindow.sort:SetHeight(24)
advisorWindow.sort:SetPoint("LEFT", advisorWindow.mode, "RIGHT", 8, 0)
advisorWindow.sort:SetText("Tri : gain")

advisorWindow.history = CreateFrame("Button", nil, advisorWindow, "UIPanelButtonTemplate")
advisorWindow.history:SetWidth(105)
advisorWindow.history:SetHeight(24)
advisorWindow.history:SetPoint("LEFT", advisorWindow.sort, "RIGHT", 8, 0)
advisorWindow.history:SetText("Historique")

advisorWindow.hint = advisorWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
advisorWindow.hint:SetPoint("BOTTOMRIGHT", advisorWindow, "BOTTOMRIGHT", -22, 52)
advisorWindow.hint:SetText("+ amélioration  •  ~ situationnel  •  ? manuel")

local function AddCandidate(best, link, source)
    local analysis = Analyze(link, source == "Sacs")
    if not analysis or not analysis.candidate or not analysis.candidateScore then return end
    local equipLoc = analysis.candidate.equipLoc
    if not SLOT_NAMES[equipLoc] then return end
    local group = SLOT_GROUP[equipLoc] or equipLoc
    local existing = best[group]
    if not existing or analysis.candidateScore > existing.analysis.candidateScore then
        best[group] = { analysis = analysis, source = source, group = group }
    end
end

local function ScanContainer(best, bag, source)
    if not GetContainerNumSlots or not GetContainerItemLink then return end
    local slots = tonumber(GetContainerNumSlots(bag)) or 0
    local slot
    for slot = 1, slots do AddCandidate(best, GetContainerItemLink(bag, slot), source) end
end

local function CollectBestCandidates()
    local best = {}
    local bag
    for bag = 0, (NUM_BAG_SLOTS or 4) do ScanContainer(best, bag, "Sacs") end

    if bankOpen then
        ScanContainer(best, -1, "Banque")
        local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
        local lastBankBag = firstBankBag + (NUM_BANKBAGSLOTS or 7) - 1
        for bag = firstBankBag, lastBankBag do ScanContainer(best, bag, "Banque") end
    end

    if merchantOpen and GetMerchantNumItems and GetMerchantItemLink then
        local merchantIndex
        for merchantIndex = 1, (tonumber(GetMerchantNumItems()) or 0) do
            AddCandidate(best, GetMerchantItemLink(merchantIndex), "Marchand")
        end
    end

    local result = {}
    local equipLoc, entry
    for equipLoc, entry in pairs(best) do table.insert(result, entry) end
    local settings = EnsureSettings()
    table.sort(result, function(left, right)
        if settings.sortMode == "gain" then
            local leftGain = tonumber(left.analysis.percent) or -999
            local rightGain = tonumber(right.analysis.percent) or -999
            if leftGain ~= rightGain then return leftGain > rightGain end
        end
        local leftRank = SLOT_RANK[left.group] or 99
        local rightRank = SLOT_RANK[right.group] or 99
        if leftRank == rightRank then
            return (left.analysis.percent or -999) > (right.analysis.percent or -999)
        end
        return leftRank < rightRank
    end)
    return result
end

local function FormatHistoryTime(entry)
    local timestamp = tonumber(entry and entry.at) or 0
    if timestamp > 0 and date then return date("%d/%m %H:%M", timestamp) end
    return "Ancien"
end

local function RefreshHistoryWindow(profile)
    local history = CoALootDeciderDB and CoALootDeciderDB.history or {}
    advisorWindow.profileTitle:SetText(profile and profile.valid
        and (profile.className .. "  •  " .. profile.specName .. "  •  historique des décisions")
        or "Historique Loot Decider")
    advisorWindow.status:SetText(tostring(#history) .. " décision(s) conservée(s)  •  survolez une ligne pour la raison complète")
    advisorWindow.mode:Hide()
    advisorWindow.sort:Hide()
    advisorWindow.history:SetText("Retour objets")
    advisorWindow.hint:SetText("Historique des NEED/PASS et conseils manuels")

    local index, row
    for index, row in ipairs(advisorWindow.rows) do
        local entry = history[index]
        if entry then
            local texture = nil
            if GetItemInfo then
                local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(entry.itemLink or "")
                texture = itemTexture
            end
            row.itemLink = entry.itemLink
            row.historyEntry = entry
            row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.slot:SetText(FormatHistoryTime(entry))
            row.name:SetText(entry.itemLink or entry.itemName or "Objet inconnu")
            row.source:SetText(entry.automatic and "AUTO" or "CONSEIL")
            local percent = tonumber(entry.percent)
            local suffix = percent and (" " .. ShortPercent(percent)) or ""
            if entry.decision == "NEED" then
                row.delta:SetText("|cff33ff4c+ NEED" .. suffix .. "|r")
            elseif entry.decision == "GREED" then
                row.delta:SetText("|cff55aaff+ CUPIDITÉ" .. suffix .. "|r")
            elseif entry.decision == "PASS" then
                row.delta:SetText("|cffff5b5b- PASS" .. suffix .. "|r")
            else
                row.delta:SetText("|cffffbf19? MANUEL|r")
            end
            row:Show()
        else
            row.itemLink = nil
            row.historyEntry = nil
            row:Hide()
        end
    end
end

local function RefreshWindow()
    if not advisorWindow:IsVisible() then return end
    local allResults = CollectBestCandidates()
    local profile = api.GetProfile()
    local settings = EnsureSettings()
    if settings.viewMode == "history" then
        RefreshHistoryWindow(profile)
        return
    end
    advisorWindow.mode:Show()
    advisorWindow.sort:Show()
    advisorWindow.history:SetText("Historique")
    advisorWindow.hint:SetText("+ amélioration  •  ~ situationnel  •  ? manuel")
    local sourceText = merchantOpen and "sacs + marchand" or "sacs"
    if bankOpen then sourceText = sourceText .. " + banque" end
    local result = {}
    local _, candidateEntry
    for _, candidateEntry in ipairs(allResults) do
        local analysis = candidateEntry.analysis
        if settings.showAllCandidates or analysis.need or analysis.manual
            or (tonumber(analysis.percent) or 0) > 0 then
            table.insert(result, candidateEntry)
        end
    end
    local confidence = profile and profile.adaptive and profile.adaptive.confidence or "standard"
    local talentCount = profile and profile.adaptive and profile.adaptive.selectedCount or 0
    local level = profile and profile.adaptive and profile.adaptive.level or (UnitLevel and UnitLevel("player")) or "?"
    advisorWindow.profileTitle:SetText(profile and profile.valid
        and (profile.className .. "  •  " .. profile.specName .. "  •  niveau " .. tostring(level))
        or "Profil WotLK indisponible")
    local manualCount = 0
    local topGain = nil
    for _, candidateEntry in ipairs(result) do
        if candidateEntry.analysis.manual then manualCount = manualCount + 1 end
        local gain = tonumber(candidateEntry.analysis.percent)
        if gain and (not topGain or gain > topGain) then topGain = gain end
    end
    advisorWindow.status:SetText("Confiance " .. tostring(confidence)
        .. "  •  " .. tostring(talentCount) .. " talents détectés"
        .. "  •  " .. sourceText
        .. "  •  " .. tostring(#result) .. (settings.showAllCandidates and " objet(s)" or " candidat(s) utile(s)")
        .. (topGain and ("  •  meilleur " .. ShortPercent(topGain)) or "")
        .. (manualCount > 0 and ("  •  " .. tostring(manualCount) .. " manuel(s)") or ""))
    advisorWindow.mode:SetText(settings.showAllCandidates and "Améliorations" or "Voir tout")
    advisorWindow.sort:SetText(settings.sortMode == "gain" and "Tri : gain" or "Tri : slot")

    local index, row
    for index, row in ipairs(advisorWindow.rows) do
        local entry = result[index]
        if entry then
            local analysis = entry.analysis
            local candidate = analysis.candidate
            row.itemLink = candidate.link
            row.historyEntry = nil
            row.icon:SetTexture(candidate.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.slot:SetText(SLOT_NAMES[candidate.equipLoc] or candidate.equipLoc)
            row.name:SetText(candidate.link or candidate.name)
            row.source:SetText(entry.source)
            if analysis.manual then
                row.delta:SetText("|cffffbf19? MANUEL|r")
            elseif analysis.need then
                local gainText = analysis.bagUpgrade and ("+" .. tostring(analysis.slotGain or 0) .. " places")
                    or ShortPercent(analysis.percent)
                row.delta:SetText("|cff33ff4c+ " .. gainText .. "|r")
            elseif (analysis.percent or 0) > 0 then
                row.delta:SetText("|cffffbf19~ " .. ShortPercent(analysis.percent) .. "|r")
            else
                row.delta:SetText("|cffff4040- " .. ShortPercent(analysis.percent) .. "|r")
            end
            row:Show()
        else
            row.itemLink = nil
            row:Hide()
        end
    end
    if #result == 0 then
        advisorWindow.status:SetText(advisorWindow.status:GetText() .. " | aucun objet equipable analyse")
    end
end

advisorWindow.refresh:SetScript("OnClick", function()
    bagRefreshPending = true
    RequestRefresh()
end)
advisorWindow.mode:SetScript("OnClick", function()
    local settings = EnsureSettings()
    settings.showAllCandidates = not settings.showAllCandidates
    RequestRefresh()
end)
advisorWindow.sort:SetScript("OnClick", function()
    local settings = EnsureSettings()
    settings.sortMode = settings.sortMode == "gain" and "slot" or "gain"
    RequestRefresh()
end)
advisorWindow.history:SetScript("OnClick", function()
    local settings = EnsureSettings()
    settings.viewMode = settings.viewMode == "history" and "gear" or "history"
    RefreshWindow()
end)

local function PositionAdvisorWindow()
    local settings = EnsureSettings()
    advisorWindow:ClearAllPoints()
    advisorWindow:SetPoint("CENTER", UIParent, "CENTER",
        tonumber(settings.windowX) or 0, tonumber(settings.windowY) or 0)
end

function CoALootAdvisor_Toggle()
    EnsureSettings()
    if advisorWindow:IsVisible() then
        advisorWindow:Hide()
    else
        EnsureSettings().viewMode = "gear"
        PositionAdvisorWindow()
        advisorWindow:Show()
        advisorWindow.status:SetText("Analyse progressive des objets…")
        RequestRefresh()
    end
end

function CoALootAdvisor_ShowHistory()
    EnsureSettings().viewMode = "history"
    PositionAdvisorWindow()
    advisorWindow:Show()
    RefreshWindow()
end

local function Atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function PositionLootMinimapButton()
    if not minimapButton then return end
    EnsureSettings()
    minimapButton:ClearAllPoints()
    if Minimap then
        local angle = CoALootDeciderDB.minimap.angle or LOOT_MINIMAP_DEFAULT_ANGLE
        local radius = 80
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    else
        minimapButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -250, -20)
    end
end

function CoALootAdvisor_SetMinimapVisible(visible)
    EnsureSettings()
    CoALootDeciderDB.minimap.hidden = not visible
    if minimapButton then
        if visible then
            PositionLootMinimapButton()
            minimapButton:Show()
        else
            minimapButton:Hide()
        end
    end
end

function CoALootAdvisor_ResetMinimapButton()
    EnsureSettings()
    CoALootDeciderDB.minimap.angle = LOOT_MINIMAP_DEFAULT_ANGLE
    CoALootDeciderDB.minimap.hidden = false
    PositionLootMinimapButton()
    if minimapButton then minimapButton:Show() end
end

local function BuildLootMinimapButton()
    if minimapButton then return end
    EnsureSettings()
    local iconWasDragged = false
    minimapButton = CreateFrame("Button", "CoALootDeciderMinimapButton", UIParent)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("HIGH")
    minimapButton:SetFrameLevel(30)
    minimapButton:SetClampedToScreen(true)
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(22)
    icon:SetHeight(22)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetWidth(52)
    border:SetHeight(52)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetWidth(32)
    highlight:SetHeight(32)
    highlight:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    minimapButton:SetScript("OnMouseDown", function() iconWasDragged = false end)
    minimapButton:SetScript("OnDragStart", function(self)
        iconWasDragged = true
        self:SetScript("OnUpdate", function()
            if not Minimap then return end
            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            local minimapX, minimapY = Minimap:GetCenter()
            if not minimapX or not minimapY then return end
            cursorX, cursorY = cursorX / scale, cursorY / scale
            CoALootDeciderDB.minimap.angle = Atan2(cursorY - minimapY, cursorX - minimapX)
            PositionLootMinimapButton()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        PositionLootMinimapButton()
    end)
    minimapButton:SetScript("OnClick", function(_, button)
        if iconWasDragged then
            iconWasDragged = false
            return
        end
        if button == "RightButton" then
            CoALootAdvisor_ShowHistory()
        else
            CoALootAdvisor_Toggle()
        end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Loot Decider • Warmane", 1, 0.82, 0.20)
        GameTooltip:AddLine("Clic gauche : ouvrir le comparateur de butin.", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : ouvrir l'historique.", 1, 1, 1)
        GameTooltip:AddLine("Survole un objet ; maintiens MAJ pour comprendre le calcul.", 0.45, 0.90, 1)
        GameTooltip:AddLine("Glisser : déplacer l'icône autour de la minicarte.", 0.65, 0.78, 1)
        GameTooltip:AddLine("/cld minimap hide pour masquer l'icône.", 0.65, 0.72, 0.80)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PositionLootMinimapButton()
    if CoALootDeciderDB.minimap.hidden then minimapButton:Hide() else minimapButton:Show() end
end

function CoALootAdvisor_ToggleVisuals()
    local settings = EnsureSettings()
    settings.enabled = not settings.enabled
    if not settings.enabled then
        local _, overlay
        for _, overlay in pairs(overlays) do overlay:Hide() end
    else
        refreshPending = true
    end
    return settings.enabled
end

function CoALootAdvisor_ToggleDowngrades()
    local settings = EnsureSettings()
    settings.showDowngrades = not settings.showDowngrades
    refreshPending = true
    return settings.showDowngrades
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event)
    EnsureSettings()
    if event == "PLAYER_LOGIN" then
        if not api.GetProfile() then api.RefreshProfile() end
        BuildLootMinimapButton()
        HookTooltip(GameTooltip)
        HookTooltip(ItemRefTooltip)
        HookTooltip(ShoppingTooltip1)
        HookTooltip(ShoppingTooltip2)
        HookAdiBags()
        HookSourceFrames()
    elseif event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_LEVEL_UP"
        or event == "SPELLS_CHANGED"
    then
        profileRefreshPending = true
    elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" then
        bagRefreshPending = true
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
    end
    RequestRefresh()
end)

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    if refreshPending then
        refreshElapsed = refreshElapsed + elapsed
        if refreshElapsed >= REFRESH_DELAY then
            refreshPending = false
            refreshElapsed = 0
            local invalidated = profileRefreshPending or bagRefreshPending
            if profileRefreshPending then
                -- Le moteur central fusionne deja ces evenements et termine son
                -- profil apres 0,30 s. Le delai visuel de 0,40 s reutilise ce
                -- resultat au lieu de refaire le meme scan une seconde fois.
                profileRefreshPending = false
                bagRefreshPending = false
            elseif bagRefreshPending and api.RefreshBagItems then
                api.RefreshBagItems()
                bagRefreshPending = false
            end
            if invalidated then
                analysisCache = {}
                local tooltip
                for tooltip in pairs(tooltipHooks) do tooltip.CoALootAdvisorLink = nil end
            end
            HookAdiBags()
            HookSourceFrames()
            paintQueue = {}
            paintIndex = 1
            UpdateBagButtons()
            UpdateMerchantButtons()
            UpdateLootButtons()
            windowRefreshPending = advisorWindow:IsVisible()
        end
    end

    -- Les analyses passent sur plusieurs images. Ouvrir un grand sac ou un
    -- marchand ne bloque plus toute l'interface pendant un scan monolithique.
    local painted = 0
    while paintIndex <= #paintQueue and painted < PAINTS_PER_FRAME do
        local job = paintQueue[paintIndex]
        paintIndex = paintIndex + 1
        painted = painted + 1
        if job and job.button then PaintButton(job.button, job.link, job.excludeOwnedCopy) end
    end
    if paintIndex > #paintQueue and #paintQueue > 0 then
        paintQueue = {}
        paintIndex = 1
        if windowRefreshPending then
            windowRefreshPending = false
            RefreshWindow()
        end
    elseif #paintQueue == 0 and windowRefreshPending then
        windowRefreshPending = false
        RefreshWindow()
    end
end)
