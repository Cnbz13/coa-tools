local addonName = ...

local HISTORY_LIMIT = 300
local activeFilter = "ALL"
local initialized = false
local hubManaged = false
local prefixes = {}
local originalChatAddMessage = nil

CoAMessageCenter = CoAMessageCenter or {}
local API = CoAMessageCenter

local panel = nil
local messageView = nil
local minimapButton = nil
local unreadText = nil
local statusText = nil
local filterButtons = {}

local LEVEL_COLORS = {
    info = { 0.78, 0.88, 1.00 },
    warning = { 1.00, 0.76, 0.18 },
    error = { 1.00, 0.32, 0.32 }
}

local KNOWN_PREFIXES = {
    ["CoA Loot Decider"] = "CoA Loot Decider",
    ["CoA Combat Assistant"] = "CoA Combat Assistant",
    ["CoA UI Manager"] = "CoA UI Manager",
    ["Grid CoA"] = "Grid CoA",
    ["Grid - Compatibilite CoA"] = "Grid CoA",
    ["Grid - Compatibilité CoA"] = "Grid CoA",
    ["CoA Analytics"] = "CoA Analytics",
    ["CoA Message Center"] = "CoA Message Center"
}

local function Trim(value)
    return string.match(tostring(value or ""), "^%s*(.-)%s*$")
end

local function StripFormatting(value)
    local text = tostring(value or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "|T.-|t", "")
    text = string.gsub(text, "|H.-|h(.-)|h", "%1")
    return Trim(text)
end

local function Normalize(value)
    local text = string.lower(StripFormatting(value))
    text = string.gsub(text, "%s+", " ")
    return Trim(text)
end

local function EnsureDatabase()
    CoAMessageCenterDB = CoAMessageCenterDB or {}
    if type(CoAMessageCenterDB.history) ~= "table" then CoAMessageCenterDB.history = {} end
    if CoAMessageCenterDB.enabled == nil then CoAMessageCenterDB.enabled = true end
    if CoAMessageCenterDB.suppressChat == nil then CoAMessageCenterDB.suppressChat = true end
    CoAMessageCenterDB.unread = tonumber(CoAMessageCenterDB.unread) or 0
    CoAMessageCenterDB.window = CoAMessageCenterDB.window or {}
    CoAMessageCenterDB.icon = CoAMessageCenterDB.icon or {}
    CoAMessageCenterDB.version = "0.1.2"
end

local function RegisterPrefix(prefix, source)
    local key = Normalize(prefix)
    if key == "" then return end
    prefixes[key] = Trim(source or StripFormatting(prefix))
end

local function RegisterInstalledAddon(indexOrName)
    if not GetAddOnInfo then return end
    local name, title = GetAddOnInfo(indexOrName)
    if name then RegisterPrefix(name, StripFormatting(title or name)) end
    if title then RegisterPrefix(title, StripFormatting(title)) end
end

local function BuildPrefixRegistry()
    for prefix, source in pairs(KNOWN_PREFIXES) do RegisterPrefix(prefix, source) end
    if GetNumAddOns and GetAddOnInfo then
        for index = 1, GetNumAddOns() do RegisterInstalledAddon(index) end
    end
end

local function InferLevel(message)
    local text = Normalize(message)
    if string.find(text, "erreur", 1, true)
        or string.find(text, "error", 1, true)
        or string.find(text, "invalide", 1, true)
        or string.find(text, "impossible", 1, true)
        or string.find(text, "echec", 1, true)
        or string.find(text, "refuse", 1, true) then
        return "error"
    end
    if string.find(text, "avertissement", 1, true)
        or string.find(text, "warning", 1, true)
        or string.find(text, "suspendu", 1, true)
        or string.find(text, "manuel", 1, true)
        or string.find(text, "desactive", 1, true) then
        return "warning"
    end
    return "info"
end

