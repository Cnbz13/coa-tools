local addonName = ...

local DEFAULT_FRAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
    "MinimapCluster", "BuffFrame", "WatchFrame", "CastingBarFrame",
    "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "BonusActionBarFrame", "PetActionBarFrame", "ShapeshiftBarFrame", "PossessBarFrame",
    "CoACombatAssistantFrame", "EA_Main_Frame", "EA_Anchor_Frame", "CoAUIManagerPanel",
    "CoALootDeciderBanner", "CoALootAdvisorWindow", "CoAHereticProcAnchor",
    "CoAHereticBlackBloodTracker", "CoAHereticHUDMenu", "CoAMessageCenterFrame",
    "CoARotationGuideFrame", "CoARotationGuideHUD", "CoADungeonNavigatorFrame", "CoADungeonNavigatorHUD",
    "CoADungeonNavigatorLearningFrame", "CoADungeonNavigatorRecorder",
    "CoAStormbringerHUD", "CoAStormbringerMenu", "CoAStormbringerLevelToast",
    "CoAPrimalistHUD", "CoAPrimalistMenu", "CoAPrimalistLevelToast",
    "CoAEssentialAssistantHUD", "CoAEssentialResourceHUD", "CoAEssentialTargetHUD", "CoAEssentialCoverageHUD", "CoAEssentialAssistantSettings"
}

local FRAME_LABELS = {
    PlayerFrame = "Joueur", TargetFrame = "Cible", FocusFrame = "Focus", PetFrame = "Familier",
    PartyMemberFrame1 = "Groupe 1", PartyMemberFrame2 = "Groupe 2",
    PartyMemberFrame3 = "Groupe 3", PartyMemberFrame4 = "Groupe 4",
    MinimapCluster = "Minicarte", BuffFrame = "Améliorations", WatchFrame = "Quêtes",
    CastingBarFrame = "Incantation", MainMenuBar = "Barre principale",
    MultiBarBottomLeft = "Barre bas gauche", MultiBarBottomRight = "Barre bas droite",
    MultiBarRight = "Barre droite", MultiBarLeft = "Barre gauche",
    BonusActionBarFrame = "Barre bonus", PetActionBarFrame = "Barre familier",
    ShapeshiftBarFrame = "Barre formes", PossessBarFrame = "Barre contrôle",
    CoACombatAssistantFrame = "CoA Combat Assistant", CoAUIManagerPanel = "Centre CoA",
    CoALootDeciderBanner = "Décision de butin", CoALootAdvisorWindow = "Comparateur de butin",
    CoAHereticProcAnchor = "Heretic : proc", CoAHereticBlackBloodTracker = "Heretic : Sang noir",
    CoAHereticHUDMenu = "Réglages Heretic", CoAMessageCenterFrame = "Messages CoA",
    CoARotationGuideFrame = "Guide de rotation", CoARotationGuideHUD = "Rotation : prochain sort", CoADungeonNavigatorFrame = "Navigateur de donjon",
    CoADungeonNavigatorHUD = "Flèche discrète de donjon", CoADungeonNavigatorLearningFrame = "Collecte de donjon",
    CoADungeonNavigatorRecorder = "Enregistrement de donjon",
    CoAStormbringerHUD = "Stormbringer : conseil", CoAStormbringerMenu = "Réglages Stormbringer",
    CoAStormbringerLevelToast = "Stormbringer : niveau",
    CoAPrimalistHUD = "Primalist : conseil", CoAPrimalistMenu = "Réglages Primalist",
    CoAPrimalistLevelToast = "Primalist : niveau",
    CoAEssentialAssistantHUD = "Essentiel : procs", CoAEssentialResourceHUD = "Essentiel : ressource",
    CoAEssentialTargetHUD = "Essentiel : effet cible", CoAEssentialCoverageHUD = "Essentiel : couverture groupe",
    CoAEssentialAssistantSettings = "Réglages Essentiel"
}

