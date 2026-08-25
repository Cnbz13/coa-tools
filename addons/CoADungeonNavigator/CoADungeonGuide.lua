-- CoA Dungeon Navigator - live guidance layer for Ascension / WoW 3.3.5.
-- Loaded after the recorder so the learning database and the generated routes
-- remain completely separate.

local routes = CoADungeonRouteData and CoADungeonRouteData.routes or {}
local API = CoADungeonNavigatorAPI or {}
local PI = math.pi
local TWO_PI = PI * 2
local guideFrame = nil
local hud = nil
local activeRoute = nil
local activeRouteKey = nil
local currentStep = 1
local lastPosition = nil
local lastDistance = nil
local statusMessage = "En attente d'un donjon"
local statusColor = { 0.58, 0.70, 0.82 }
local refreshElapsed = 0
local mapDots = {}
local playerDot = nil
local nextDot = nil
local progressFill = nil
local progressText = nil
local liveTitle = nil
local liveInstruction = nil
local liveMeta = nil
local liveDirection = nil
local routeSummary = nil
local upcomingText = nil
local lootText = nil
local confidenceText = nil
local hudDungeon = nil
local hudKind = nil
local hudTitle = nil
local hudInstruction = nil
local hudMeta = nil
local hudDirection = nil
local hudProgress = nil
local hudProgressFill = nil
local hudArrow = nil
local hudAccent = nil
local autoButton = nil
local hudButton = nil
local alertShownFor = nil

local KIND_COLORS = {
    start = { 0.35, 0.88, 1.00 }, route = { 0.35, 0.82, 1.00 },
    pack = { 1.00, 0.70, 0.22 }, boss = { 1.00, 0.28, 0.24 },
    finish = { 0.38, 0.92, 0.52 }, shortcut = { 0.62, 0.90, 0.45 },
    skip = { 0.75, 0.58, 1.00 }, stairs = { 0.45, 0.76, 1.00 },
    door = { 0.74, 0.66, 0.50 }, danger = { 1.00, 0.30, 0.18 }, note = { 0.75, 0.80, 0.88 }
}

local KIND_LABELS = {
    start = "DÉPART", route = "DIRECTION", pack = "PROCHAIN PACK", boss = "BOSS",
    finish = "ARRIVÉE", shortcut = "RACCOURCI", skip = "PACK À ÉVITER",
    stairs = "CHANGEMENT D'ÉTAGE", door = "PASSAGE", danger = "ATTENTION", note = "REPÈRE"
}

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff54d6ffCoA Dungeon Guide:|r " .. tostring(message or ""))
    end
end

local function Normalize(value)
    local text = string.lower(tostring(value or ""))
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function Round(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + PI end
    if x < 0 and y < 0 then return math.atan(y / x) - PI end
    if x == 0 and y > 0 then return PI / 2 end
    if x == 0 and y < 0 then return -PI / 2 end
    return 0
end

local function SavePosition(frame, storage)
    if not frame or not storage then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    storage.point = point or "CENTER"
    storage.relativePoint = relativePoint or storage.point
    storage.x = Round(x, 1)
    storage.y = Round(y, 1)
end

local function RestorePosition(frame, storage, point, relativePoint, x, y)
    frame:ClearAllPoints()
    if storage and storage.point then
        frame:SetPoint(storage.point, UIParent, storage.relativePoint or storage.point, storage.x or 0, storage.y or 0)
    else
        frame:SetPoint(point, UIParent, relativePoint, x, y)
    end
end

local function EnsureGuideDatabase()
    CoADungeonNavigatorDB = CoADungeonNavigatorDB or {}
    CoADungeonNavigatorDB.guide = CoADungeonNavigatorDB.guide or {}
    local settings = CoADungeonNavigatorDB.guide
    if settings.auto == nil then settings.auto = true end
    if settings.hud == nil then settings.hud = true end
    if settings.alerts == nil then settings.alerts = true end
    if settings.arrival == nil then settings.arrival = 0.028 end
    settings.window = settings.window or {}
    settings.hudPosition = settings.hudPosition or {}
    settings.progress = settings.progress or {}
    return settings
end

local function CurrentInstance()
    local name, instanceType, difficultyIndex = GetInstanceInfo()
    return tostring(name or ""), tostring(instanceType or "none"), tonumber(difficultyIndex) or 0
end

local function CurrentPosition(route)
    if not route then return nil end
    local currentMapId = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    if tonumber(route.mapId) and tonumber(route.mapId) > 0 and currentMapId ~= tonumber(route.mapId)
        and SetMapToCurrentZone and (not WorldMapFrame or not WorldMapFrame:IsShown()) then
        SetMapToCurrentZone()
        currentMapId = GetCurrentMapAreaID and GetCurrentMapAreaID() or currentMapId
    end
    local x, y = 0, 0
    if GetPlayerMapPosition then x, y = GetPlayerMapPosition("player") end
    x, y = tonumber(x) or 0, tonumber(y) or 0
    if x <= 0 and y <= 0 then return nil end
    return {
        x = x, y = y,
        floor = tonumber(GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0) or 0,
        mapId = tonumber(currentMapId) or 0,
        facing = tonumber(GetPlayerFacing and GetPlayerFacing() or 0) or 0
    }
end

local function Distance(position, step)
    if not position or not step then return 999 end
    local dx = (tonumber(step.x) or 0) - position.x
    local dy = (tonumber(step.y) or 0) - position.y
    return math.sqrt(dx * dx + dy * dy)
end

local function SameFloor(position, step)
    if not position or not step then return false end
    local playerFloor = tonumber(position.floor) or 0
    local stepFloor = tonumber(step.floor) or 0
    return playerFloor == 0 or stepFloor == 0 or playerFloor == stepFloor
end

local function KindColor(kind)
    return KIND_COLORS[kind] or KIND_COLORS.route
end

local function ColorText(text, color)
    local r = math.floor(Clamp(color[1], 0, 1) * 255)
    local g = math.floor(Clamp(color[2], 0, 1) * 255)
    local b = math.floor(Clamp(color[3], 0, 1) * 255)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, tostring(text or ""))