local function DetectAddonMessage(text)
    if type(text) ~= "string" then return nil end
    local clean = StripFormatting(text)
    local candidate = string.match(clean, "^%[([^%]]+)%]%s*.*$")
    if not candidate then candidate = string.match(clean, "^<([^>]+)>%s*.*$") end
    if not candidate then candidate = string.match(clean, "^([^:]+):%s*.*$") end
    if not candidate then candidate = string.match(clean, "^(.-)%s+%-%s+.*$") end
    if not candidate or string.len(candidate) > 80 then return nil end
    local normalized = Normalize(candidate)
    if prefixes[normalized] then return prefixes[normalized] end
    -- Certains addons ajoutent le nom de leur module au prefixe principal,
    -- par exemple "CoA Analytics PvE". Il reste identifiable sans ouvrir
    -- la porte aux messages ordinaires des joueurs.
    for prefix, source in pairs(prefixes) do
        if string.len(prefix) >= 3
            and string.sub(normalized, 1, string.len(prefix) + 1) == prefix .. " " then
            return source
        end
    end
    return nil
end

local function CurrentClock()
    if date then return date("%H:%M:%S") end
    return "--:--:--"
end

local function UpdateBadge()
    if not unreadText or not minimapButton then return end
    local unread = tonumber(CoAMessageCenterDB and CoAMessageCenterDB.unread) or 0
    if unread > 0 then
        unreadText:SetText(unread > 99 and "99+" or tostring(unread))
        unreadText:Show()
    else
        unreadText:SetText("")
        unreadText:Hide()
    end
end

local function EntryVisible(entry)
    return activeFilter == "ALL" or entry.level == activeFilter
end

local function RefreshMessages()
    if not messageView or not CoAMessageCenterDB then return end
    messageView:Clear()
    local visible = 0
    for _, entry in ipairs(CoAMessageCenterDB.history) do
        if EntryVisible(entry) then
            visible = visible + 1
            local color = LEVEL_COLORS[entry.level] or LEVEL_COLORS.info
            messageView:AddMessage("|cff7f8c9a[" .. tostring(entry.time or "--:--:--") .. "]|r "
                .. tostring(entry.text or ""), color[1], color[2], color[3])
        end
    end
    if visible == 0 then
        messageView:AddMessage("Aucun message dans ce filtre.", 0.55, 0.60, 0.68)
    else
        messageView:ScrollToBottom()
    end
    if statusText then
        statusText:SetText(visible .. " affiché(s) sur " .. #CoAMessageCenterDB.history
            .. "  •  " .. CoAMessageCenterDB.unread .. " non lu(s)")
    end
    for filter, button in pairs(filterButtons) do
        if filter == activeFilter then button:Disable() else button:Enable() end
    end
end

local function StoreMessage(source, text, level, alreadyFormatted)
    EnsureDatabase()
    local display = tostring(text or "")
    if not alreadyFormatted then
        display = "|cff67d9ff" .. tostring(source or "Addon") .. ":|r " .. display
    end
    table.insert(CoAMessageCenterDB.history, {
        time = CurrentClock(),
        source = tostring(source or "Addon"),
        text = display,
        level = LEVEL_COLORS[level] and level or InferLevel(display)
    })
    while #CoAMessageCenterDB.history > HISTORY_LIMIT do table.remove(CoAMessageCenterDB.history, 1) end

    if not panel or not panel:IsShown() then
        CoAMessageCenterDB.unread = CoAMessageCenterDB.unread + 1
    end
    UpdateBadge()
    RefreshMessages()
end

function API:RegisterPrefix(prefix, source)
    RegisterPrefix(prefix, source)
end

function API:AddMessage(source, message, level)
    StoreMessage(source, message, level, false)
end

function API:Show()
    if panel then panel:Show() end
end

function API:Toggle()
    if not panel then return end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

function API:SetHubManaged(value)
    hubManaged = value and true or false
    if minimapButton then
        if hubManaged then minimapButton:Hide() else minimapButton:Show() end
    end
end

local function ChatInterceptor(frame, text, ...)
    local source = CoAMessageCenterDB and CoAMessageCenterDB.enabled and DetectAddonMessage(text)
    if source then
        StoreMessage(source, text, InferLevel(text), true)
        if CoAMessageCenterDB.suppressChat then return end
    end
    if originalChatAddMessage then return originalChatAddMessage(frame, text, ...) end
end

local function InstallChatInterceptor()
    if not DEFAULT_CHAT_FRAME or type(DEFAULT_CHAT_FRAME.AddMessage) ~= "function" then return end
    if DEFAULT_CHAT_FRAME.AddMessage == ChatInterceptor then return end
    originalChatAddMessage = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = ChatInterceptor
end