local movers = {}
local originals = {}
local unlocked = false
local selectedName = nil
local pendingApply = false
local scheduledAt = {}
local initialized = false
local minimapButton = nil
local minimapUnreadText = nil
local nextBadgeUpdate = 0

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66CoA UI Manager:|r " .. tostring(message))
    end
end

local function Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function ResolveFrame(name)
    local object = _G[name]
    local kind = type(object)
    if kind ~= "table" and kind ~= "userdata" then return nil end
    if type(object.GetPoint) ~= "function" or type(object.SetPoint) ~= "function" then return nil end
    return object
end

local function CharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Ascension"
    return name .. "-" .. realm
end

local function EnsureDatabase()
    CoAUIManagerDB = CoAUIManagerDB or {}
    CoAUIManagerDB.profiles = CoAUIManagerDB.profiles or {}
    CoAUIManagerDB.profiles.global = CoAUIManagerDB.profiles.global or { frames = {} }
    CoAUIManagerDB.profiles.characters = CoAUIManagerDB.profiles.characters or {}
    CoAUIManagerDB.characterModes = CoAUIManagerDB.characterModes or {}
    CoAUIManagerDB.customFrames = CoAUIManagerDB.customFrames or {}
    CoAUIManagerDB.minimap = CoAUIManagerDB.minimap or {}
    if type(CoAUIManagerDB.minimap.angle) ~= "number" then CoAUIManagerDB.minimap.angle = 3.9 end
    if type(CoAUIManagerDB.minimap.hidden) ~= "boolean" then CoAUIManagerDB.minimap.hidden = false end
end

local function ProfileMode()
    EnsureDatabase()
    return CoAUIManagerDB.characterModes[CharacterKey()] == "CHARACTER" and "CHARACTER" or "GLOBAL"
end

local function ActiveProfile()
    EnsureDatabase()
    if ProfileMode() == "CHARACTER" then
        local key = CharacterKey()
        CoAUIManagerDB.profiles.characters[key] = CoAUIManagerDB.profiles.characters[key] or { frames = {} }
        return CoAUIManagerDB.profiles.characters[key]
    end
    return CoAUIManagerDB.profiles.global
end

local function FrameSetting(name, create)
    local profile = ActiveProfile()
    profile.frames = profile.frames or {}
    if create and not profile.frames[name] then profile.frames[name] = {} end
    return profile.frames[name]
end

local function CaptureOriginal(name, target)
    if originals[name] then return end
    local point, relative, relativePoint, x, y = target:GetPoint(1)
    originals[name] = {
        point = point, relative = relative, relativePoint = relativePoint, x = x, y = y,
        scale = target:GetScale(), alpha = target:GetAlpha(), width = target:GetWidth(), height = target:GetHeight()
    }
end

local function RestoreOriginal(name, target)
    local original = originals[name]
    if not original then return end
    target:ClearAllPoints()
    if original.point then
        target:SetPoint(original.point, original.relative or UIParent, original.relativePoint or original.point, original.x or 0, original.y or 0)
    end
    if original.scale then target:SetScale(original.scale) end
    if original.alpha then target:SetAlpha(original.alpha) end
    if original.width and original.width > 0 then target:SetWidth(original.width) end
    if original.height and original.height > 0 then target:SetHeight(original.height) end
end

local function ApplyTarget(name)
    local target = ResolveFrame(name)
    if not target or target == UIParent then return false end
    CaptureOriginal(name, target)
    if InCombatLockdown and InCombatLockdown() then
        pendingApply = true
        return false
    end
    local setting = FrameSetting(name, false)
    if not setting then
        -- Une frame sans réglage appartient à son addon. La restaurer ici
        -- écrasait notamment la position sauvegardée par Combat Assistant à
        -- chaque PLAYER_REGEN_ENABLED.
        return true
    end
    if setting.point then
        target:ClearAllPoints()
        target:SetPoint(setting.point, UIParent, setting.relativePoint or "BOTTOMLEFT", setting.x or 0, setting.y or 0)
    end
    if setting.scale then target:SetScale(Clamp(setting.scale, 0.4, 2.5)) end
    if setting.alpha then target:SetAlpha(Clamp(setting.alpha, 0.15, 1)) end
    if setting.width and setting.width > 0 then target:SetWidth(setting.width) end
    if setting.height and setting.height > 0 then target:SetHeight(setting.height) end
    return true
