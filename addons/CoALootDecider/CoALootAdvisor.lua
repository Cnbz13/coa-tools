-- CoA Loot Advisor: universal item comparison UI for Project Ascension 3.3.5.
-- Loaded after CoALootDecider.lua and intentionally uses only Lua 5.1 APIs.

local api = CoALootDeciderAPI
if not api then return end

local REFRESH_DELAY = 0.20
local MAX_BAG_BUTTONS = 36
local MAX_CONTAINER_FRAMES = 13
local MERCHANT_PAGE_SIZE = 10

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
    INVTYPE_RELIC = "Relique"
}

local SLOT_ORDER = {
    "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
    "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND",
    "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER",
    "INVTYPE_TRINKET", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
    "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD",
    "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN", "INVTYPE_RELIC"
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
    if not analysis or analysis.nonEquipable then return end
    if not analysis.candidateScore then
        if analysis.candidate and analysis.candidate.equipLoc then
            SetOverlayState(overlay, "x", "", 0.95, 0.20, 0.20)
        end
        return
    end

    if analysis.manual then
        SetOverlayState(overlay, "?", "", 1.00, 0.75, 0.10)
    elseif analysis.need then
        SetOverlayState(overlay, "+", ShortPercent(analysis.percent), 0.15, 1.00, 0.25)
    elseif (tonumber(analysis.percent) or 0) > 0 then
        SetOverlayState(overlay, "~", ShortPercent(analysis.percent), 1.00, 0.75, 0.10)
    elseif EnsureSettings().showDowngrades and (tonumber(analysis.percent) or 0) < -0.5 then
        SetOverlayState(overlay, "-", ShortPercent(analysis.percent), 1.00, 0.18, 0.18)
    else
        return
    end
end

local function UpdateBagButtons()
    local frameIndex, itemIndex
    for frameIndex = 1, MAX_CONTAINER_FRAMES do
        local container = _G["ContainerFrame" .. frameIndex]
        if container then
            for itemIndex = 1, MAX_BAG_BUTTONS do
                local button = _G["ContainerFrame" .. frameIndex .. "Item" .. itemIndex]
                if button then
                    local bag = container.GetID and container:GetID() or nil
                    local slot = button.GetID and button:GetID() or nil
                    local link = bag and slot and GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
                    PaintButton(button, link, true)
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
        if button then PaintButton(button, link, false) end
    end
end

local function UpdateLootButtons()
    local index
    for index = 1, 8 do
        local button = _G["LootButton" .. index]
        local slot = button and button.GetID and button:GetID() or index
        local link = button and GetLootSlotLink and GetLootSlotLink(slot) or nil
        if button then PaintButton(button, link, false) end
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
                    impact = math.abs(difference * weight)
                })
            end
        end
    end
    table.sort(result, function(left, right) return left.impact > right.impact end)
    return result
end