local function SavePanelPosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    CoAMessageCenterDB.window.point = point
    CoAMessageCenterDB.window.relativePoint = relativePoint
    CoAMessageCenterDB.window.x = x
    CoAMessageCenterDB.window.y = y
end

local function SetPanelPosition(frame)
    local saved = CoAMessageCenterDB.window
    frame:ClearAllPoints()
    frame:SetPoint(saved.point or "CENTER", UIParent, saved.relativePoint or "CENTER", saved.x or 0, saved.y or 20)
end

local function MakePanelButton(parent, text, width, x, handler)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(23)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -43)
    button:SetText(text)
    button:SetScript("OnClick", handler)
    return button
end

local function BuildPanel()
    panel = CreateFrame("Frame", "CoAMessageCenterFrame", UIParent)
    panel:SetWidth(600)
    panel:SetHeight(390)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePanelPosition(self) end)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    panel:SetBackdropColor(0.025, 0.035, 0.055, 0.97)
    SetPanelPosition(panel)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -16)
    title:SetText("|cff67d9ffCentre de messages CoA|r")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subtitle:SetText("Addons uniquement")
    subtitle:SetTextColor(0.55, 0.62, 0.72)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)

    local filterData = {
        { key = "ALL", label = "Tous", width = 70 },
        { key = "info", label = "Infos", width = 70 },
        { key = "warning", label = "Alertes", width = 80 },
        { key = "error", label = "Erreurs", width = 80 }
    }
    local x = 18
    for _, data in ipairs(filterData) do
        local key = data.key
        filterButtons[key] = MakePanelButton(panel, data.label, data.width, x, function()
            activeFilter = key
            RefreshMessages()
        end)
        x = x + data.width + 5
    end

    local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clear:SetWidth(90)
    clear:SetHeight(23)
    clear:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -43)
    clear:SetText("Tout vider")
    clear:SetScript("OnClick", function()
        CoAMessageCenterDB.history = {}
        CoAMessageCenterDB.unread = 0
        UpdateBadge()
        RefreshMessages()
    end)

    local viewBackdrop = CreateFrame("Frame", nil, panel)
    viewBackdrop:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -75)
    viewBackdrop:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 40)
    viewBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    viewBackdrop:SetBackdropColor(0.005, 0.010, 0.018, 0.92)
    viewBackdrop:SetBackdropBorderColor(0.20, 0.42, 0.62, 0.80)

    messageView = CreateFrame("ScrollingMessageFrame", "CoAMessageCenterMessageView", viewBackdrop)
    messageView:SetPoint("TOPLEFT", viewBackdrop, "TOPLEFT", 10, -10)
    messageView:SetPoint("BOTTOMRIGHT", viewBackdrop, "BOTTOMRIGHT", -30, 10)
    messageView:SetFontObject(ChatFontNormal)
    messageView:SetJustifyH("LEFT")
    messageView:SetFading(false)
    messageView:SetMaxLines(HISTORY_LIMIT)
    messageView:EnableMouseWheel(true)
    messageView:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    if messageView.SetHyperlinksEnabled then messageView:SetHyperlinksEnabled(true) end
    messageView:SetScript("OnHyperlinkClick", function(_, link, text, button)
        if ChatFrame_OnHyperlinkShow then ChatFrame_OnHyperlinkShow(DEFAULT_CHAT_FRAME, link, text, button) end
    end)

    local scrollUp = CreateFrame("Button", nil, viewBackdrop, "UIPanelScrollUpButtonTemplate")
    scrollUp:SetPoint("TOPRIGHT", viewBackdrop, "TOPRIGHT", -5, -8)
    scrollUp:SetScript("OnClick", function() messageView:ScrollUp() end)
    local scrollDown = CreateFrame("Button", nil, viewBackdrop, "UIPanelScrollDownButtonTemplate")
    scrollDown:SetPoint("BOTTOMRIGHT", viewBackdrop, "BOTTOMRIGHT", -5, 8)
    scrollDown:SetScript("OnClick", function() messageView:ScrollDown() end)

    statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 18)
    statusText:SetTextColor(0.58, 0.66, 0.75)

    panel:SetScript("OnShow", function()
        CoAMessageCenterDB.unread = 0
        UpdateBadge()
        RefreshMessages()
    end)
    panel:Hide()