end

local function ForEachFrameName(callback)
    local seen = {}
    local index, name
    for index, name in ipairs(DEFAULT_FRAMES) do
        if not seen[name] then
            seen[name] = true
            callback(name)
        end
    end
    EnsureDatabase()
    for index, name in ipairs(CoAUIManagerDB.customFrames) do
        if not seen[name] then
            seen[name] = true
            callback(name)
        end
    end
end

local function ApplyAll()
    if InCombatLockdown and InCombatLockdown() then
        pendingApply = true
        return
    end
    pendingApply = false
    ForEachFrameName(ApplyTarget)
end

local panel = CreateFrame("Frame", "CoAUIManagerPanel", UIParent)
panel:SetWidth(370)
panel:SetHeight(275)
panel:SetPoint("TOP", UIParent, "TOP", 0, -90)
panel:SetFrameStrata("DIALOG")
panel:SetFrameLevel(20)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
panel:SetBackdropColor(0.03, 0.04, 0.07, 0.96)
panel:SetBackdropBorderColor(0.75, 0.55, 0.25, 0.9)
panel:Hide()

local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panelTitle:SetPoint("TOP", panel, "TOP", 0, -14)
panelTitle:SetText("Centre CoA")

local panelStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panelStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -44)
panelStatus:SetWidth(334)
panelStatus:SetJustifyH("LEFT")
panelStatus:SetText("/cui unlock pour afficher les movers")

local panelHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
panelHelp:SetPoint("TOPLEFT", panelStatus, "BOTTOMLEFT", 0, -8)
panelHelp:SetWidth(334)
panelHelp:SetJustifyH("LEFT")
panelHelp:SetText("Glisser: position  •  Molette: échelle  •  Maj+molette: alpha\nBouton rouge en haut: terminer  •  /cui add NomDuFrame")

local hubLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hubLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -94)
hubLabel:SetText("OUTILS COA")
hubLabel:SetTextColor(0.35, 0.82, 1.00)

local function HubButton(text, x, y)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetWidth(78)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y or -112)
    button:SetText(text)
    return button
end

local hereticHubButton = HubButton("Heretic", 18)
local rotationHubButton = HubButton("Rotations", 101)
local messagesHubButton = HubButton("Messages", 184)
local dungeonHubButton = HubButton("Donjons", 267)
local essentialHubButton = HubButton("Essentiel", 18, -140)
local stormHubButton = HubButton("Storm", 101, -140)
local primalistHubButton = HubButton("Primalist", 184, -140)

local hubHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hubHint:SetPoint("TOPLEFT", panel, "TOPLEFT", 267, -143)
hubHint:SetWidth(82)
hubHint:SetJustifyH("LEFT")
hubHint:SetText("Réglages via minicarte.")

