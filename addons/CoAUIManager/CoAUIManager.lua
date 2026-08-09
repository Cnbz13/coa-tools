local addonName = ...

local DEFAULT_FRAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
    "MinimapCluster", "BuffFrame", "WatchFrame", "CastingBarFrame",
    "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "BonusActionBarFrame", "PetActionBarFrame", "ShapeshiftBarFrame", "PossessBarFrame",
    "CoACombatAssistantFrame", "CoAUIManagerPanel"
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
    CoACombatAssistantFrame = "CoA Combat Assistant", CoAUIManagerPanel = "CoA UI Manager"
}

local movers = {}
local originals = {}
local unlocked = false
local selectedName = nil
local pendingApply = false
local scheduledAt = {}
local initialized = false

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
panel:SetHeight(145)
panel:SetPoint("TOP", UIParent, "TOP", 0, -90)
panel:SetFrameStrata("DIALOG")
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
panelTitle:SetText("CoA UI Manager 3.3.5")

local panelStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panelStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -44)
panelStatus:SetWidth(334)
panelStatus:SetJustifyH("LEFT")
panelStatus:SetText("/cui unlock pour afficher les movers")

local panelHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
panelHelp:SetPoint("TOPLEFT", panelStatus, "BOTTOMLEFT", 0, -8)
panelHelp:SetWidth(334)
panelHelp:SetJustifyH("LEFT")
panelHelp:SetText("Glisser: position  •  Molette: échelle  •  Maj+molette: alpha\n/cui add NomDuFrame  •  /cui profile global|character")

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

local function ShowMovers()
    if InCombatLockdown and InCombatLockdown() then
        Chat("Impossible de déverrouiller les frames en combat.")
        return
    end
    unlocked = true
    panel:Show()
    ForEachFrameName(CreateMover)
    UpdatePanelStatus()
    Chat("Movers déverrouillés. Glissez-les puis utilisez /cui lock.")
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
    ApplyAll()
    UpdatePanelStatus()
    Chat("Positions enregistrées et movers verrouillés.")
end

lockButton:SetScript("OnClick", LockMovers)

panel:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving()
end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not unlocked then
        local centerX, centerY = self:GetCenter()
        if centerX and centerY then
            local setting = FrameSetting("CoAUIManagerPanel", true)
            setting.point, setting.relativePoint, setting.x, setting.y = "CENTER", "BOTTOMLEFT", centerX, centerY
        end
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
    if pendingApply and (not InCombatLockdown or not InCombatLockdown()) then ApplyAll() end
    if scheduledAt[1] and GetTime() >= scheduledAt[1] then
        table.remove(scheduledAt, 1)
        ApplyAll()
        if unlocked then ForEachFrameName(CreateMover) end
    end
end)

eventFrame:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == addonName then
        EnsureDatabase()
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
        ScheduleApply()
    elseif event == "ADDON_LOADED" then
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
    elseif command == "status" then
        Chat("Profil " .. ProfileMode() .. ", movers " .. (unlocked and "déverrouillés" or "verrouillés") .. ", sélection " .. (selectedName or "aucune"))
    elseif command == "help" then
        PrintHelp()
    elseif command == "" then
        if panel:IsVisible() then
            panel:Hide()
        else
            panel:Show()
            UpdatePanelStatus()
        end
    else
        PrintHelp()
    end
end
