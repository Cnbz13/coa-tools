-- CoA Loot Decider - organisateur de sacs prudent pour WoW 3.3.5a.
-- Aucun déplacement ne démarre sans un clic explicite du joueur.

local organizer = CreateFrame("Frame", "CoALootBagOrganizerFrame")
organizer:Hide() -- coupe entièrement OnUpdate hors d'un tri demandé
local button = nil
local queue = {}
local running = false
local phase = nil
local elapsedSinceMove = 0
local nextPhaseAt = nil
local expectedBagUpdates = 0
local containerHooks = {}

local CATEGORY_NAMES = {
    [1] = "Quêtes", [2] = "Consommables", [3] = "Métiers",
    [4] = "Gemmes et améliorations", [5] = "Équipement",
    [6] = "Divers", [7] = "Camelote"
}

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff67d9ffLoot Decider :|r " .. tostring(message))
    end
end

local function InCombat()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return true end
    return type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") and true or false
end

local TEXT_FOLD = {
    ["À"]="a", ["Â"]="a", ["Ä"]="a", ["à"]="a", ["â"]="a", ["ä"]="a",
    ["Ç"]="c", ["ç"]="c", ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e", ["Î"]="i", ["Ï"]="i",
    ["î"]="i", ["ï"]="i", ["Ô"]="o", ["Ö"]="o", ["ô"]="o", ["ö"]="o",
    ["Ù"]="u", ["Û"]="u", ["Ü"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u"
}

local function Fold(value)
    local text = tostring(value or "")
    local source, replacement
    for source, replacement in pairs(TEXT_FOLD) do
        text = string.gsub(text, source, replacement)
    end
    return string.lower(text)
end

local function Contains(text, words)
    local _, word
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function ItemID(link)
    return tonumber(string.match(tostring(link or ""), "item:(%-?%d+)")) or 0
end

local function BagIsGeneral(bag)
    if bag == 0 then return true end
    if type(GetInventoryItemLink) ~= "function" or type(GetItemFamily) ~= "function" then
        -- Sans information fiable sur les familles, seul le sac à dos est sûr.
        return false
    end
    local link = GetInventoryItemLink("player", 19 + bag)
    if not link then return false end
    local ok, family = pcall(GetItemFamily, link)
    return ok and (tonumber(family) or 0) == 0
end

local function CursorOccupied()
    if type(CursorHasItem) == "function" then return CursorHasItem() and true or false end
    if type(GetCursorInfo) == "function" then return GetCursorInfo() ~= nil end
    return false
end

local function SlotState(bag, slot)
    local texture, count, locked = GetContainerItemInfo(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    return {
        bag = bag, slot = slot, texture = texture, count = tonumber(count) or 0,
        locked = locked and true or false, link = link
    }
end

local function EligibleSlots()
    local slots = {}
    local maxBag = tonumber(NUM_BAG_SLOTS) or 4
    local bag, slot
    for bag = 0, maxBag do
        if BagIsGeneral(bag) then
            local count = tonumber(GetContainerNumSlots(bag)) or 0
            for slot = 1, count do
                local state = SlotState(bag, slot)
                -- Un objet verrouillé reste exactement à sa place.
                if not state.locked then table.insert(slots, state) end
            end
        end
    end
    return slots
end

local function CategoryFor(link, quality, equipLoc, itemType, itemSubType)
    if tonumber(quality) == 0 then return 7 end
    local text = Fold((itemType or "") .. " " .. (itemSubType or ""))
    if Contains(text, { "quest", "quete" }) then return 1 end
    if Contains(text, { "consumable", "consommable", "food", "drink", "potion", "elixir", "flask" }) then
        return 2
    end
    if Contains(text, { "trade goods", "artisanat", "reagent", "composant", "metal", "cloth", "herb", "cuir" }) then
        return 3
    end
    if Contains(text, { "gem", "gemme", "glyph", "glyphe", "enchant", "amelioration d'objet" }) then
        return 4
    end
    if equipLoc and equipLoc ~= "" then return 5 end
    return 6
end

local function Describe(state, uid)
    if not state.link then return nil end
    local name, _, quality, _, _, itemType, itemSubType, maxStack, equipLoc = GetItemInfo(state.link)
    if not name then return nil end
    local category = CategoryFor(state.link, quality, equipLoc, itemType, itemSubType)
    return {
        uid = uid,
        bag = state.bag,
        slot = state.slot,
        link = state.link,
        count = state.count,
        maxStack = tonumber(maxStack) or 1,
        itemID = ItemID(state.link),
        category = category,
        key = string.format("%02d|%s|%s|%02d|%s|%010d", category, Fold(itemType),
            Fold(itemSubType), 9 - (tonumber(quality) or 0), Fold(name), ItemID(state.link))
    }
end

local function SamePosition(left, right)
    return left and right and left.bag == right.bag and left.slot == right.slot
end

local function CurrentLink(position)
    return GetContainerItemLink(position.bag, position.slot)
end

local function Abort(reason)
    queue = {}
    running = false
    phase = nil
    nextPhaseAt = nil
    expectedBagUpdates = 0
    if button then button:Enable() button:SetText("Tri") end
    organizer:Hide()
    if CursorOccupied() and type(ClearCursor) == "function" then ClearCursor() end
    Chat("tri arrêté : " .. tostring(reason or "état des sacs modifié"))
end

local function Finish()
    queue = {}
    running = false
    phase = nil
    nextPhaseAt = nil
    expectedBagUpdates = 0
    if button then button:Enable() button:SetText("Tri") end
    organizer:Hide()
    Chat("sacs organisés")
end

local function QueueMergePlan(slots)
    local groups = {}
    local uid = 0
    local _, state
    for _, state in ipairs(slots) do
        if state.link then
            uid = uid + 1
            local item = Describe(state, uid)
            if item and item.maxStack > 1 then
                groups[item.itemID] = groups[item.itemID] or {}
                table.insert(groups[item.itemID], item)
            end
        end
    end

    local _, items
    for _, items in pairs(groups) do
        local targetIndex, sourceIndex
        for targetIndex = 1, #items do
            local target = items[targetIndex]
            local free = target.maxStack - target.count
            if free > 0 then
                for sourceIndex = #items, targetIndex + 1, -1 do
                    local source = items[sourceIndex]
                    if source.count > 0 and source.count <= free then
                        table.insert(queue, {
                            kind = "merge", from = source, to = target,
                            fromLink = source.link, toLink = target.link
                        })
                        free = free - source.count
                        target.count = target.count + source.count
                        source.count = 0
                    end
                end
            end
        end
    end
end

local function QueueSortPlan()
    local slots = EligibleSlots()
    local state = {}
    local desired = {}
    local uid = 0
    local index, slot
    for index, slot in ipairs(slots) do
        local item = nil
        if slot.link then
            uid = uid + 1
            item = Describe(slot, uid)
            if not item then
                Abort("informations d'objet encore indisponibles")
                return false
            end
            table.insert(desired, item)
        end
        state[index] = item
    end
    table.sort(desired, function(left, right)
        if left.key == right.key then return left.uid < right.uid end
        return left.key < right.key
    end)

    for index = 1, #desired do
        if not state[index] or state[index].uid ~= desired[index].uid then
            local sourceIndex = nil
            local search
            for search = index + 1, #state do
                if state[search] and state[search].uid == desired[index].uid then
                    sourceIndex = search
                    break
                end
            end
            if not sourceIndex then
                Abort("contenu des sacs modifié pendant le calcul")
                return false
            end
            table.insert(queue, {
                kind = "swap", from = slots[sourceIndex], to = slots[index],
                fromLink = state[sourceIndex] and state[sourceIndex].link or nil,
                toLink = state[index] and state[index].link or nil
            })
            state[index], state[sourceIndex] = state[sourceIndex], state[index]
        end
    end
    return true
end

local function SlotLocked(position)
    local _, _, locked = GetContainerItemInfo(position.bag, position.slot)
    return locked and true or false
end

local function ExecuteMove(move)
    if CursorOccupied() then return false, "un objet est déjà tenu par le curseur" end
    if SlotLocked(move.from) or SlotLocked(move.to) then return nil end
    if CurrentLink(move.from) ~= move.fromLink or CurrentLink(move.to) ~= move.toLink then
        return false, "contenu des sacs modifié pendant le tri"
    end

    PickupContainerItem(move.from.bag, move.from.slot)
    PickupContainerItem(move.to.bag, move.to.slot)
    if move.kind == "swap" and CursorOccupied() then
        PickupContainerItem(move.from.bag, move.from.slot)
    end
    if CursorOccupied() then
        -- Une fusion partielle imprévue ne doit jamais laisser un objet au curseur.
        PickupContainerItem(move.from.bag, move.from.slot)
    end
    if CursorOccupied() then return false, "le client a refusé un déplacement" end
    expectedBagUpdates = expectedBagUpdates + 1
    return true
end

local function BeginSort()
    if running then
        Chat("un tri est déjà en cours")
        return
    end
    if InCombat() then
        Chat("tri impossible pendant le combat")
        return
    end
    if CursorOccupied() then
        Chat("dépose d'abord l'objet tenu par le curseur")
        return
    end
    if type(GetContainerNumSlots) ~= "function" or type(GetContainerItemInfo) ~= "function"
        or type(GetContainerItemLink) ~= "function" or type(PickupContainerItem) ~= "function"
    then
        Chat("API de sacs WotLK indisponible")
        return
    end

    queue = {}
    running = true
    organizer:Show()
    phase = "merge"
    elapsedSinceMove = 0
    expectedBagUpdates = 0
    if button then button:Disable() button:SetText("...") end
    QueueMergePlan(EligibleSlots())
    if #queue == 0 then
        phase = "sort"
        if not QueueSortPlan() then return end
        if #queue == 0 then Finish() end
    end
end

local function BackpackFrame()
    local index
    for index = 1, (tonumber(NUM_CONTAINER_FRAMES) or 13) do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.IsShown and frame:IsShown() then
            local id = frame.GetID and frame:GetID() or frame.bagID
            if tonumber(id) == 0 then return frame end
        end
    end
    return nil
end

local function PositionButton()
    if not button then return end
    local frame = BackpackFrame()
    if not frame then button:Hide() return end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -3)
    button:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
    button:Show()
end

local function HookContainerFrames()
    local index
    for index = 1, (tonumber(NUM_CONTAINER_FRAMES) or 13) do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.HookScript and not containerHooks[frame] then
            frame:HookScript("OnShow", PositionButton)
            frame:HookScript("OnHide", PositionButton)
            containerHooks[frame] = true
        end
    end
end

local function CreateSortButton()
    if button then PositionButton() return end
    button = CreateFrame("Button", "CoALootBagSortButton", UIParent, "UIPanelButtonTemplate")
    button:SetWidth(38)
    button:SetHeight(18)
    button:SetText("Tri")
    button:SetScript("OnClick", BeginSort)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Organiser les sacs", 1, 0.82, 0.20)
        GameTooltip:AddLine("Regroupe les piles et classe les objets.", 1, 1, 1)
        GameTooltip:AddLine("Les sacs spécialisés et objets verrouillés ne bougent pas.", 0.65, 0.78, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PositionButton()
end

organizer:RegisterEvent("PLAYER_LOGIN")
organizer:RegisterEvent("BAG_UPDATE")
organizer:RegisterEvent("ITEM_LOCK_CHANGED")
organizer:RegisterEvent("PLAYER_REGEN_DISABLED")
organizer:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CreateSortButton()
        HookContainerFrames()
    elseif event == "PLAYER_REGEN_DISABLED" and running then
        Abort("entrée en combat")
    elseif event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" then
        if expectedBagUpdates > 0 then expectedBagUpdates = expectedBagUpdates - 1 end
        PositionButton()
    end
end)

organizer:SetScript("OnUpdate", function(self, elapsed)
    if not running then return end
    if InCombat() then Abort("entrée en combat") return end
    elapsedSinceMove = elapsedSinceMove + elapsed
    if elapsedSinceMove < 0.12 then return end
    elapsedSinceMove = 0

    if nextPhaseAt then
        if GetTime() < nextPhaseAt then return end
        nextPhaseAt = nil
        phase = "sort"
        if not QueueSortPlan() then return end
        if #queue == 0 then Finish() return end
    end

    local move = queue[1]
    if not move then
        if phase == "merge" then
            nextPhaseAt = GetTime() + 0.30
        else
            Finish()
        end
        return
    end
    local moved, problem = ExecuteMove(move)
    if moved == nil then return end
    if not moved then Abort(problem) return end
    table.remove(queue, 1)
end)

SLASH_COALOOTBAGS1 = "/cldbags"
SlashCmdList.COALOOTBAGS = function(message)
    local command = Fold(message)
    if command == "sort" or command == "tri" or command == "" then
        BeginSort()
    elseif command == "categories" then
        local index
        for index = 1, 7 do Chat(index .. ". " .. CATEGORY_NAMES[index]) end
    else
        Chat("/cldbags - organise les sacs ; /cldbags categories - affiche l'ordre")
    end
end

CoALootBagOrganizer = {
    Sort = BeginSort,
    IsRunning = function() return running end,
    Categories = CATEGORY_NAMES
}