hereticHubButton:SetScript("OnClick", function()
    if CoAHereticHelperAPI and CoAHereticHelperAPI.Toggle then
        CoAHereticHelperAPI:Toggle()
    else
        Chat("CoA Heretic Helper n'est pas chargé pour ce personnage.")
    end
end)
rotationHubButton:SetScript("OnClick", function()
    if CoARotationGuideAPI and CoARotationGuideAPI.Toggle then
        CoARotationGuideAPI:Toggle()
    else
        Chat("CoA Rotation Guide n'est pas chargé.")
    end
end)
messagesHubButton:SetScript("OnClick", function()
    if CoAMessageCenter and CoAMessageCenter.Toggle then CoAMessageCenter:Toggle()
    else Chat("CoA Message Center n'est pas chargé.") end
end)
dungeonHubButton:SetScript("OnClick", function()
    if CoADungeonNavigatorAPI and CoADungeonNavigatorAPI.Toggle then
        CoADungeonNavigatorAPI:Toggle()
    else
        Chat("CoA Dungeon Navigator n'est pas chargé.")
    end
end)
stormHubButton:SetScript("OnClick", function()
    if CoAStormbringerHelperAPI and CoAStormbringerHelperAPI.Toggle then
        CoAStormbringerHelperAPI:Toggle()
    else
        Chat("CoA Stormbringer Helper n'est pas chargé pour ce personnage.")
    end
end)
primalistHubButton:SetScript("OnClick", function()
    if CoAPrimalistHelperAPI and CoAPrimalistHelperAPI.Toggle then
        CoAPrimalistHelperAPI:Toggle()
    else
        Chat("CoA Primalist Helper n'est pas chargé pour ce personnage.")
    end
end)
essentialHubButton:SetScript("OnClick", function()
    if CoAEssentialAssistantAPI and CoAEssentialAssistantAPI.Toggle then
        CoAEssentialAssistantAPI:Toggle()
    else
        Chat("CoA Essential Assistant n'est pas chargé.")
    end
end)

local function UpdateHubBadge()
    local unread = tonumber(CoAMessageCenterDB and CoAMessageCenterDB.unread) or 0
    messagesHubButton:SetText(unread > 0 and ("Messages (" .. tostring(unread) .. ")") or "Messages")
    if minimapUnreadText then minimapUnreadText:SetText(unread > 0 and tostring(unread) or "") end
end

local function UpdateHubAvailability()
    if CoAHereticHelperAPI and CoAHereticHelperAPI.SetHubManaged then CoAHereticHelperAPI:SetHubManaged(true) end
    if CoARotationGuideAPI and CoARotationGuideAPI.SetHubManaged then CoARotationGuideAPI:SetHubManaged(true) end
    if CoAMessageCenter and CoAMessageCenter.SetHubManaged then CoAMessageCenter:SetHubManaged(true) end
    if CoADungeonNavigatorAPI and CoADungeonNavigatorAPI.SetHubManaged then CoADungeonNavigatorAPI:SetHubManaged(true) end
    if CoAStormbringerHelperAPI and CoAStormbringerHelperAPI.SetHubManaged then CoAStormbringerHelperAPI:SetHubManaged(true) end
    if CoAPrimalistHelperAPI and CoAPrimalistHelperAPI.SetHubManaged then CoAPrimalistHelperAPI:SetHubManaged(true) end
    if CoAEssentialAssistantAPI and CoAEssentialAssistantAPI.SetHubManaged then CoAEssentialAssistantAPI:SetHubManaged(true) end
    if CoAHereticHelperAPI and CoAHereticHelperAPI.Toggle then hereticHubButton:Enable() else hereticHubButton:Disable() end
    if CoARotationGuideAPI and CoARotationGuideAPI.Toggle then rotationHubButton:Enable() else rotationHubButton:Disable() end
    if CoAMessageCenter and CoAMessageCenter.Toggle then messagesHubButton:Enable() else messagesHubButton:Disable() end
    if CoADungeonNavigatorAPI and CoADungeonNavigatorAPI.Toggle then dungeonHubButton:Enable() else dungeonHubButton:Disable() end
    if CoAStormbringerHelperAPI and CoAStormbringerHelperAPI.Toggle then stormHubButton:Enable() else stormHubButton:Disable() end
    if CoAPrimalistHelperAPI and CoAPrimalistHelperAPI.Toggle then primalistHubButton:Enable() else primalistHubButton:Disable() end
    if CoAEssentialAssistantAPI and CoAEssentialAssistantAPI.Toggle then essentialHubButton:Enable() else essentialHubButton:Disable() end
    UpdateHubBadge()