end

local function ResetIconPosition()
    if not minimapButton then return end
    minimapButton:ClearAllPoints()
    if Minimap then
        minimapButton:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 0, -8)
    else
        minimapButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -210, -20)
    end
end

local function BuildMinimapButton()
    local iconWasDragged = false
    minimapButton = CreateFrame("Button", "CoAMessageCenterMinimapButton", UIParent)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetClampedToScreen(true)
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    local saved = CoAMessageCenterDB.icon
    if saved.point then
        minimapButton:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        ResetIconPosition()
    end
    minimapButton:SetFrameStrata("HIGH")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(22)
    icon:SetHeight(22)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_05")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetWidth(52)
    border:SetHeight(52)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetWidth(32)
    highlight:SetHeight(32)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    unreadText = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unreadText:SetPoint("BOTTOMRIGHT", minimapButton, "BOTTOMRIGHT", 3, -2)
    unreadText:SetTextColor(1, 0.82, 0.10)
    unreadText:SetShadowOffset(1, -1)

    minimapButton:SetScript("OnMouseDown", function() iconWasDragged = false end)
    minimapButton:SetScript("OnDragStart", function(self)
        iconWasDragged = true
        self:StartMoving()
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        CoAMessageCenterDB.icon.point = point
        CoAMessageCenterDB.icon.relativePoint = relativePoint
        CoAMessageCenterDB.icon.x = x
        CoAMessageCenterDB.icon.y = y
    end)
    minimapButton:SetScript("OnClick", function()
        if iconWasDragged then
            iconWasDragged = false
            return
        end
        API:Toggle()
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("CoA Message Center", 0.40, 0.85, 1)
        GameTooltip:AddLine("Cliquez pour ouvrir les messages des addons.", 1, 1, 1, true)
        GameTooltip:AddLine("Maintenez le clic gauche pour déplacer l'icône.", 1, 0.82, 0.20, true)
        GameTooltip:AddLine("/cmc chat : afficher/masquer aussi dans le chat", 0.65, 0.72, 0.80, true)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UpdateBadge()
    if hubManaged then minimapButton:Hide() end
end

local function Initialize()
    if initialized then return end
    initialized = true
    EnsureDatabase()
    BuildPrefixRegistry()
    BuildPanel()
    BuildMinimapButton()
    InstallChatInterceptor()
    if CoAMessageCenterDB.welcomeVersion ~= "0.1.0" then
        CoAMessageCenterDB.welcomeVersion = "0.1.0"
        StoreMessage("CoA Message Center",
            "Centre actif : les messages identifiables des addons sont retirés du chat.", "info", false)
    end
end

SLASH_COAMESSAGECENTER1 = "/cmc"
SLASH_COAMESSAGECENTER2 = "/coamsg"
SlashCmdList.COAMESSAGECENTER = function(input)
    EnsureDatabase()
    local command = Normalize(input)
    if command == "clear" or command == "vider" then
        CoAMessageCenterDB.history = {}
        CoAMessageCenterDB.unread = 0
        UpdateBadge()
        RefreshMessages()
        return
    elseif command == "chat" then
        CoAMessageCenterDB.suppressChat = not CoAMessageCenterDB.suppressChat
        StoreMessage("CoA Message Center", "Copie dans le chat "
            .. (CoAMessageCenterDB.suppressChat and "désactivée" or "activée") .. ".", "info", false)
        API:Show()
        return
    elseif command == "off" then
        CoAMessageCenterDB.enabled = false
        StoreMessage("CoA Message Center", "Interception désactivée.", "warning", false)
        API:Show()
        return
    elseif command == "on" then
        CoAMessageCenterDB.enabled = true
        StoreMessage("CoA Message Center", "Interception activée.", "info", false)
        API:Show()
        return
    elseif command == "reset" then
        CoAMessageCenterDB.icon = {}
        ResetIconPosition()
        StoreMessage("CoA Message Center", "Position de l'icône réinitialisée.", "info", false)
        API:Show()
        return
    end
    API:Toggle()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if initialized then RegisterInstalledAddon(loadedName) end
        if loadedName == addonName then Initialize() end
    elseif event == "PLAYER_LOGIN" then
        Initialize()
        BuildPrefixRegistry()
        InstallChatInterceptor()
    end
end)