local function AddTooltipAnalysis(tooltip)
    local settings = EnsureSettings()
    if not settings.enabled or not settings.tooltip then return end
    if tooltip.CoALootAdvisorBusy then return end

    local _, link = tooltip:GetItem()
    if not link or tooltip.CoALootAdvisorLink == link then return end
    tooltip.CoALootAdvisorBusy = true
    local analysis = Analyze(link)
    if not analysis or analysis.nonEquipable then
        tooltip.CoALootAdvisorBusy = false
        return
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("CoA Loot Advisor", 0.40, 0.85, 1.00)
    local profile = api.GetProfile()
    if profile and profile.valid then
        tooltip:AddLine(profile.className .. " - " .. profile.specName, 0.70, 0.70, 0.70)
        if profile.adaptive then
            tooltip:AddLine("Profil adaptatif : " .. tostring(profile.adaptive.confidence or "basse")
                .. " ; " .. tostring(profile.adaptive.selectedCount or 0) .. " talents ; niveau "
                .. tostring(profile.adaptive.level or "?"), 0.45, 0.82, 1.00)
        end
    end

    if not analysis.candidateScore then
        tooltip:AddLine("INCOMPATIBLE", 1.00, 0.20, 0.20)
        tooltip:AddLine(analysis.reason or "Comparaison impossible", 1.00, 0.55, 0.55, true)
    elseif analysis.manual then
        tooltip:AddDoubleLine("VERIFICATION MANUELLE", ShortPercent(analysis.percent),
            1.00, 0.75, 0.10, 1.00, 0.75, 0.10)
        tooltip:AddLine(analysis.reason or "Effet non chiffre", 1.00, 0.82, 0.35, true)
    else
        local positive = analysis.need
        local partial = not positive and (tonumber(analysis.percent) or 0) > 0
        local red, green, blue = 1.00, 0.25, 0.25
        local verdict = "MOINS BON"
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
    elseif analysis.candidateScore then
        tooltip:AddLine("Emplacement actuellement vide", 0.20, 1.00, 0.30)
    end

    if analysis.candidateScore then
        local differences = WeightedStatDifferences(analysis)
        local parts = {}
        local index, stat
        for index, stat in ipairs(differences) do
            if index > 4 then break end
            local prefix = stat.value > 0 and "+" or ""
            table.insert(parts, prefix .. stat.value .. " " .. stat.name)
        end
        if #parts > 0 then tooltip:AddLine(table.concat(parts, "  "), 0.82, 0.82, 0.82, true) end
        tooltip:AddLine("Confiance : " .. tostring(analysis.confidence or "inconnue"), 0.55, 0.75, 0.90)
    end

    tooltip.CoALootAdvisorLink = link
    tooltip.CoALootAdvisorBusy = false
    tooltip:Show()
end

local function ClearTooltipAnalysis(tooltip)
    tooltip.CoALootAdvisorLink = nil
    tooltip.CoALootAdvisorBusy = nil
end

local function HookTooltip(tooltip)
    if not tooltip or tooltipHooks[tooltip] or not tooltip.HookScript then return end
    tooltip:HookScript("OnTooltipSetItem", AddTooltipAnalysis)
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
            PaintButton(button, link)
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
advisorWindow.title:SetText("CoA Loot Decider")

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
    api.RefreshProfile()
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
        or "Profil CoA indisponible")
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
                row.delta:SetText("|cff33ff4c+ " .. ShortPercent(analysis.percent) .. "|r")
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

advisorWindow.refresh:SetScript("OnClick", RefreshWindow)
advisorWindow.mode:SetScript("OnClick", function()
    local settings = EnsureSettings()
    settings.showAllCandidates = not settings.showAllCandidates
    RefreshWindow()
end)
advisorWindow.sort:SetScript("OnClick", function()
    local settings = EnsureSettings()
    settings.sortMode = settings.sortMode == "gain" and "slot" or "gain"
    RefreshWindow()
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
        RefreshWindow()
    end
end

function CoALootAdvisor_ShowHistory()
    EnsureSettings().viewMode = "history"
    PositionAdvisorWindow()
    advisorWindow:Show()
    RefreshWindow()
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
        api.RefreshProfile()
        HookTooltip(GameTooltip)
        HookTooltip(ItemRefTooltip)
        HookTooltip(ShoppingTooltip1)
        HookTooltip(ShoppingTooltip2)
        HookAdiBags()
        HookSourceFrames()
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
    if not refreshPending then return end
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < REFRESH_DELAY then return end
    refreshPending = false
    refreshElapsed = 0
    analysisCache = {}
    local tooltip
    for tooltip in pairs(tooltipHooks) do tooltip.CoALootAdvisorLink = nil end
    api.RefreshProfile()
    HookAdiBags()
    HookSourceFrames()
    UpdateBagButtons()
    UpdateMerchantButtons()
    UpdateLootButtons()
    RefreshWindow()
end)