end

local lockButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
lockButton:SetWidth(92)
lockButton:SetHeight(22)
lockButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 14)
lockButton:SetText("Verrouiller")

local closeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
closeButton:SetWidth(72)
closeButton:SetHeight(22)
closeButton:SetPoint("RIGHT", lockButton, "LEFT", -8, 0)
closeButton:SetText("Fermer")
closeButton:SetScript("OnClick", function() panel:Hide() end)

local function UpdatePanelStatus()
    local selected = selectedName or "aucun"
    panelStatus:SetText("Profil: " .. ProfileMode() .. "  •  Sélection: " .. selected)
end

local function UpdateMoverLabel(name)
    local mover = movers[name]
    if not mover then return end
    local target = _G[name]
    local setting = FrameSetting(name, false) or {}
    local scale = setting.scale or (target and target:GetScale()) or 1
    local alpha = setting.alpha or (target and target:GetAlpha()) or 1
    mover.label:SetText((FRAME_LABELS[name] or name) .. string.format("\nS %.2f  A %.2f", scale, alpha))
end

local function SyncMover(name)
    local mover = movers[name]
    local target = ResolveFrame(name)
    if not mover or not target then return end
    local centerX, centerY = target:GetCenter()
    if not centerX or not centerY then
        centerX, centerY = UIParent:GetCenter()
    end
    local width = target:GetWidth() or 100
    local height = target:GetHeight() or 30
    if name == "CoAUIManagerPanel" then height = 26 end
    local parentScale = UIParent:GetEffectiveScale() or 1
    local scale = (target:GetEffectiveScale() or 1) / parentScale
    width = Clamp(width * scale, 80, 700)
    height = Clamp(height * scale, 24, 500)
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
    mover:SetWidth(width)
    mover:SetHeight(height)
    UpdateMoverLabel(name)
end

local function StoreMoverPosition(name, mover)
    if InCombatLockdown and InCombatLockdown() then pendingApply = true return end
    local centerX, centerY = mover:GetCenter()
    if not centerX or not centerY then return end
    local setting = FrameSetting(name, true)
    setting.point = "CENTER"
    setting.relativePoint = "BOTTOMLEFT"
    setting.x = centerX
    setting.y = centerY
    ApplyTarget(name)
    SyncMover(name)
end

local function AdjustSelectedScale(name, delta, alphaMode)
    local target = ResolveFrame(name)
    if not target then return end
    local setting = FrameSetting(name, true)
    if alphaMode then
        setting.alpha = Clamp((setting.alpha or target:GetAlpha() or 1) + delta * 0.05, 0.15, 1)
    else
        setting.scale = Clamp((setting.scale or target:GetScale() or 1) + delta * 0.05, 0.4, 2.5)
    end
    ApplyTarget(name)
    SyncMover(name)
    UpdatePanelStatus()
end

local function CreateMover(name)
    -- The Centre CoA is directly draggable. Giving it a mover would cover its
    -- own Fermer/Verrouiller buttons and could trap the player in edit mode.
    if name == "CoAUIManagerPanel" then return end
    local target = ResolveFrame(name)
    if not target then return end
    if movers[name] then
        SyncMover(name)
        movers[name]:Show()
        return
    end
    CaptureOriginal(name, target)
    local mover = CreateFrame("Frame", "CoAUIMover_" .. name, UIParent)
    mover:SetFrameStrata("TOOLTIP")
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:EnableMouseWheel(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    mover:SetBackdropColor(0.15, 0.35, 0.65, 0.28)
    mover:SetBackdropBorderColor(0.35, 0.75, 1, 1)
    mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetJustifyH("CENTER")
    mover:SetScript("OnEnter", function()
        selectedName = name
        UpdatePanelStatus()
        mover:SetBackdropColor(0.45, 0.25, 0.05, 0.42)
    end)
    mover:SetScript("OnLeave", function() mover:SetBackdropColor(0.15, 0.35, 0.65, 0.28) end)
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then Chat("Déplacement interdit en combat.") return end
        selectedName = name
        self:StartMoving()
        self:SetScript("OnUpdate", function(current)
            local x, y = current:GetCenter()
            local movingTarget = ResolveFrame(name)
            if x and y and movingTarget then
                movingTarget:ClearAllPoints()
                movingTarget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            end
        end)
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        StoreMoverPosition(name, self)
    end)
    mover:SetScript("OnMouseWheel", function(_, delta)
        if InCombatLockdown and InCombatLockdown() then Chat("Modification différée jusqu'à la fin du combat.") return end
        selectedName = name
        AdjustSelectedScale(name, delta, IsShiftKeyDown and IsShiftKeyDown())
    end)
    movers[name] = mover
    SyncMover(name)
    mover:Show()
