local addonName = ...

local STATUS = "debuff_coa_harmful"
local SCAN_INTERVAL = 0.50
local initialized = false
local elapsedSinceScan = 0
local GridStatus
local GridStatusAuras
local GridFrame
local GridRoster

local colors = {
    Magic = { r = 0.20, g = 0.60, b = 1.00, a = 1 },
    Curse = { r = 0.60, g = 0.00, b = 1.00, a = 1 },
    Disease = { r = 0.60, g = 0.40, b = 0.00, a = 1 },
    Poison = { r = 0.00, g = 0.60, b = 0.00, a = 1 },
    Other = { r = 1.00, g = 0.20, b = 0.20, a = 1 }
}

local controlWords = {
    "sleep", "asleep", "slumber", "stun", "fear", "charm", "control",
    "polymorph", "hex", "banish", "sap", "silence", "root", "freeze",
    "frozen", "pacify", "endormi", "sommeil", "peur", "charme", "controle"
}

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c0ffGrid CoA:|r " .. tostring(message))
    end
end

local function AuraScore(name, debuffType)
    local score = debuffType and 20 or 10
    local lowered = string.lower(name or "")
    local _, word
    for _, word in ipairs(controlWords) do
        if string.find(lowered, word, 1, true) then return score + 100 end
    end
    return score
end

local function ScanUnit(unit)
    if not initialized or not unit or not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or not GridRoster:IsGUIDInRaid(guid) then return end

    local selected
    local index
    for index = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime = UnitAura(unit, index, "HARMFUL")
        if not name then break end
        local score = AuraScore(name, debuffType)
        if not selected or score > selected.score then
            selected = {
                name = name,
                icon = icon,
                count = count,
                debuffType = debuffType,
                duration = tonumber(duration) or 0,
                expirationTime = tonumber(expirationTime) or 0,
                score = score
            }
        end
    end

    if selected then
        local start = selected.duration > 0 and selected.expirationTime > 0
            and selected.expirationTime - selected.duration or nil
        local auraColor = colors[selected.debuffType] or colors.Other
        local label = selected.debuffType and (selected.debuffType .. ": " .. selected.name) or selected.name
        GridStatus:SendStatusGained(
            guid, STATUS, 99, nil, auraColor, label, selected.count, nil,
            selected.icon, start, selected.duration, selected.count
        )
    else
        GridStatus:SendStatusLost(guid, STATUS)
    end
end

local function ScanAll()
    if not initialized then return end
    local guid, unit
    for guid, unit in GridRoster:IterateRoster() do ScanUnit(unit) end
end

local function EnableTypedDebuffs()
    local statuses = { "debuff_magic", "debuff_curse", "debuff_disease", "debuff_poison" }
    GridFrame.db.profile.statusmap.icon = GridFrame.db.profile.statusmap.icon or {}
    GridFrame.db.profile.statusmap.text = GridFrame.db.profile.statusmap.text or {}

    local _, status
    for _, status in ipairs(statuses) do
        local settings = GridStatusAuras.db.profile[status]
        if settings then
            settings.enable = true
            GridFrame.db.profile.statusmap.icon[status] = true
            GridFrame.db.profile.statusmap.text[status] = true
            if GridStatusAuras.OnStatusEnable then GridStatusAuras:OnStatusEnable(status) end
        end
    end

    GridFrame.db.profile.statusmap.icon[STATUS] = true
    GridFrame.db.profile.statusmap.text[STATUS] = true
end

local function Initialize()
    if initialized or not Grid or not Grid.GetModule then return false end
    GridStatus = Grid:GetModule("GridStatus")
    GridFrame = Grid:GetModule("GridFrame")
    GridRoster = Grid:GetModule("GridRoster")
    GridStatusAuras = GridStatus and GridStatus:GetModule("GridStatusAuras")
    if not GridStatus or not GridFrame or not GridRoster or not GridStatusAuras
        or not GridStatusAuras.db or not GridFrame.db then return false end

    if not GridStatus:IsStatusRegistered(STATUS) then
        GridStatus:RegisterStatus(STATUS, "CoA: effet nuisible ou controle", addonName or "GridCoA")
    end
    EnableTypedDebuffs()
    initialized = true
    ScanAll()
    Chat("affaiblissements Magic/Curse/Disease/Poison et controles CoA actives")
    return true
end

local frame = CreateFrame("Frame", "GridCoAEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = select(1, ...)
        if loaded == "Grid" or loaded == addonName then Initialize() end
    elseif not initialized then
        Initialize()
    elseif event == "UNIT_AURA" then
        ScanUnit(select(1, ...))
    else
        ScanAll()
    end
end)
frame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceScan = elapsedSinceScan + elapsed
    if elapsedSinceScan < SCAN_INTERVAL then return end
    elapsedSinceScan = 0
    if not initialized then Initialize() else ScanAll() end
end)

Initialize()
