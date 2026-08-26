local addonName = ...

local ADDON_VERSION = "1.18.0"
local EXPORT_FORMAT = "COADN1"
local DEFAULT_SAMPLE_INTERVAL = 0.75
local DEFAULT_MIN_DISTANCE = 0.0015
local MAX_ROUTE_POINTS = 8000
local MAX_SESSIONS = 40

local activeSession = nil
local activePull = nil
local initialized = false
local updateElapsed = 0
local statusElapsed = 0
local zoneCheckAt = nil
local hubManaged = false
local panel = nil
local recorder = nil
local exportFrame = nil
local exportEditBox = nil
local minimapButton = nil
local statusText = nil
local detailText = nil
local historyText = nil
local autoButton = nil
local recordButton = nil
local lastKilledEnemy = nil
local lootCaptureUntil = nil
local lootRetryElapsed = 0

CoADungeonNavigatorAPI = CoADungeonNavigatorAPI or {}
local API = CoADungeonNavigatorAPI

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff54d6ffCoA Dungeon Navigator:|r " .. tostring(message or ""))
    end
end

local function Now()
    return GetTime and GetTime() or 0
end

local function Epoch()
    return time and time() or 0
end

local function Round(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

local function Trim(value)
    return string.match(tostring(value or ""), "^%s*(.-)%s*$")
end

local function Escape(value)
    local text = tostring(value or "")
    text = string.gsub(text, "%%", "%%25")
    text = string.gsub(text, "\t", "%%09")
    text = string.gsub(text, "\r", "%%0D")
    text = string.gsub(text, "\n", "%%0A")
    text = string.gsub(text, "|", "%%7C")
    return text
end

local function EnsureDatabase()
    CoADungeonNavigatorDB = CoADungeonNavigatorDB or {}
    CoADungeonNavigatorDB.settings = CoADungeonNavigatorDB.settings or {}
    if CoADungeonNavigatorDB.settings.autoRecord == nil then CoADungeonNavigatorDB.settings.autoRecord = true end
    CoADungeonNavigatorDB.settings.sampleInterval = tonumber(CoADungeonNavigatorDB.settings.sampleInterval) or DEFAULT_SAMPLE_INTERVAL
    CoADungeonNavigatorDB.settings.minDistance = tonumber(CoADungeonNavigatorDB.settings.minDistance) or DEFAULT_MIN_DISTANCE
    CoADungeonNavigatorDB.sessions = CoADungeonNavigatorDB.sessions or {}
    CoADungeonNavigatorDB.window = CoADungeonNavigatorDB.window or {}
    CoADungeonNavigatorDB.recorder = CoADungeonNavigatorDB.recorder or {}
    CoADungeonNavigatorDB.minimap = CoADungeonNavigatorDB.minimap or {}
    if type(CoADungeonNavigatorDB.minimap.angle) ~= "number" then CoADungeonNavigatorDB.minimap.angle = 2.65 end
    CoADungeonNavigatorDB.version = ADDON_VERSION
end

local function CurrentInstance()
    local name, instanceType, difficultyIndex, difficultyName, maxPlayers = GetInstanceInfo()
    local mapId = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    return {
        name = name or GetRealZoneText() or GetZoneText() or "Zone inconnue",
        instanceType = instanceType or "none",
        difficultyIndex = tonumber(difficultyIndex) or 0,
        difficultyName = difficultyName or "",
        maxPlayers = tonumber(maxPlayers) or 0,
        mapId = tonumber(mapId) or 0
    }
end

local function InstanceKey(info)
    return tostring(info.name) .. ":" .. tostring(info.instanceType) .. ":" .. tostring(info.difficultyIndex)
end

local function IsDungeon(info)
    return info and info.instanceType == "party"
end

local function CurrentPosition()
    local currentMapId = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local expectedMapId = activeSession and activeSession.instance and activeSession.instance.mapId or 0
    if expectedMapId > 0 and currentMapId ~= expectedMapId and SetMapToCurrentZone
        and (not WorldMapFrame or not WorldMapFrame:IsShown()) then
        SetMapToCurrentZone()
    end
    local x, y = 0, 0
    if GetPlayerMapPosition then x, y = GetPlayerMapPosition("player") end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    local valid = x > 0.0001 or y > 0.0001
    local floor = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0
    local mapId = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    return {
        x = valid and Round(x, 5) or nil,
        y = valid and Round(y, 5) or nil,
        floor = tonumber(floor) or 0,
        mapId = tonumber(mapId) or 0,
        facing = Round(tonumber(facing) or 0, 4),
        zone = GetZoneText and GetZoneText() or "",
        subZone = GetSubZoneText and GetSubZoneText() or ""
    }
end

local function SessionElapsed(session)
    if not session then return 0 end
    if session.status == "recording" then
        return math.max(0, (tonumber(session.elapsedOffset) or 0) + Now() - (session.startedClock or Now()))
    end
    return tonumber(session.duration) or 0
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function SaveFramePosition(frame, storage)
    if not frame or not storage then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    storage.point = point
    storage.relativePoint = relativePoint
    storage.x = Round(x, 1)
    storage.y = Round(y, 1)
end

local function RestoreFramePosition(frame, storage, fallbackPoint, fallbackRelativePoint, fallbackX, fallbackY)
    frame:ClearAllPoints()
    if storage and storage.point then
        frame:SetPoint(storage.point, UIParent, storage.relativePoint or storage.point, storage.x or 0, storage.y or 0)
    else
        frame:SetPoint(fallbackPoint, UIParent, fallbackRelativePoint, fallbackX, fallbackY)
    end
end

local function AddRoutePoint(force, reason)
    if not activeSession then return nil end
    local position = CurrentPosition()
    local elapsed = SessionElapsed(activeSession)
    local last = activeSession.points[#activeSession.points]
    if not force and last then
        if not position.x or not position.y then
            if elapsed - (last.t or 0) < 10 then return nil end
        elseif last.x and last.y and last.floor == position.floor and last.mapId == position.mapId then
            local dx, dy = position.x - last.x, position.y - last.y
            local minimum = tonumber(CoADungeonNavigatorDB.settings.minDistance) or DEFAULT_MIN_DISTANCE
            if dx * dx + dy * dy < minimum * minimum and elapsed - (last.t or 0) < 4 then return nil end
        end
    end
    if #activeSession.points >= MAX_ROUTE_POINTS then
        activeSession.truncated = true
        return nil
    end
    local point = {
        t = Round(elapsed, 2), x = position.x, y = position.y,
        floor = position.floor, mapId = position.mapId, facing = position.facing,
        zone = position.zone, subZone = position.subZone, reason = reason or "sample"
    }
    table.insert(activeSession.points, point)
    activeSession.lastPosition = point
    return point
end

local function PruneSessions()
    while #CoADungeonNavigatorDB.sessions > MAX_SESSIONS do table.remove(CoADungeonNavigatorDB.sessions, 1) end
end

local function BeginSession(reason, manual)
    EnsureDatabase()
    if activeSession then return activeSession end
    local info = CurrentInstance()
    if not manual and not IsDungeon(info) then return nil end
    local className, classToken = UnitClass("player")
    activeSession = {
        schema = 1,
        id = tostring(Epoch()) .. "-" .. tostring(math.random(1000, 9999)),
        status = "recording",
        reason = reason or "manuel",
        manual = manual and true or false,
        instance = info,
        instanceKey = InstanceKey(info),
        character = {
            className = className or "Inconnue",
            classToken = classToken or "UNKNOWN",
            level = UnitLevel("player") or 0
        },
        startedAt = Epoch(),
        startedClock = Now(),
        elapsedOffset = 0,
        points = {}, pulls = {}, enemies = {}, markers = {}, targets = {}, loot = {}, lootSeen = {},
        deaths = 0, coordinatesAvailable = false, truncated = false
    }
    CoADungeonNavigatorDB.activeSession = activeSession
    AddRoutePoint(true, "start")
    if activeSession.lastPosition and activeSession.lastPosition.x then activeSession.coordinatesAvailable = true end
    Chat("apprentissage démarré dans " .. tostring(info.name) .. ". Je n'enregistre ni le chat ni le nom des joueurs.")
    if recorder then recorder:Show() end
    return activeSession
end

local function EndPull(reason)
    if not activePull then return end
    AddRoutePoint(true, "combat-end")
    activePull.ended = Round(SessionElapsed(activeSession), 2)
    activePull.duration = Round(activePull.ended - (activePull.started or activePull.ended), 2)
    activePull.endReason = reason or "combat"
    activePull.endPosition = activeSession and activeSession.lastPosition or nil
    activePull = nil
    if activeSession then activeSession.currentPull = nil end
end

local function EndSession(reason)
    if not activeSession then return nil end
    EndPull("fin du parcours")
    AddRoutePoint(true, "stop")
    local finalDuration = SessionElapsed(activeSession)
    activeSession.status = "complete"
    activeSession.endedAt = Epoch()
    activeSession.duration = Round(finalDuration, 2)
    activeSession.endReason = reason or "manuel"
    activeSession.currentPull = nil
    local completed = activeSession
    table.insert(CoADungeonNavigatorDB.sessions, completed)
    PruneSessions()
    activeSession = nil
    CoADungeonNavigatorDB.activeSession = nil
    if recorder then recorder:Hide() end
    Chat("parcours enregistré : " .. tostring(completed.instance.name) .. ", "
        .. FormatDuration(completed.duration) .. ", " .. #completed.points .. " points, "
        .. #completed.pulls .. " combats et " .. #completed.markers .. " repères.")
    if CoAMessageCenter and CoAMessageCenter.AddMessage then
        CoAMessageCenter:AddMessage("CoA Dungeon Navigator", "Parcours de " .. tostring(completed.instance.name)
            .. " prêt à exporter (" .. #completed.points .. " points).", "info")
    end
    return completed
end

local function BeginPull()
    if not activeSession or activePull then return end
    local position = AddRoutePoint(true, "combat-start")
    activePull = {
        index = #activeSession.pulls + 1,
        started = Round(SessionElapsed(activeSession), 2),
        startPosition = position,
        enemies = {}, enemyCount = 0, kills = 0, damageDone = 0, damageTaken = 0
    }
    table.insert(activeSession.pulls, activePull)
    activeSession.currentPull = activePull
end

local function HasFlag(flags, mask)
    flags, mask = tonumber(flags), tonumber(mask)
    if not flags or not mask or mask <= 0 then return false end
    if bit and bit.band then return bit.band(flags, mask) ~= 0 end
    return math.floor(flags / mask) % 2 >= 1
end

local function GroupOwned(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_AFFILIATION_MINE)
        or HasFlag(flags, COMBATLOG_OBJECT_AFFILIATION_PARTY)
        or HasFlag(flags, COMBATLOG_OBJECT_AFFILIATION_RAID)
end

local function Hostile(flags)
    return HasFlag(flags, COMBATLOG_OBJECT_REACTION_HOSTILE)
end

local function CaptureEnemy(guid, name, flags, source)
    if not activeSession or not guid or guid == "" then return nil end
    local enemy = activeSession.enemies[guid]
    local elapsed = Round(SessionElapsed(activeSession), 2)
    if not enemy then
        enemy = {
            guid = guid, name = name or "Créature inconnue", firstSeen = elapsed, lastSeen = elapsed,
            encounters = 0, kills = 0, damageDone = 0, damageTaken = 0,
            source = source or "combat", positions = {}
        }
        activeSession.enemies[guid] = enemy
    end
    enemy.name = name or enemy.name
    enemy.lastSeen = elapsed
    if activeSession.lastPosition and #enemy.positions < 12 then
        local previous = enemy.positions[#enemy.positions]
        if not previous or elapsed - (previous.t or 0) >= 3 then
            table.insert(enemy.positions, {
                t = elapsed, x = activeSession.lastPosition.x, y = activeSession.lastPosition.y,
                floor = activeSession.lastPosition.floor, mapId = activeSession.lastPosition.mapId
            })
        end
    end
    if activePull and not activePull.enemies[guid] then
        activePull.enemies[guid] = { guid = guid, name = enemy.name, killed = false }
        activePull.enemyCount = activePull.enemyCount + 1
        enemy.encounters = enemy.encounters + 1
    end
    return enemy
end

local function CaptureTarget()
    if not activeSession or not UnitExists("target") or UnitIsPlayer("target") then return end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return end
    local guid = UnitGUID("target")
    if not guid then return end
    AddRoutePoint(true, "hostile-target")
    local enemy = CaptureEnemy(guid, UnitName("target"), COMBATLOG_OBJECT_REACTION_HOSTILE, "target")
    if not enemy then return end
    enemy.level = UnitLevel("target") or enemy.level
    enemy.classification = UnitClassification and UnitClassification("target") or enemy.classification
    enemy.creatureType = UnitCreatureType and UnitCreatureType("target") or enemy.creatureType
    enemy.maxHealth = math.max(tonumber(enemy.maxHealth) or 0, tonumber(UnitHealthMax("target")) or 0)
    local playerHealth = tonumber(UnitHealthMax and UnitHealthMax("player") or 0) or 0
    enemy.bossCandidate = enemy.classification == "worldboss" or enemy.classification == "rareelite"
        or enemy.level == -1 or (enemy.classification == "elite" and playerHealth > 0
        and (tonumber(enemy.maxHealth) or 0) >= playerHealth * 2.5)
    if not activeSession.targets[guid] then
        activeSession.targets[guid] = { name = enemy.name, firstSeen = enemy.firstSeen, count = 0 }
    end
    activeSession.targets[guid].count = activeSession.targets[guid].count + 1
    activeSession.targets[guid].lastSeen = enemy.lastSeen
end

local function CombatAmount(subevent, ...)
    local rawAmount = nil
    -- select() renvoie toutes les valeurs restantes. L'affectation locale
    -- tronque ce résultat avant tonumber, sinon la valeur suivante devient
    -- par erreur son second argument (la base) sur Lua 5.1.
    if subevent == "SWING_DAMAGE" then rawAmount = select(9, ...)
    elseif string.find(subevent or "", "_DAMAGE", 1, true) then rawAmount = select(12, ...) end
    return tonumber(rawAmount) or 0
end

local function HandleCombatLog(...)
    if not activeSession then return end
    local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
    if not subevent then return end
    local sourceGroup = GroupOwned(sourceFlags)
    local destGroup = GroupOwned(destFlags)
    local sourceHostile = Hostile(sourceFlags)
    local destHostile = Hostile(destFlags)
    local amount = CombatAmount(subevent, ...)

    if sourceGroup and destHostile then
        if not activePull then BeginPull() end
        local enemy = CaptureEnemy(destGUID, destName, destFlags, "combat")
        if enemy then
            enemy.damageTaken = (enemy.damageTaken or 0) + amount
            activePull.damageDone = (activePull.damageDone or 0) + amount
        end
    elseif sourceHostile and destGroup then
        if not activePull then BeginPull() end
        local enemy = CaptureEnemy(sourceGUID, sourceName, sourceFlags, "combat")
        if enemy then
            enemy.damageDone = (enemy.damageDone or 0) + amount
            activePull.damageTaken = (activePull.damageTaken or 0) + amount
        end
    end

    if subevent == "UNIT_DIED" and destGUID and activeSession.enemies[destGUID] then
        local enemy = activeSession.enemies[destGUID]
        enemy.kills = (enemy.kills or 0) + 1
        enemy.lastSeen = Round(SessionElapsed(activeSession), 2)
        if activePull and activePull.enemies[destGUID] and not activePull.enemies[destGUID].killed then
            activePull.enemies[destGUID].killed = true
            activePull.kills = (activePull.kills or 0) + 1
        end
        lastKilledEnemy = {
            guid = destGUID, name = enemy.name, t = Round(SessionElapsed(activeSession), 2),
            bossCandidate = enemy.bossCandidate
        }
    end
end

local function CaptureLootWindow()
    if not activeSession or not GetNumLootItems then return end
    activeSession.loot = activeSession.loot or {}
    activeSession.lootSeen = activeSession.lootSeen or {}
    local elapsed = Round(SessionElapsed(activeSession), 2)
    local source = lastKilledEnemy
    if UnitExists("target") and UnitIsDead("target") and not UnitIsPlayer("target") then
        local classification = UnitClassification and UnitClassification("target") or "normal"
        source = {
            guid = UnitGUID("target"), name = UnitName("target"), t = elapsed,
            bossCandidate = classification == "worldboss" or classification == "rareelite" or classification == "elite"
        }
    end
    if source and elapsed - (source.t or elapsed) > 45 then source = nil end
    local position = AddRoutePoint(true, "loot-opened") or CurrentPosition()
    for slot = 1, GetNumLootItems() do
        local isItem = not LootSlotIsItem or LootSlotIsItem(slot)
        if isItem then
            local texture, visibleName, quantity, quality, locked = GetLootSlotInfo(slot)
            local link = GetLootSlotLink and GetLootSlotLink(slot) or nil
            local itemId = link and tonumber(string.match(link, "item:(%d+)")) or nil
            if link or visibleName then
                local name, canonicalLink, itemQuality, itemLevel, requiredLevel, itemClass, itemSubClass,
                    maxStack, equipLoc, itemTexture = GetItemInfo(link or visibleName)
                local key = tostring(source and source.guid or "unknown") .. ":" .. tostring(itemId or visibleName)
                    .. ":" .. tostring(quantity or 1)
                local previousAt = tonumber(activeSession.lootSeen[key]) or -100
                if elapsed - previousAt > 5 then
                    activeSession.lootSeen[key] = elapsed
                    table.insert(activeSession.loot, {
                        t = elapsed, itemId = itemId or 0, name = name or visibleName or "Objet inconnu",
                        link = canonicalLink or link or "", quantity = tonumber(quantity) or 1,
                        quality = tonumber(itemQuality) or tonumber(quality) or 0,
                        itemLevel = tonumber(itemLevel) or 0, requiredLevel = tonumber(requiredLevel) or 0,
                        itemClass = itemClass or "", itemSubClass = itemSubClass or "", equipLoc = equipLoc or "",
                        texture = itemTexture or texture or "", locked = locked and true or false,
                        sourceGuid = source and source.guid or "", sourceName = source and source.name or "Source inconnue",
                        sourceBossCandidate = source and source.bossCandidate or false,
                        x = position.x, y = position.y, floor = position.floor, mapId = position.mapId
                    })
                end
            end
        end
    end
end

local MARKER_LABELS = {
    shortcut = "Raccourci", door = "Porte", stairs = "Escalier/étage",
    danger = "Danger", boss = "Boss", skip = "Pack évité", note = "Note"
}

local function AddMarker(kind, note)
    if not activeSession then
        Chat("aucun parcours actif. Utilise /cdn start ou entre dans un donjon avec l'apprentissage automatique.")
        return
    end
    local position = AddRoutePoint(true, "marker-" .. tostring(kind)) or CurrentPosition()
    local marker = {
        kind = MARKER_LABELS[kind] and kind or "note",
        label = MARKER_LABELS[kind] or MARKER_LABELS.note,
        note = Trim(note), t = Round(SessionElapsed(activeSession), 2),
        x = position.x, y = position.y, floor = position.floor,
        mapId = position.mapId, zone = position.zone, subZone = position.subZone
    }
    table.insert(activeSession.markers, marker)
    Chat(marker.label .. " mémorisé" .. (marker.note ~= "" and " : " .. marker.note or "."))
end

local function SortedEnemies(session)
    local result = {}
    for _, enemy in pairs(session.enemies or {}) do table.insert(result, enemy) end
    table.sort(result, function(a, b)
        if (a.firstSeen or 0) == (b.firstSeen or 0) then return tostring(a.name) < tostring(b.name) end
        return (a.firstSeen or 0) < (b.firstSeen or 0)
    end)
    return result
end

local function CountEnemies(session)
    local count = 0
    for _ in pairs(session and session.enemies or {}) do count = count + 1 end
    return count
end

local function BuildExport(session)
    if not session then return "Aucun parcours enregistré." end
    local lines = {}
    local info = session.instance or {}
    local character = session.character or {}
    table.insert(lines, table.concat({ EXPORT_FORMAT, "META", Escape(session.id), Escape(ADDON_VERSION),
        Escape(info.name), Escape(info.instanceType), tostring(info.difficultyIndex or 0), Escape(info.difficultyName),
        tostring(info.maxPlayers or 0), tostring(info.mapId or 0), Escape(character.classToken),
        tostring(character.level or 0), tostring(session.startedAt or 0), tostring(Round(SessionElapsed(session), 2)),
        session.coordinatesAvailable and "1" or "0", session.truncated and "1" or "0" }, "\t"))
    for _, point in ipairs(session.points or {}) do
        table.insert(lines, table.concat({ "P", tostring(point.t or 0), tostring(point.x or ""), tostring(point.y or ""),
            tostring(point.floor or 0), tostring(point.mapId or 0), tostring(point.facing or 0),
            Escape(point.zone), Escape(point.subZone), Escape(point.reason) }, "\t"))
    end
    for _, pull in ipairs(session.pulls or {}) do
        table.insert(lines, table.concat({ "C", tostring(pull.index or 0), tostring(pull.started or 0),
            tostring(pull.ended or 0), tostring(pull.duration or 0), tostring(pull.enemyCount or 0),
            tostring(pull.kills or 0), tostring(Round(pull.damageDone, 0)), tostring(Round(pull.damageTaken, 0)) }, "\t"))
        local pullEnemies = {}
        for _, enemy in pairs(pull.enemies or {}) do table.insert(pullEnemies, enemy) end
        table.sort(pullEnemies, function(a, b) return tostring(a.guid) < tostring(b.guid) end)
        for _, enemy in ipairs(pullEnemies) do
            table.insert(lines, table.concat({ "CE", tostring(pull.index or 0), Escape(enemy.guid),
                Escape(enemy.name), enemy.killed and "1" or "0" }, "\t"))
        end
    end
    for _, enemy in ipairs(SortedEnemies(session)) do
        table.insert(lines, table.concat({ "E", Escape(enemy.guid), Escape(enemy.name), tostring(enemy.level or ""),
            Escape(enemy.classification), Escape(enemy.creatureType), tostring(enemy.firstSeen or 0),
            tostring(enemy.lastSeen or 0), tostring(enemy.encounters or 0), tostring(enemy.kills or 0),
            tostring(Round(enemy.damageTaken, 0)), tostring(Round(enemy.damageDone, 0)),
            enemy.bossCandidate and "1" or "0", tostring(enemy.maxHealth or 0) }, "\t"))
    end
    for _, marker in ipairs(session.markers or {}) do
        table.insert(lines, table.concat({ "M", Escape(marker.kind), Escape(marker.note), tostring(marker.t or 0),
            tostring(marker.x or ""), tostring(marker.y or ""), tostring(marker.floor or 0),
            tostring(marker.mapId or 0), Escape(marker.zone), Escape(marker.subZone) }, "\t"))
    end
    for _, loot in ipairs(session.loot or {}) do
        table.insert(lines, table.concat({ "L", tostring(loot.t or 0), tostring(loot.itemId or 0), Escape(loot.name),
            tostring(loot.quantity or 1), tostring(loot.quality or 0), tostring(loot.itemLevel or 0),
            tostring(loot.requiredLevel or 0), Escape(loot.itemClass), Escape(loot.itemSubClass), Escape(loot.equipLoc),
            Escape(loot.sourceGuid), Escape(loot.sourceName), loot.sourceBossCandidate and "1" or "0",
            tostring(loot.x or ""), tostring(loot.y or ""), tostring(loot.floor or 0), tostring(loot.mapId or 0) }, "\t"))
    end
    table.insert(lines, table.concat({ "END", tostring(#(session.points or {})), tostring(#(session.pulls or {})),
        tostring(CountEnemies(session)), tostring(#(session.markers or {})), tostring(session.deaths or 0),
        tostring(#(session.loot or {})) }, "\t"))
    return table.concat(lines, "\n")
end

local function LatestSession()
    if activeSession then return activeSession end
    return CoADungeonNavigatorDB.sessions[#CoADungeonNavigatorDB.sessions]
end

local function PositionMinimapButton()
    if not minimapButton or not Minimap then return end
    local angle = CoADungeonNavigatorDB.minimap.angle or 2.65
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function ShowExport(session)
    if not session then
        Chat("aucun parcours à exporter.")
        return
    end
    exportEditBox:SetText(BuildExport(session))
    exportEditBox:SetCursorPosition(0)
    exportFrame:Show()
    exportEditBox:SetFocus()
    exportEditBox:HighlightText()
end

local function RefreshDisplay()
    if not initialized then return end
    local session = activeSession or LatestSession()
    if activeSession then
        statusText:SetText("|cff65e57a● ENREGISTREMENT EN COURS|r  •  " .. tostring(activeSession.instance.name))
        detailText:SetText(FormatDuration(SessionElapsed(activeSession)) .. "  •  " .. #activeSession.points .. " points  •  "
            .. #activeSession.pulls .. " combats  •  " .. CountEnemies(activeSession) .. " créatures  •  "
            .. #activeSession.markers .. " repères  •  " .. #(activeSession.loot or {}) .. " objets vus")
        recordButton:SetText("Arrêter et sauvegarder")
        recorder.text:SetText("|cff65e57a●|r Apprentissage  " .. FormatDuration(SessionElapsed(activeSession))
            .. "  •  " .. #activeSession.points .. " pts")
        recorder:Show()
    else
        statusText:SetText("|cff94a3b8En attente d'un donjon|r")
        if session then
            detailText:SetText("Dernier : " .. tostring(session.instance.name) .. "  •  " .. FormatDuration(session.duration)
                .. "  •  " .. #session.points .. " points  •  " .. #session.pulls .. " combats  •  "
                .. #(session.loot or {}) .. " objets vus")
        else
            detailText:SetText("Aucun parcours enregistré pour le moment.")
        end
        recordButton:SetText("Démarrer maintenant")
        recorder:Hide()
    end
    autoButton:SetText(CoADungeonNavigatorDB.settings.autoRecord and "Auto : ACTIVÉ" or "Auto : DÉSACTIVÉ")
    local history = {}
    local first = math.max(1, #CoADungeonNavigatorDB.sessions - 4)
    for index = #CoADungeonNavigatorDB.sessions, first, -1 do
        local item = CoADungeonNavigatorDB.sessions[index]
        table.insert(history, "|cffffd35a" .. tostring(item.instance.name) .. "|r  " .. FormatDuration(item.duration)
            .. "  •  " .. #item.points .. " pts  •  " .. #item.pulls .. " combats  •  " .. #item.markers .. " repères")
    end
    historyText:SetText(#history > 0 and table.concat(history, "\n") or "Les derniers parcours apparaîtront ici.")
end

local function EvaluateAutoRecording(reason)
    local info = CurrentInstance()
    if activeSession and activeSession.instanceKey ~= InstanceKey(info) then EndSession("changement d'instance") end
    if CoADungeonNavigatorDB.settings.autoRecord and IsDungeon(info) and not activeSession then
        BeginSession(reason or "automatique", false)
    elseif activeSession and not activeSession.manual and not IsDungeon(info) then
        EndSession("sortie du donjon")
    end
    RefreshDisplay()
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

panel = CreateFrame("Frame", "CoADungeonNavigatorLearningFrame", UIParent)
panel:SetWidth(510)
panel:SetHeight(430)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetClampedToScreen(true)
panel:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
panel:SetBackdropColor(0.025, 0.04, 0.07, 0.97)
panel:SetBackdropBorderColor(0.25, 0.75, 0.95, 0.92)
panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition(self, CoADungeonNavigatorDB.window)
end)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
title:SetText("CoA • Collecte avancée")
title:SetTextColor(0.35, 0.85, 1)

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
subtitle:SetWidth(472)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("APPRENTISSAGE  •  enregistre les trajets qui serviront aux prochains guides")

statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -70)
statusText:SetWidth(474)
statusText:SetJustifyH("LEFT")

detailText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
detailText:SetWidth(474)
detailText:SetJustifyH("LEFT")

recordButton = MakeButton(panel, "Démarrer maintenant", 180, 18, -117, function()
    if activeSession then EndSession("bouton") else BeginSession("manuel", true) end
    RefreshDisplay()
end)
autoButton = MakeButton(panel, "Auto : ACTIVÉ", 140, 207, -117, function()
    CoADungeonNavigatorDB.settings.autoRecord = not CoADungeonNavigatorDB.settings.autoRecord
    if CoADungeonNavigatorDB.settings.autoRecord then EvaluateAutoRecording("activation automatique") end
    RefreshDisplay()
end)
MakeButton(panel, "Exporter", 136, 356, -117, function() ShowExport(LatestSession()) end)

local markerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
markerTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -158)
markerTitle:SetText("MARQUER CE QUE TU VIENS DE VOIR")
markerTitle:SetTextColor(1, 0.82, 0.30)

MakeButton(panel, "Raccourci", 108, 18, -178, function() AddMarker("shortcut") RefreshDisplay() end)
MakeButton(panel, "Porte", 84, 132, -178, function() AddMarker("door") RefreshDisplay() end)
MakeButton(panel, "Escalier", 88, 222, -178, function() AddMarker("stairs") RefreshDisplay() end)
MakeButton(panel, "Danger", 82, 316, -178, function() AddMarker("danger") RefreshDisplay() end)
MakeButton(panel, "Boss", 88, 404, -178, function() AddMarker("boss") RefreshDisplay() end)
MakeButton(panel, "Pack évité", 108, 18, -209, function() AddMarker("skip") RefreshDisplay() end)
MakeButton(panel, "Note rapide", 108, 132, -209, function() AddMarker("note") RefreshDisplay() end)

local markerHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
markerHelp:SetPoint("TOPLEFT", panel, "TOPLEFT", 250, -214)
markerHelp:SetWidth(240)
markerHelp:SetJustifyH("LEFT")
markerHelp:SetText("Pour ajouter du texte : /cdn mark raccourci passage à gauche")

local privacy = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
privacy:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -250)
privacy:SetWidth(474)
privacy:SetJustifyH("LEFT")
privacy:SetText("L'addon relève le trajet, les créatures, les combats, les objets vus et tes repères. Il n'enregistre jamais le chat ni le nom des autres joueurs.")

local historyTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
historyTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -292)
historyTitle:SetText("DERNIERS PARCOURS")
historyTitle:SetTextColor(1, 0.82, 0.30)

historyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
historyText:SetPoint("TOPLEFT", historyTitle, "BOTTOMLEFT", 0, -8)
historyText:SetWidth(474)
historyText:SetHeight(72)
historyText:SetJustifyH("LEFT")
historyText:SetJustifyV("TOP")

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

recorder = CreateFrame("Button", "CoADungeonNavigatorRecorder", UIParent)
recorder:SetWidth(235)
recorder:SetHeight(28)
recorder:SetPoint("TOP", UIParent, "TOP", 0, -28)
recorder:SetFrameStrata("HIGH")
recorder:SetMovable(true)
recorder:EnableMouse(true)
recorder:RegisterForClicks("LeftButtonUp")
recorder:RegisterForDrag("LeftButton")
recorder:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
recorder:SetBackdropColor(0.02, 0.04, 0.05, 0.82)
recorder:SetBackdropBorderColor(0.20, 0.85, 0.55, 0.85)
recorder.text = recorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
recorder.text:SetPoint("CENTER", recorder, "CENTER", 0, 0)
recorder:SetScript("OnClick", function() API:Toggle() end)
recorder:SetScript("OnDragStart", function(self) self:StartMoving() end)
recorder:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition(self, CoADungeonNavigatorDB.recorder)
end)
recorder:Hide()

exportFrame = CreateFrame("Frame", "CoADungeonNavigatorExportFrame", UIParent)
exportFrame:SetWidth(690)
exportFrame:SetHeight(520)
exportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
exportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
exportFrame:EnableMouse(true)
exportFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
exportFrame:SetBackdropColor(0.02, 0.03, 0.05, 0.98)
exportFrame:SetBackdropBorderColor(0.25, 0.75, 0.95, 0.95)
exportFrame:Hide()

local exportTitle = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
exportTitle:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 18, -16)
exportTitle:SetText("Export du parcours")
local exportHelp = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportHelp:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -8)
exportHelp:SetWidth(650)
exportHelp:SetJustifyH("LEFT")
exportHelp:SetText("Le texte est déjà sélectionné : Ctrl+C, puis colle-le dans Codex. Aucun nom de joueur ni message de chat n'est inclus.")

local exportScroll = CreateFrame("ScrollFrame", "CoADungeonNavigatorExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 18, -76)
exportScroll:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -38, 54)
exportEditBox = CreateFrame("EditBox", "CoADungeonNavigatorExportText", exportScroll)
exportEditBox:SetWidth(620)
exportEditBox:SetHeight(380)
exportEditBox:SetMultiLine(true)
exportEditBox:SetAutoFocus(false)
exportEditBox:SetFontObject(ChatFontNormal)
if exportEditBox.SetTextInsets then exportEditBox:SetTextInsets(6, 6, 6, 6) end
exportEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() exportFrame:Hide() end)
exportEditBox:SetScript("OnTextChanged", function(self) exportScroll:UpdateScrollChildRect() end)
exportScroll:SetScrollChild(exportEditBox)
MakeButton(exportFrame, "Tout sélectionner", 150, 18, -478, function() exportEditBox:SetFocus() exportEditBox:HighlightText() end)
MakeButton(exportFrame, "Fermer", 110, 562, -478, function() exportFrame:Hide() end)

minimapButton = CreateFrame("Button", "CoADungeonNavigatorMinimapButton", Minimap)
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
local miniBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
miniBackground:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
miniBackground:SetWidth(54)
miniBackground:SetHeight(54)
miniBackground:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
local miniIcon = minimapButton:CreateTexture(nil, "ARTWORK")
miniIcon:SetTexture("Interface/Icons/INV_Misc_Map_01")
miniIcon:SetWidth(20)
miniIcon:SetHeight(20)
miniIcon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
minimapButton:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" and API.ToggleLearning then API:ToggleLearning()
    else API:Toggle() end
end)
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("CoA Dungeon Navigator")
    GameTooltip:AddLine("Ouvre le guide de donjon. Clic droit : collecte avancée.", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

function API:Toggle()
    if panel:IsShown() then panel:Hide() else panel:Show() RefreshDisplay() end
end

function API:Show()
    panel:Show()
    RefreshDisplay()
end

function API:ToggleLearning()
    if panel:IsShown() then panel:Hide() else panel:Show() RefreshDisplay() end
end

function API:ShowLearning()
    panel:Show()
    RefreshDisplay()
end

function API:GetActiveSession()
    return activeSession
end

function API:GetLatestSession()
    return LatestSession()
end

function API:AddMarker(kind, note)
    AddMarker(kind, note)
    RefreshDisplay()
end

function API:SetHubManaged(value)
    hubManaged = value and true or false
    if hubManaged then minimapButton:Hide() else minimapButton:Show() end
end

function API:IsRecording()
    return activeSession ~= nil
end

function API:Start()
    return BeginSession("API", true)
end

function API:Stop()
    return EndSession("API")
end

function API:ExportLatest()
    return BuildExport(LatestSession())
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        EnsureDatabase()
        activeSession = CoADungeonNavigatorDB.activeSession
        if activeSession and activeSession.status == "recording" then
            activeSession.loot = activeSession.loot or {}
            activeSession.lootSeen = activeSession.lootSeen or {}
            local savedAt = tonumber(activeSession.lastSavedAt) or Epoch()
            local savedElapsed = tonumber(activeSession.lastSavedElapsed) or tonumber(activeSession.elapsedOffset) or 0
            activeSession.elapsedOffset = savedElapsed
            activeSession.startedClock = Now()
            activeSession.currentPull = nil
            activePull = nil
            if Epoch() - savedAt > 600 then
                activeSession.duration = savedElapsed
                activeSession.status = "complete"
                activeSession.endReason = "ancienne session interrompue"
                table.insert(CoADungeonNavigatorDB.sessions, activeSession)
                PruneSessions()
                activeSession = nil
                CoADungeonNavigatorDB.activeSession = nil
            end
        end
        RestoreFramePosition(panel, CoADungeonNavigatorDB.window, "CENTER", "CENTER", 0, 20)
        RestoreFramePosition(recorder, CoADungeonNavigatorDB.recorder, "TOP", "TOP", 0, -28)
        PositionMinimapButton()
        initialized = true
        RefreshDisplay()
    elseif not initialized then
        return
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if SetMapToCurrentZone and (not WorldMapFrame or not WorldMapFrame:IsShown()) then SetMapToCurrentZone() end
        zoneCheckAt = Now() + 1.5
    elseif event == "PLAYER_TARGET_CHANGED" then
        CaptureTarget()
    elseif event == "PLAYER_REGEN_DISABLED" then
        BeginPull()
        CaptureTarget()
    elseif event == "PLAYER_REGEN_ENABLED" then
        EndPull("fin du combat")
    elseif event == "PLAYER_DEAD" then
        if activeSession then activeSession.deaths = (activeSession.deaths or 0) + 1 end
    elseif event == "PLAYER_LOGOUT" then
        if activeSession then
            EndPull("rechargement ou déconnexion")
            activeSession.lastSavedElapsed = SessionElapsed(activeSession)
            activeSession.lastSavedAt = Epoch()
            activeSession.elapsedOffset = activeSession.lastSavedElapsed
            CoADungeonNavigatorDB.activeSession = activeSession
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLog(...)
    elseif event == "LOOT_OPENED" then
        lootCaptureUntil = Now() + 1.5
        lootRetryElapsed = 0
        CaptureLootWindow()
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    if zoneCheckAt and Now() >= zoneCheckAt then
        zoneCheckAt = nil
        EvaluateAutoRecording("entrée en donjon")
    end
    updateElapsed = updateElapsed + elapsed
    if activeSession and updateElapsed >= (CoADungeonNavigatorDB.settings.sampleInterval or DEFAULT_SAMPLE_INTERVAL) then
        updateElapsed = 0
        local point = AddRoutePoint(false, "sample")
        if point and point.x then activeSession.coordinatesAvailable = true end
    end
    if activeSession and lootCaptureUntil then
        lootRetryElapsed = lootRetryElapsed + elapsed
        if lootRetryElapsed >= 0.20 then
            lootRetryElapsed = 0
            CaptureLootWindow()
        end
        if Now() >= lootCaptureUntil then lootCaptureUntil = nil end
    end
    statusElapsed = statusElapsed + elapsed
    if statusElapsed >= 0.5 then
        statusElapsed = 0
        RefreshDisplay()
    end
end)

SLASH_COADUNGEONNAVIGATOR1 = "/cdn"
SLASH_COADUNGEONNAVIGATOR2 = "/dungeonnav"
SlashCmdList.COADUNGEONNAVIGATOR = function(message)
    local command, rest = string.match(Trim(message), "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    if command == "" or command == "show" then
        API:Toggle()
    elseif command == "start" then
        BeginSession("commande", true)
    elseif command == "stop" then
        EndSession("commande")
    elseif command == "status" then
        if activeSession then
            Chat("enregistrement de " .. tostring(activeSession.instance.name) .. " depuis "
                .. FormatDuration(SessionElapsed(activeSession)) .. " : " .. #activeSession.points .. " points, "
                .. #activeSession.pulls .. " combats, " .. CountEnemies(activeSession) .. " créatures.")
        else
            Chat("aucun enregistrement en cours ; " .. #CoADungeonNavigatorDB.sessions .. " parcours conservé(s).")
        end
    elseif command == "auto" then
        local choice = string.lower(Trim(rest))
        if choice == "on" then CoADungeonNavigatorDB.settings.autoRecord = true
        elseif choice == "off" then CoADungeonNavigatorDB.settings.autoRecord = false
        else CoADungeonNavigatorDB.settings.autoRecord = not CoADungeonNavigatorDB.settings.autoRecord end
        Chat("apprentissage automatique " .. (CoADungeonNavigatorDB.settings.autoRecord and "activé." or "désactivé."))
        EvaluateAutoRecording("commande auto")
    elseif command == "mark" then
        local marker, note = string.match(rest, "^(%S+)%s*(.-)$")
        marker = string.lower(marker or "note")
        local aliases = { raccourci = "shortcut", porte = "door", escalier = "stairs", danger = "danger", boss = "boss", skip = "skip", evite = "skip", note = "note" }
        AddMarker(aliases[marker] or marker, note)
    elseif command == "export" then
        ShowExport(LatestSession())
    else
        Chat("commandes : /cdn, start, stop, status, auto on|off, mark raccourci|porte|escalier|danger|boss|skip [note], export")
    end
    RefreshDisplay()
end