end

-- This button is deliberately not a mover target. It stays above every mover,
-- including MinimapCluster, so the player can always leave edit mode by mouse.
local moveModeExitButton = CreateFrame("Button", "CoAUIManagerMoveModeExit", UIParent, "UIPanelButtonTemplate")
moveModeExitButton:SetWidth(250)
moveModeExitButton:SetHeight(32)
moveModeExitButton:SetPoint("TOP", UIParent, "TOP", 0, -18)
moveModeExitButton:SetFrameStrata("TOOLTIP")
moveModeExitButton:SetFrameLevel(10000)
moveModeExitButton:SetText("TERMINER LE DEPLACEMENT")
moveModeExitButton:Hide()

local function ShowMovers()
    if InCombatLockdown and InCombatLockdown() then
        Chat("Impossible de déverrouiller les frames en combat.")
        return
    end
    unlocked = true
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(9000)
    panel:Show()
    ForEachFrameName(CreateMover)
    if minimapButton then
        minimapButton:SetFrameStrata("TOOLTIP")
        minimapButton:SetFrameLevel(9500)
    end
    moveModeExitButton:Show()
    UpdatePanelStatus()
    Chat("Movers déverrouillés. Cliquez sur TERMINER LE DEPLACEMENT ou utilisez /cui lock.")
end

local function HideMovers()
    local _, mover
    for _, mover in pairs(movers) do
        mover:StopMovingOrSizing()
        mover:SetScript("OnUpdate", nil)
        mover:Hide()
    end
end

local function LockMovers()
    unlocked = false
    HideMovers()
    moveModeExitButton:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(20)
    if minimapButton then
        minimapButton:SetFrameStrata("HIGH")
        minimapButton:SetFrameLevel(20)
    end
    ApplyAll()
    UpdatePanelStatus()
    Chat("Positions enregistrées et movers verrouillés.")
end

lockButton:SetScript("OnClick", LockMovers)
moveModeExitButton:SetScript("OnClick", LockMovers)

local function TogglePanel()
    if panel:IsVisible() then
        panel:Hide()
    else
        panel:Show()
        UpdatePanelStatus()
    end
end

local function Atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function PositionMinimapButton()
    if not minimapButton then return end
    EnsureDatabase()
    minimapButton:ClearAllPoints()
    if Minimap then
        local angle = CoAUIManagerDB.minimap.angle or 3.9
        local radius = 80
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    else
        minimapButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -210, -20)
    end
end

local function SetMinimapButtonVisible(visible)
    EnsureDatabase()
    CoAUIManagerDB.minimap.hidden = not visible
    if minimapButton then
        if visible then
            PositionMinimapButton()
            minimapButton:Show()
        else
            minimapButton:Hide()
        end
    end
end

local function ResetMinimapButton()
    EnsureDatabase()
    CoAUIManagerDB.minimap.angle = 3.9
    CoAUIManagerDB.minimap.hidden = false
    PositionMinimapButton()
    if minimapButton then minimapButton:Show() end
end