end

local function MeaningfulStep(route, startIndex)
    if not route or not route.checkpoints then return nil, nil end
    for index = startIndex or 1, #route.checkpoints do
        local step = route.checkpoints[index]
        if step.kind and step.kind ~= "route" then return step, index end
    end
    return route.checkpoints[#route.checkpoints], #route.checkpoints
end

local function FindNearestStep(route, position, first, last)
    if not route or not position or not route.checkpoints then return 1, 999 end
    local bestIndex, bestDistance = first or 1, 999
    for index = math.max(1, first or 1), math.min(#route.checkpoints, last or #route.checkpoints) do
        local step = route.checkpoints[index]
        if SameFloor(position, step) then
            local distance = Distance(position, step)
            if distance < bestDistance then
                bestIndex, bestDistance = index, distance
            end
        end
    end
    return bestIndex, bestDistance
end

local function DirectionText(relativeAngle)
    while relativeAngle < -PI do relativeAngle = relativeAngle + TWO_PI end
    while relativeAngle > PI do relativeAngle = relativeAngle - TWO_PI end
    local eighth = PI / 8
    if relativeAngle >= -eighth and relativeAngle < eighth then return "TOUT DROIT" end
    if relativeAngle >= eighth and relativeAngle < eighth * 3 then return "DEVANT À DROITE" end
    if relativeAngle >= eighth * 3 and relativeAngle < eighth * 5 then return "À DROITE" end
    if relativeAngle >= eighth * 5 and relativeAngle < eighth * 7 then return "DERRIÈRE À DROITE" end
    if relativeAngle >= eighth * 7 or relativeAngle < -eighth * 7 then return "DEMI-TOUR" end
    if relativeAngle >= -eighth * 7 and relativeAngle < -eighth * 5 then return "DERRIÈRE À GAUCHE" end
    if relativeAngle >= -eighth * 5 and relativeAngle < -eighth * 3 then return "À GAUCHE" end
    return "DEVANT À GAUCHE"
end

local function RelativeAngle(position, step)
    if not position or not step then return 0 end
    local dx = (tonumber(step.x) or 0) - position.x
    local dy = (tonumber(step.y) or 0) - position.y
    local bearing = Atan2(dx, -dy)
    local relative = bearing - (position.facing or 0)
    while relative < -PI do relative = relative + TWO_PI end
    while relative > PI do relative = relative - TWO_PI end
    return relative
end

local function RotateTexture(texture, angle)
    if not texture or not texture.SetTexCoord then return end
    local cosine = math.cos(angle)
    local sine = math.sin(angle)
    local function Rotate(x, y)
        local centeredX, centeredY = x - 0.5, y - 0.5
        return 0.5 + centeredX * cosine - centeredY * sine,
            0.5 + centeredX * sine + centeredY * cosine
    end
    local ulx, uly = Rotate(0, 0)
    local llx, lly = Rotate(0, 1)
    local urx, ury = Rotate(1, 0)
    local lrx, lry = Rotate(1, 1)
    texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function DistanceText(distance)
    if not distance or distance >= 900 then return "position inconnue" end
    if distance < 0.012 then return "juste devant" end
    if distance < 0.025 then return "tout près" end
    if distance < 0.06 then return "à " .. tostring(Round(distance * 100, 1)) .. "% de carte" end
    return "encore " .. tostring(Round(distance * 100, 1)) .. "% de carte"
end

local function RouteProgress(route)
    if not route or not route.checkpoints or #route.checkpoints == 0 then return 0 end
    return Clamp((currentStep - 1) / math.max(1, #route.checkpoints - 1), 0, 1)
end

local function StepInstruction(route, step)
    if not step then return "Aucune étape disponible." end
    if step.kind ~= "route" then return tostring(step.text or "Suis l'indication.") end
    local nextImportant = MeaningfulStep(route, currentStep + 1)
    if nextImportant and nextImportant.title then
        return "Continue par ici. Ensuite : " .. tostring(nextImportant.title) .. "."
    end
    return tostring(step.text or "Continue dans cette direction.")
end

local function SetStatus(message, color)
    statusMessage = message or statusMessage
    statusColor = color or statusColor
end

local function PersistProgress()
    if not activeRouteKey then return end
    local settings = EnsureGuideDatabase()
    settings.progress[activeRouteKey] = currentStep
end

local function AlertStep(step)
    local settings = EnsureGuideDatabase()
    if not settings.alerts or not step or (step.kind ~= "boss" and step.kind ~= "danger") then return end
    local key = tostring(activeRouteKey) .. ":" .. tostring(currentStep)
    if alertShownFor == key then return end
    alertShownFor = key
    if RaidWarningFrame and RaidNotice_AddMessage and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, "Guide : " .. tostring(step.title), ChatTypeInfo.RAID_WARNING)
    end
end

local function SelectRoute(forceReset)
    local settings = EnsureGuideDatabase()
    local name, instanceType = CurrentInstance()
    local key = Normalize(name)
    local route = instanceType == "party" and routes[key] or nil
    if route ~= activeRoute then
        activeRoute = route
        activeRouteKey = route and key or nil
        alertShownFor = nil
        lastPosition = nil
        if route then
            currentStep = 1
            local position = CurrentPosition(route)
            if position then
                local firstDistance = Distance(position, route.checkpoints[1])
                if firstDistance > 0.09 then currentStep = FindNearestStep(route, position, 1, #route.checkpoints) end
            end
            SetStatus("Guide actif", { 0.34, 0.91, 0.62 })
            Chat("itinéraire chargé : " .. tostring(route.name) .. " (" .. tostring(#route.checkpoints) .. " étapes).")
        else
            currentStep = 1
            if instanceType == "party" then SetStatus("Aucune route validée pour ce donjon", { 1.00, 0.67, 0.24 })
            else SetStatus("Entre dans un donjon : le guide démarrera tout seul", { 0.58, 0.70, 0.82 }) end
        end
    end
end

local function AdvanceStep(amount, reason)
    if not activeRoute or not activeRoute.checkpoints then return end
    local previous = currentStep
    currentStep = Clamp(currentStep + (amount or 1), 1, #activeRoute.checkpoints)
    if previous ~= currentStep then
        PersistProgress()
        alertShownFor = nil
        if reason then SetStatus(reason, { 0.34, 0.91, 0.62 }) end
    end
end

local function Recalibrate()
    if not activeRoute then return end
    local position = CurrentPosition(activeRoute)
    if not position then
        SetStatus("Ouvre puis referme la carte pour actualiser la position", { 1.00, 0.67, 0.24 })
        return
    end
    local index, distance = FindNearestStep(activeRoute, position, 1, #activeRoute.checkpoints)
    currentStep = index
    lastDistance = distance
    PersistProgress()
    SetStatus("Trajet recalé sur ta position", { 0.34, 0.91, 0.62 })
end

local function UpdateNavigation()
    local settings = EnsureGuideDatabase()
    if not activeRoute then return end
    local position = CurrentPosition(activeRoute)
    lastPosition = position
    if not position then
        lastDistance = nil
        SetStatus("Position indisponible — ouvre puis referme la carte", { 1.00, 0.67, 0.24 })
        return
    end
    local step = activeRoute.checkpoints[currentStep]
    if not step then return end
    if not SameFloor(position, step) then
        local nearbyIndex, nearbyDistance = FindNearestStep(activeRoute, position,
            math.max(1, currentStep - 6), math.min(#activeRoute.checkpoints, currentStep + 25))
        if nearbyDistance < 0.10 then
            currentStep = nearbyIndex
            step = activeRoute.checkpoints[currentStep]
            SetStatus("Étage détecté — trajet recalé", { 0.34, 0.91, 0.62 })
        else
            lastDistance = nil
            SetStatus("Rejoins l'étage " .. tostring(step.floor or "indiqué"), { 0.47, 0.76, 1.00 })
            return
        end
    end
    local distance = Distance(position, step)
    lastDistance = distance
    local arrival = Clamp(settings.arrival or 0.028, 0.012, 0.060)
    local safety = 0
    while distance <= arrival and currentStep < #activeRoute.checkpoints and safety < 8 do
        if step.kind == "pack" or step.kind == "boss" or step.kind == "danger" then break end
        currentStep = currentStep + 1
        step = activeRoute.checkpoints[currentStep]
        distance = Distance(position, step)
        lastDistance = distance
        safety = safety + 1
        PersistProgress()
        alertShownFor = nil
    end
    if distance > 0.16 then
        local nearestIndex, nearestDistance = FindNearestStep(activeRoute, position, 1, #activeRoute.checkpoints)
        if nearestDistance + 0.035 < distance then
            currentStep = nearestIndex
            lastDistance = nearestDistance
            step = activeRoute.checkpoints[currentStep]
            PersistProgress()
            SetStatus("Tu as quitté la trace : nouveau point trouvé", { 1.00, 0.67, 0.24 })
        end
    elseif currentStep >= #activeRoute.checkpoints and distance <= arrival * 1.5 then
        SetStatus("Parcours terminé", { 0.38, 0.92, 0.52 })
    else
        SetStatus("Guide actif", { 0.34, 0.91, 0.62 })
    end
    AlertStep(step)
end

local function CreateCard(parent, x, y, width, height, borderColor)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0.025, 0.045, 0.070, 0.94)
    local color = borderColor or { 0.16, 0.35, 0.48 }
    frame:SetBackdropBorderColor(color[1], color[2], color[3], 0.9)
    return frame
end

local function MakeButton(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function FormatUpcoming(route)
    if not route then return "Entre dans un donjon pris en charge pour afficher les prochaines étapes." end
    local lines = {}
    local shown = 0
    for index = currentStep, #route.checkpoints do
        local step = route.checkpoints[index]
        if index == currentStep or step.kind ~= "route" then
            local color = KindColor(step.kind)
            local marker = index == currentStep and "▶" or "•"
            table.insert(lines, ColorText(marker .. " " .. tostring(step.title or "Étape"), color))
            if index == currentStep then table.insert(lines, "   " .. StepInstruction(route, step)) end
            shown = shown + 1
            if shown >= 5 then break end
        end
    end
    return table.concat(lines, "\n")
end

local function FormatLoot(route)
    if not route then return "Le butin pertinent apparaîtra ici." end
    if not route.loot or #route.loot == 0 then
        return "Aucun objet fiable n'a encore été observé dans cette route. La collecte continue automatiquement."
    end
    local lines = {}
    for index = 1, math.min(4, #route.loot) do
        local item = route.loot[index]
        local verdict = "observé"
        local color = { 0.72, 0.80, 0.88 }
        if CoALootDeciderAPI and CoALootDeciderAPI.AnalyzeItem and item.itemId and item.itemId > 0 then
            local analysis = CoALootDeciderAPI.AnalyzeItem("item:" .. tostring(item.itemId))
            if analysis and analysis.need then verdict, color = "amélioration possible", { 0.35, 0.95, 0.48 }
            elseif analysis and analysis.candidateScore then verdict, color = "moins intéressant", { 0.72, 0.75, 0.80 } end
        end
        table.insert(lines, ColorText("• " .. tostring(item.name), color) .. "  " .. verdict)
    end
    return table.concat(lines, "\n")
end

local function UpdateRoutePreview()
    for _, dot in ipairs(mapDots) do dot:Hide() end
    if playerDot then playerDot:Hide() end
    if nextDot then nextDot:Hide() end
    if not activeRoute or not activeRoute.checkpoints or #activeRoute.checkpoints == 0 then return end
    local current = activeRoute.checkpoints[currentStep]
    local floor = lastPosition and lastPosition.floor or current and current.floor or 0
    local visible = {}
    local minX, minY, maxX, maxY = 1, 1, 0, 0
    for _, step in ipairs(activeRoute.checkpoints) do
        if floor == 0 or tonumber(step.floor or 0) == 0 or tonumber(step.floor or 0) == tonumber(floor) then
            table.insert(visible, step)
            minX, minY = math.min(minX, step.x), math.min(minY, step.y)
            maxX, maxY = math.max(maxX, step.x), math.max(maxY, step.y)
        end
    end
    if #visible == 0 then return end
    local rangeX = math.max(0.05, maxX - minX)
    local rangeY = math.max(0.05, maxY - minY)
    local stride = math.max(1, math.ceil(#visible / #mapDots))
    local dotIndex = 1
    for index = 1, #visible, stride do
        local step = visible[index]
        local dot = mapDots[dotIndex]
        if not dot then break end
        local px = 14 + (step.x - minX) / rangeX * 360
        local py = -35 - (step.y - minY) / rangeY * 205
        dot:ClearAllPoints()
        dot:SetPoint("TOPLEFT", dot.owner, "TOPLEFT", px, py)
        local color = KindColor(step.kind)
        local size = step.kind == "boss" and 8 or step.kind == "pack" and 5 or 3
        dot:SetWidth(size)
        dot:SetHeight(size)
        dot:SetVertexColor(color[1], color[2], color[3], step.kind == "route" and 0.72 or 1)
        dot:Show()
        dotIndex = dotIndex + 1
    end
    local function PlaceSpecial(dot, position)
        if not dot or not position then return end
        local px = 14 + (position.x - minX) / rangeX * 360
        local py = -35 - (position.y - minY) / rangeY * 205
        dot:ClearAllPoints()
        dot:SetPoint("TOPLEFT", dot.owner, "TOPLEFT", px - 4, py + 4)
        dot:Show()
    end
    PlaceSpecial(nextDot, current)
    PlaceSpecial(playerDot, lastPosition)
end

local function UpdateDisplays()
    local settings = EnsureGuideDatabase()
    local route = activeRoute
    local step = route and route.checkpoints and route.checkpoints[currentStep] or nil
    local progress = RouteProgress(route)
    local color = step and KindColor(step.kind) or statusColor
    local direction = ""
    if step and lastPosition and SameFloor(lastPosition, step) then
        direction = DirectionText(RelativeAngle(lastPosition, step))
        RotateTexture(hudArrow, RelativeAngle(lastPosition, step))
    else
        RotateTexture(hudArrow, 0)
    end

    if guideFrame and guideFrame:IsShown() then
        if route and step then
            liveTitle:SetText(ColorText(KIND_LABELS[step.kind] or "ÉTAPE", color) .. "  •  " .. tostring(step.title or "Suis le chemin"))
            liveInstruction:SetText(StepInstruction(route, step))
            liveMeta:SetText(direction .. (direction ~= "" and "  •  " or "") .. DistanceText(lastDistance)
                .. "  •  étage " .. tostring(step.floor or 0))
            progressText:SetText(tostring(currentStep) .. " / " .. tostring(#route.checkpoints)
                .. "  •  " .. tostring(math.floor(progress * 100 + 0.5)) .. "%")
            routeSummary:SetText(tostring(route.summary or "") .. "\n\n"
                .. ColorText("État : " .. statusMessage, statusColor))
            confidenceText:SetText("Trace issue de " .. tostring(route.sourceRuns or 1) .. " run(s)  •  confiance "
                .. tostring(route.confidence or "à confirmer") .. "  •  " .. tostring(#(route.observedBosses or {})) .. " boss observés")
        else
            liveTitle:SetText(ColorText("GUIDE EN ATTENTE", statusColor))
            liveInstruction:SetText(statusMessage)
            liveMeta:SetText(tostring(CoADungeonRouteData and CoADungeonRouteData.routeCount or 0) .. " routes disponibles hors ligne")
            progressText:SetText("0 %")
            routeSummary:SetText("Le guide apparaît automatiquement dès que tu entres dans un donjon connu. En attendant, l'apprentissage reste actif en arrière-plan.")
            confidenceText:SetText("Aucune route active")
        end
        progressFill:SetWidth(math.max(1, 620 * progress))
        progressFill:SetVertexColor(color[1], color[2], color[3], 0.95)
        upcomingText:SetText(FormatUpcoming(route))
        lootText:SetText(FormatLoot(route))
        autoButton:SetText(settings.auto and "Guidage auto : ON" or "Guidage auto : OFF")
        hudButton:SetText(settings.hud and "HUD : ON" or "HUD : OFF")
        UpdateRoutePreview()
    end

    if hud then
        if route and step and settings.hud then
            hud:Show()
            hudDungeon:SetText(tostring(route.name) .. "  •  " .. tostring(math.floor(progress * 100 + 0.5)) .. "%")
            hudKind:SetText(ColorText(KIND_LABELS[step.kind] or "DIRECTION", color))
            hudTitle:SetText(tostring(step.title or "Suis le chemin"))
            hudInstruction:SetText(StepInstruction(route, step))
            hudMeta:SetText(DistanceText(lastDistance) .. "  •  étage " .. tostring(step.floor or 0)
                .. "  •  étape " .. tostring(currentStep) .. "/" .. tostring(#route.checkpoints))
            hudDirection:SetText(direction)
            hudProgress:SetText(tostring(math.floor(progress * 100 + 0.5)) .. "%")
            hudProgressFill:SetWidth(math.max(1, 350 * progress))
            hudProgressFill:SetVertexColor(color[1], color[2], color[3], 0.95)
            hudAccent:SetVertexColor(color[1], color[2], color[3], 1)
            hud:SetBackdropBorderColor(color[1], color[2], color[3], 0.95)
            hudArrow:SetVertexColor(color[1], color[2], color[3], 1)
        else
            hud:Hide()
        end
    end
end

guideFrame = CreateFrame("Frame", "CoADungeonNavigatorFrame", UIParent)
guideFrame:SetWidth(700)
guideFrame:SetHeight(560)
guideFrame:SetFrameStrata("DIALOG")
guideFrame:SetMovable(true)
guideFrame:EnableMouse(true)
guideFrame:RegisterForDrag("LeftButton")
if guideFrame.SetClampedToScreen then guideFrame:SetClampedToScreen(true) end
guideFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
guideFrame:SetBackdropColor(0.018, 0.032, 0.052, 0.985)
guideFrame:SetBackdropBorderColor(0.18, 0.64, 0.84, 0.95)
guideFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
guideFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self, EnsureGuideDatabase().window)
end)
guideFrame:Hide()

local topAccent = guideFrame:CreateTexture(nil, "ARTWORK")
topAccent:SetTexture("Interface/Buttons/WHITE8X8")
topAccent:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 5, -5)
topAccent:SetPoint("TOPRIGHT", guideFrame, "TOPRIGHT", -5, -5)
topAccent:SetHeight(3)
topAccent:SetVertexColor(0.20, 0.80, 1.00, 0.95)

local title = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 20, -19)
title:SetText("CoA • Guide de donjon")
title:SetTextColor(0.38, 0.86, 1.00)

local subtitle = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
subtitle:SetText("UNE ROUTE CLAIRE, UNE CONSIGNE À LA FOIS")
subtitle:SetTextColor(0.52, 0.63, 0.72)

local close = CreateFrame("Button", nil, guideFrame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", guideFrame, "TOPRIGHT", -4, -4)

local liveCard = CreateCard(guideFrame, 18, -64, 664, 104, { 0.20, 0.63, 0.82 })
liveTitle = liveCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
liveTitle:SetPoint("TOPLEFT", liveCard, "TOPLEFT", 14, -12)
liveTitle:SetWidth(630)
liveTitle:SetJustifyH("LEFT")
liveInstruction = liveCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
liveInstruction:SetPoint("TOPLEFT", liveTitle, "BOTTOMLEFT", 0, -8)
liveInstruction:SetWidth(630)
liveInstruction:SetJustifyH("LEFT")
liveMeta = liveCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
liveMeta:SetPoint("BOTTOMLEFT", liveCard, "BOTTOMLEFT", 14, 12)
liveMeta:SetTextColor(0.58, 0.76, 0.88)

local progressBack = guideFrame:CreateTexture(nil, "BACKGROUND")
progressBack:SetTexture("Interface/Buttons/WHITE8X8")
progressBack:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 30, -176)
progressBack:SetWidth(620)
progressBack:SetHeight(6)
progressBack:SetVertexColor(0.08, 0.13, 0.18, 1)
progressFill = guideFrame:CreateTexture(nil, "ARTWORK")
progressFill:SetTexture("Interface/Buttons/WHITE8X8")
progressFill:SetPoint("LEFT", progressBack, "LEFT", 0, 0)
progressFill:SetWidth(1)
progressFill:SetHeight(6)
progressText = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
progressText:SetPoint("LEFT", progressBack, "RIGHT", 8, 0)

local mapCard = CreateCard(guideFrame, 18, -198, 408, 274, { 0.14, 0.36, 0.50 })
local mapTitle = mapCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mapTitle:SetPoint("TOPLEFT", mapCard, "TOPLEFT", 12, -10)
mapTitle:SetText("TRACE DE L'ÉTAGE ACTUEL")
mapTitle:SetTextColor(0.38, 0.86, 1.00)
local mapHelp = mapCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
mapHelp:SetPoint("TOPRIGHT", mapCard, "TOPRIGHT", -12, -10)
mapHelp:SetText("jaune : toi  •  blanc : prochaine étape")
for index = 1, 120 do
    local dot = mapCard:CreateTexture(nil, "ARTWORK")
    dot.owner = mapCard
    dot:SetTexture("Interface/Buttons/WHITE8X8")
    dot:SetWidth(3)
    dot:SetHeight(3)
    dot:Hide()
    mapDots[index] = dot
end
nextDot = mapCard:CreateTexture(nil, "OVERLAY")
nextDot.owner = mapCard
nextDot:SetTexture("Interface/Buttons/WHITE8X8")
nextDot:SetWidth(10)
nextDot:SetHeight(10)
nextDot:SetVertexColor(0.95, 0.98, 1.00, 1)
nextDot:Hide()
playerDot = mapCard:CreateTexture(nil, "OVERLAY")
playerDot.owner = mapCard
playerDot:SetTexture("Interface/Buttons/WHITE8X8")
playerDot:SetWidth(9)
playerDot:SetHeight(9)
playerDot:SetVertexColor(1.00, 0.84, 0.22, 1)
playerDot:Hide()

local sideCard = CreateCard(guideFrame, 436, -198, 246, 274, { 0.14, 0.36, 0.50 })
local upcomingTitle = sideCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
upcomingTitle:SetPoint("TOPLEFT", sideCard, "TOPLEFT", 12, -10)
upcomingTitle:SetText("CE QUI T'ATTEND")
upcomingTitle:SetTextColor(1.00, 0.80, 0.30)
upcomingText = sideCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
upcomingText:SetPoint("TOPLEFT", upcomingTitle, "BOTTOMLEFT", 0, -10)
upcomingText:SetWidth(218)
upcomingText:SetHeight(142)
upcomingText:SetJustifyH("LEFT")
upcomingText:SetJustifyV("TOP")
local lootTitle = sideCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lootTitle:SetPoint("TOPLEFT", sideCard, "TOPLEFT", 12, -179)
lootTitle:SetText("BUTIN POUR TON PERSONNAGE")
lootTitle:SetTextColor(0.42, 0.92, 0.58)
lootText = sideCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lootText:SetPoint("TOPLEFT", lootTitle, "BOTTOMLEFT", 0, -7)
lootText:SetWidth(218)
lootText:SetHeight(68)
lootText:SetJustifyH("LEFT")
lootText:SetJustifyV("TOP")

routeSummary = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
routeSummary:SetPoint("TOPLEFT", guideFrame, "TOPLEFT", 24, -483)
routeSummary:SetWidth(650)
routeSummary:SetHeight(36)
routeSummary:SetJustifyH("LEFT")
routeSummary:SetJustifyV("TOP")
confidenceText = guideFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
confidenceText:SetPoint("BOTTOMLEFT", guideFrame, "BOTTOMLEFT", 24, 47)
confidenceText:SetWidth(650)
confidenceText:SetJustifyH("LEFT")

MakeButton(guideFrame, "◀ Étape", 84, 18, -526, function() AdvanceStep(-1, "Étape précédente") UpdateDisplays() end)
MakeButton(guideFrame, "Étape ▶", 84, 108, -526, function() AdvanceStep(1, "Étape suivante") UpdateDisplays() end)
MakeButton(guideFrame, "Me recaler", 100, 198, -526, function() Recalibrate() UpdateDisplays() end)
autoButton = MakeButton(guideFrame, "Guidage auto : ON", 132, 304, -526, function()
    local settings = EnsureGuideDatabase()
    settings.auto = not settings.auto
    UpdateDisplays()
end)
hudButton = MakeButton(guideFrame, "HUD : ON", 88, 442, -526, function()
    local settings = EnsureGuideDatabase()
    settings.hud = not settings.hud
    UpdateDisplays()
end)
MakeButton(guideFrame, "Collecte", 102, 536, -526, function()
    if API.ToggleLearning then API:ToggleLearning() end
end)

hud = CreateFrame("Frame", "CoADungeonNavigatorHUD", UIParent)
hud:SetWidth(430)
hud:SetHeight(154)
hud:SetFrameStrata("HIGH")
hud:SetMovable(true)
hud:EnableMouse(true)
hud:RegisterForDrag("LeftButton")
if hud.SetClampedToScreen then hud:SetClampedToScreen(true) end
hud:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
hud:SetBackdropColor(0.015, 0.030, 0.048, 0.94)
hud:SetBackdropBorderColor(0.25, 0.78, 1.00, 0.95)
hud:SetScript("OnDragStart", function(self) self:StartMoving() end)
hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self, EnsureGuideDatabase().hudPosition)
end)
hud:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then API:Toggle() end
end)
hud:Hide()

hudAccent = hud:CreateTexture(nil, "ARTWORK")
hudAccent:SetTexture("Interface/Buttons/WHITE8X8")
hudAccent:SetPoint("TOPLEFT", hud, "TOPLEFT", 5, -5)
hudAccent:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 5, 5)
hudAccent:SetWidth(4)
hudAccent:SetVertexColor(0.25, 0.78, 1.00, 1)

local arrowRing = hud:CreateTexture(nil, "BACKGROUND")
arrowRing:SetTexture("Interface/Buttons/UI-Quickslot2")
arrowRing:SetWidth(74)
arrowRing:SetHeight(74)
arrowRing:SetPoint("LEFT", hud, "LEFT", 18, 4)
arrowRing:SetVertexColor(0.18, 0.45, 0.62, 0.90)
hudArrow = hud:CreateTexture(nil, "ARTWORK")
hudArrow:SetTexture("Interface/Minimap/MinimapArrow")
hudArrow:SetWidth(50)
hudArrow:SetHeight(50)
hudArrow:SetPoint("CENTER", arrowRing, "CENTER", 0, 0)
hudArrow:SetVertexColor(0.35, 0.88, 1.00, 1)
hudDirection = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hudDirection:SetPoint("TOP", arrowRing, "BOTTOM", 0, -1)
hudDirection:SetWidth(100)
hudDirection:SetTextColor(1.00, 0.82, 0.28)

hudDungeon = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hudDungeon:SetPoint("TOPLEFT", hud, "TOPLEFT", 105, -13)
hudDungeon:SetWidth(302)
hudDungeon:SetJustifyH("LEFT")
hudDungeon:SetTextColor(0.58, 0.72, 0.82)
hudKind = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hudKind:SetPoint("TOPLEFT", hudDungeon, "BOTTOMLEFT", 0, -6)
hudKind:SetWidth(302)
hudKind:SetJustifyH("LEFT")
hudTitle = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hudTitle:SetPoint("TOPLEFT", hudKind, "BOTTOMLEFT", 0, -3)
hudTitle:SetWidth(302)
hudTitle:SetJustifyH("LEFT")
hudInstruction = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hudInstruction:SetPoint("TOPLEFT", hudTitle, "BOTTOMLEFT", 0, -5)
hudInstruction:SetWidth(302)
hudInstruction:SetHeight(32)
hudInstruction:SetJustifyH("LEFT")
hudInstruction:SetJustifyV("TOP")
hudMeta = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hudMeta:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 105, 20)
hudMeta:SetWidth(260)
hudMeta:SetJustifyH("LEFT")
hudProgress = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hudProgress:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -14, 20)
hudProgress:SetJustifyH("RIGHT")
local hudProgressBack = hud:CreateTexture(nil, "BACKGROUND")
hudProgressBack:SetTexture("Interface/Buttons/WHITE8X8")
hudProgressBack:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 65, 9)
hudProgressBack:SetWidth(350)
hudProgressBack:SetHeight(5)
hudProgressBack:SetVertexColor(0.07, 0.12, 0.17, 1)
hudProgressFill = hud:CreateTexture(nil, "ARTWORK")
hudProgressFill:SetTexture("Interface/Buttons/WHITE8X8")
hudProgressFill:SetPoint("LEFT", hudProgressBack, "LEFT", 0, 0)
hudProgressFill:SetWidth(1)
hudProgressFill:SetHeight(5)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= "CoADungeonNavigator" then return end
        local settings = EnsureGuideDatabase()
        RestorePosition(guideFrame, settings.window, "CENTER", "CENTER", 0, 10)
        RestorePosition(hud, settings.hudPosition, "TOP", "TOP", 0, -75)
        SelectRoute(false)
        UpdateNavigation()
        UpdateDisplays()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        SelectRoute(false)
        UpdateNavigation()
        UpdateDisplays()
    elseif event == "PLAYER_REGEN_ENABLED" then
        local step = activeRoute and activeRoute.checkpoints and activeRoute.checkpoints[currentStep]
        if step and (step.kind == "pack" or step.kind == "boss") then
            AdvanceStep(1, "Combat terminé — on continue")
        end
        UpdateNavigation()
        UpdateDisplays()
    elseif event == "PLAYER_TARGET_CHANGED" then
        local targetName = UnitExists("target") and UnitName("target") or nil
        if targetName and activeRoute then
            for index = currentStep, math.min(#activeRoute.checkpoints, currentStep + 12) do
                local step = activeRoute.checkpoints[index]
                if step.kind == "boss" and Normalize(step.title) == Normalize(targetName) then
                    currentStep = index
                    PersistProgress()
                    SetStatus("Boss repéré", { 1.00, 0.28, 0.24 })
                    break
                end
            end
        end
        UpdateDisplays()
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < 0.12 then return end
    refreshElapsed = 0
    SelectRoute(false)
    if EnsureGuideDatabase().auto then UpdateNavigation() end
    UpdateDisplays()
end)

function API:Toggle()
    if guideFrame:IsShown() then guideFrame:Hide()
    else guideFrame:Show() UpdateDisplays() end
end

function API:Show()
    guideFrame:Show()
    UpdateDisplays()
end

function API:ShowGuide()
    guideFrame:Show()
    UpdateDisplays()
end

function API:Recalibrate()
    Recalibrate()
    UpdateDisplays()
end

function API:GetGuideStatus()
    return {
        active = activeRoute ~= nil,
        dungeon = activeRoute and activeRoute.name or nil,
        step = currentStep,
        total = activeRoute and activeRoute.checkpoints and #activeRoute.checkpoints or 0,
        message = statusMessage
    }
end

SLASH_COADUNGEONGUIDE1 = "/cdg"
SlashCmdList.COADUNGEONGUIDE = function(message)
    local command = Normalize(message)
    if command == "" or command == "show" then API:Toggle()
    elseif command == "next" or command == "suivant" then AdvanceStep(1, "Étape suivante")
    elseif command == "prev" or command == "precedent" or command == "précédent" then AdvanceStep(-1, "Étape précédente")
    elseif command == "reset" then currentStep = 1 PersistProgress() SetStatus("Parcours repris au début", { 0.34, 0.91, 0.62 })
    elseif command == "recal" or command == "recaler" then Recalibrate()
    elseif command == "hud" then
        local settings = EnsureGuideDatabase()
        settings.hud = not settings.hud
    elseif command == "learning" or command == "collecte" then
        if API.ToggleLearning then API:ToggleLearning() end
    else
        Chat("commandes : /cdg, next, prev, recal, reset, hud, collecte")
    end
    UpdateDisplays()
end