local function BuildMinimapButton()
    if minimapButton then return end
    EnsureDatabase()
    local iconWasDragged = false
    minimapButton = CreateFrame("Button", "CoAUIManagerMinimapButton", UIParent)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("HIGH")
    minimapButton:SetFrameLevel(20)
    minimapButton:SetClampedToScreen(true)
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(22)
    icon:SetHeight(22)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
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

    minimapUnreadText = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minimapUnreadText:SetPoint("BOTTOMRIGHT", minimapButton, "BOTTOMRIGHT", 3, -2)
    minimapUnreadText:SetTextColor(1, 0.82, 0.10)
    minimapUnreadText:SetShadowOffset(1, -1)

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
            CoAUIManagerDB.minimap.angle = Atan2(cursorY - minimapY, cursorX - minimapX)
            PositionMinimapButton()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        PositionMinimapButton()
    end)
    minimapButton:SetScript("OnClick", function(_, button)
        if iconWasDragged then
            iconWasDragged = false
            return
        end
        if button == "RightButton" then
            if unlocked then LockMovers() else ShowMovers() end
        else
            TogglePanel()
        end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("CoA Tools", 1, 0.82, 0.20)
        GameTooltip:AddLine("Clic gauche : ouvrir le centre CoA.", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : verrouiller/déverrouiller l'interface.", 1, 1, 1)
        GameTooltip:AddLine("Glisser : déplacer l'icône autour de la minicarte.", 0.65, 0.78, 1)
        GameTooltip:AddLine("/cui minimap hide pour masquer l'icône.", 0.65, 0.72, 0.80)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PositionMinimapButton()
    if CoAUIManagerDB.minimap.hidden then minimapButton:Hide() else minimapButton:Show() end
    UpdateHubAvailability()
end

panel:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving()
end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local centerX, centerY = self:GetCenter()
    if centerX and centerY then
        local setting = FrameSetting("CoAUIManagerPanel", true)
        setting.point, setting.relativePoint, setting.x, setting.y = "CENTER", "BOTTOMLEFT", centerX, centerY
    end
end)

local function ScheduleApply()
    local now = GetTime()
    scheduledAt = { now + 0.2, now + 1.0, now + 3.0 }
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnUpdate", function()
    if not initialized then return end
    local now = GetTime()
    if now >= nextBadgeUpdate then
        nextBadgeUpdate = now + 0.5
        UpdateHubBadge()
    end
    if pendingApply and (not InCombatLockdown or not InCombatLockdown()) then ApplyAll() end
    if scheduledAt[1] and now >= scheduledAt[1] then
        table.remove(scheduledAt, 1)
        ApplyAll()
        if unlocked then ForEachFrameName(CreateMover) end
    end
end)

eventFrame:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == addonName then
        EnsureDatabase()
        BuildMinimapButton()
        initialized = true
        ScheduleApply()
    elseif not initialized then
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        panel:StopMovingOrSizing()
        HideMovers()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplyAll()
        ScheduleApply()
        if unlocked then ForEachFrameName(CreateMover) end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        PositionMinimapButton()
        UpdateHubAvailability()
        ScheduleApply()
    elseif event == "ADDON_LOADED" then
        UpdateHubAvailability()
        ScheduleApply()
    end
end)

local function ValidFrameName(name)
    return type(name) == "string" and string.match(name, "^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function AddCustomFrame(name)
    if not ValidFrameName(name) then Chat("Nom Lua invalide.") return end
    if not ResolveFrame(name) then Chat("Frame introuvable ou objet non déplaçable: " .. name) return end
    EnsureDatabase()
    local _, existing
    for _, existing in ipairs(CoAUIManagerDB.customFrames) do
        if existing == name then Chat(name .. " est déjà géré.") return end
    end
    table.insert(CoAUIManagerDB.customFrames, name)
    Chat(name .. " ajouté au profil.")
    if unlocked then CreateMover(name) end
end

local function SelectFrame(name)
    if not ValidFrameName(name) or not ResolveFrame(name) then Chat("Frame introuvable: " .. tostring(name)) return false end
    selectedName = name
    UpdatePanelStatus()
    Chat("Frame sélectionné: " .. name)
    return true
end

local function ResetFrame(name)
    if not name then Chat("Sélectionnez d'abord un mover.") return end
    ActiveProfile().frames[name] = nil
    local target = ResolveFrame(name)
    if target then RestoreOriginal(name, target) end
    if movers[name] then SyncMover(name) end
    Chat(name .. " réinitialisé dans le profil actif.")
end

local function PrintHelp()
    Chat("/cui unlock | lock | profile global|character | add FrameLua")
    Chat("/cui select FrameLua | scale 1.0 | alpha 1.0 | size largeur hauteur | reset")
    Chat("/cui minimap show|hide|reset")
end

SLASH_COAUI1 = "/cui"
SLASH_COAUI2 = "/coaui"
SlashCmdList.COAUI = function(message)
    EnsureDatabase()
    local command, arguments = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "unlock" then
        ShowMovers()
    elseif command == "lock" then
        LockMovers()
    elseif command == "profile" then
        local mode = string.lower(arguments or "")
        if mode == "character" or mode == "personnage" then
            CoAUIManagerDB.characterModes[CharacterKey()] = "CHARACTER"
        elseif mode == "global" then
            CoAUIManagerDB.characterModes[CharacterKey()] = "GLOBAL"
        else
            Chat("Profil actif: " .. ProfileMode())
            return
        end
        ApplyAll()
        if unlocked then ForEachFrameName(CreateMover) end
        Chat("Profil actif: " .. ProfileMode())
    elseif command == "add" then
        AddCustomFrame(arguments)
    elseif command == "select" then
        SelectFrame(arguments)
    elseif command == "scale" then
        if selectedName then
            local setting = FrameSetting(selectedName, true)
            setting.scale = Clamp(arguments, 0.4, 2.5)
            ApplyTarget(selectedName)
            if movers[selectedName] then SyncMover(selectedName) end
        else Chat("Sélectionnez d'abord un mover.") end
    elseif command == "alpha" then
        if selectedName then
            local setting = FrameSetting(selectedName, true)
            setting.alpha = Clamp(arguments, 0.15, 1)
            ApplyTarget(selectedName)
            if movers[selectedName] then SyncMover(selectedName) end
        else Chat("Sélectionnez d'abord un mover.") end
    elseif command == "size" then
        if selectedName then
            local width, height = string.match(arguments or "", "^(%d+)%s+(%d+)$")
            if not width then Chat("Usage: /cui size largeur hauteur") return end
            local setting = FrameSetting(selectedName, true)
            setting.width, setting.height = Clamp(width, 20, 2000), Clamp(height, 10, 1200)
            ApplyTarget(selectedName)
            if movers[selectedName] then SyncMover(selectedName) end
        else Chat("Sélectionnez d'abord un mover.") end
    elseif command == "reset" then
        ResetFrame(selectedName)
    elseif command == "minimap" then
        local action = string.lower(arguments or "")
        if action == "hide" or action == "masquer" then
            SetMinimapButtonVisible(false)
            Chat("Bouton de minicarte masqué. /cui minimap show pour le retrouver.")
        elseif action == "show" or action == "afficher" then
            SetMinimapButtonVisible(true)
            Chat("Bouton de minicarte affiché.")
        elseif action == "reset" then
            ResetMinimapButton()
            Chat("Position du bouton de minicarte réinitialisée.")
        else
            Chat("Usage: /cui minimap show|hide|reset")
        end
    elseif command == "status" then
        Chat("Profil " .. ProfileMode() .. ", movers " .. (unlocked and "déverrouillés" or "verrouillés") .. ", sélection " .. (selectedName or "aucune"))
    elseif command == "help" then
        PrintHelp()
    elseif command == "" then
        TogglePanel()
    else
        PrintHelp()
    end
end
