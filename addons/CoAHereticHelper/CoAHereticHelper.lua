local addonName = ...

-- CoA Heretic Helper v3.8.0
-- One proc only: instant Eldritch Mending.
-- Separate, compact Black Blood tracker.
-- Optional neutral 3-pip progress indicator for Malevolent Power.
-- No rotation helper.
-- Level-aware profile for CoA Build Hub build 5ba4e749-4871-4e36-aeeb-52c0678bc26c.

local UPDATE_INTERVAL = 0.05
local MALEVOLENT_SCAN_INTERVAL = 0.12
local MENDING_SCAN_INTERVAL = 0.10
local BLACK_BLOOD_SCAN_INTERVAL = 0.20
local MELEE_DUPLICATE_WINDOW = 0.25
local TRACE_EVENT_LIMIT = 80
local elapsed = 0
local testUntil = 0
local testPhase = 0
local lastInstant = false
local localProcProgress = 0
local localInstantUntil = 0
local lastMalevolentAuraSeen = 0
local lastMalevolentStacks = 0
local lastMalevolentExpiration = 0
local lastQualifyingCastAt = 0
local procReady = false
local procReadyUntil = 0
local traceEnabled = false
local localBB = {} -- [guid] = {expires=number, stacks=number}

-- Debounced proc tracking. CoA custom auras can update a fraction of a second
-- after SPELL_CAST_SUCCESS; we wait briefly before falling back to our local counter.
local pendingMelee = false
local pendingMeleeAt = 0
local lastProcessedMeleeAt = 0
local lastMalevolentScanAt = 0
local lastMendingScanAt = 0

-- Black Blood warning state.
local bbPrevCovered = 0
local bbPrevTotal = 0
local bbWarnedExpiryCycle = false
local bbWarnedCriticalCycle = false
local bbWarnedMissingCycle = false
local bbPulse = 0
local bbLastScanAt = 0
local bbCachedState = {covered=0,total=1,remain=0,duration=10,maxStacks=0,details={},sampledAt=0}
local bbSoundTestAt = 0
local playerLevel = 0

local BUILD_PROFILE = {
    id = "5ba4e749-4871-4e36-aeeb-52c0678bc26c",
    name = "Cultist Healer M+ Ready",
    className = "Cultist",
    specName = "Heretic",
}

local SPELL = {
    MENTAL_EXPANSION = 706178,
    ELDRITCH_MENDING = 502229,
    BLADE_EMPIRE     = 502124,
    MALEVOLENCE      = 502240,
    BLACK_BLOOD      = 807638,
    HERALD_DEPTHS    = 520326,
}

-- Public skill IDs exposed by the exact CoA Build Hub template. CoA can emit
-- different runtime IDs for the same custom ability, so these are aliases;
-- the learned spellbook ID remains authoritative on the running client.
local BUILDHUB_SPELL = {
    ELDRITCH_MENDING = 500711,
    BLADE_EMPIRE     = 500720,
    MALEVOLENCE      = 500714,
    ENTROPIC_SLAM    = 555351,
    HAMMER_TWILIGHT  = 805116,
    HERALD_DEPTHS    = 805120,
}

local spellbook = {
    mending=nil,
    blade=nil,
    malevolence=nil,
    entropic=nil,
    hammer=nil,
}

local function Chat(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8ee9ffHeretic HUD:|r " .. tostring(msg))
    end
end

local function Clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function EnsureDB()
    CoAHereticHelperDB = CoAHereticHelperDB or {}
    local db = CoAHereticHelperDB
    if db.enabled == nil then db.enabled = true end
    if db.sound == nil then db.sound = true end
    if db.locked == nil then db.locked = true end
    if db.bbLocked == nil then db.bbLocked = true end
    if db.procScale == nil then db.procScale = 1.0 end
    if db.bbScale == nil then db.bbScale = 1.0 end
    if db.x == nil then db.x = -250 end
    if db.y == nil then db.y = -205 end
    if db.bbX == nil then db.bbX = -250 end
    if db.bbY == nil then db.bbY = -255 end
    if db.buttonX == nil then db.buttonX = 250 end
    if db.buttonY == nil then db.buttonY = -140 end
    if db.showProgress == nil then db.showProgress = true end
    if db.bbAlways == nil then db.bbAlways = true end
    if db.showKeybind == nil then db.showKeybind = true end
    if db.hudPreset == nil then db.hudPreset = "compact" end
    if type(db.buttonAngle) ~= "number" then db.buttonAngle = 4.15 end
    if db.buttonHidden == nil then db.buttonHidden = false end
    if type(db.eventTrace) ~= "table" then db.eventTrace = {} end
    -- Preserve positions/settings across addon updates.
    db.version = 380
    return db
end

local function SafeGetSpellInfo(idOrName, bookType)
    if not GetSpellInfo then return nil end
    return GetSpellInfo(idOrName, bookType)
end

local function Lower(v) return v and string.lower(v) or nil end
local function NameMatches(name, patterns)
    local n = Lower(name)
    if not n then return false end
    for _, p in ipairs(patterns or {}) do
        p = Lower(p)
        if p and (n == p or string.find(n, p, 1, true)) then return true end
    end
    return false
end

local function SpellIDAt(index)
    if not index or not GetSpellLink then return nil end
    local link = GetSpellLink(index, BOOKTYPE_SPELL)
    return link and tonumber(string.match(link, "spell:(%d+)")) or nil
end

local function IsKnownSpellID(spellID)
    if not spellID then return false end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known then return true end
    end
    return false
end

local function DiscoverSpell(patterns, fallbackID, aliasIDs)
    if GetNumSpellTabs and GetSpellBookItemName then
        local tabs = GetNumSpellTabs() or 0
        for tab=1,tabs do
            local _,_,offset,num = GetSpellTabInfo(tab)
            offset, num = offset or 0, num or 0
            for i=offset+1,offset+num do
                local name, rank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                if name and NameMatches(name, patterns) then
                    local n,r,icon,cost,funnel,powerType,castMS = SafeGetSpellInfo(i, BOOKTYPE_SPELL)
                    return {name=n or name, rank=r or rank, icon=icon, index=i, spellID=SpellIDAt(i), castMS=castMS, learned=true}
                end
            end
        end
    end

    local candidates = {}
    if fallbackID then table.insert(candidates, fallbackID) end
    for _,spellID in ipairs(aliasIDs or {}) do table.insert(candidates, spellID) end
    local displayFallback = nil
    for _,spellID in ipairs(candidates) do
        local n,r,icon,cost,funnel,powerType,castMS = SafeGetSpellInfo(spellID)
        if n then
            local candidate = {name=n, rank=r, icon=icon, index=nil, spellID=spellID, castMS=castMS, learned=IsKnownSpellID(spellID)}
            if candidate.learned then return candidate end
            if not displayFallback then displayFallback = candidate end
        end
    end
    return displayFallback
end

local function RefreshSpellbook()
    spellbook.mending = DiscoverSpell({"Eldritch Mending", "Soin occulte", "Soins occultes"}, SPELL.ELDRITCH_MENDING, {BUILDHUB_SPELL.ELDRITCH_MENDING})
    spellbook.blade = DiscoverSpell({"Blade of the Empire", "Lame de l'Empire", "Lame de l’Empire"}, SPELL.BLADE_EMPIRE, {BUILDHUB_SPELL.BLADE_EMPIRE})
    spellbook.malevolence = DiscoverSpell({"Malevolence", "Malveillance"}, SPELL.MALEVOLENCE, {BUILDHUB_SPELL.MALEVOLENCE})
    spellbook.entropic = DiscoverSpell({"Entropic Slam", "Frappe entropique", "Heurt entropique"}, BUILDHUB_SPELL.ENTROPIC_SLAM)
    spellbook.hammer = DiscoverSpell({"Hammer of Twilight", "Marteau du Crepuscule", "Marteau du Crépuscule"}, BUILDHUB_SPELL.HAMMER_TWILIGHT)
end

local hereticDetected = false
local function RefreshSpecDetection()
    playerLevel = (UnitLevel and UnitLevel("player")) or 0
    RefreshSpellbook()
    -- GetSpellInfo(id) can resolve abilities the character has not learned.
    -- Only a spell found in the live spellbook (or confirmed by IsSpellKnown)
    -- may activate this HUD. This is essential while following the level-60
    -- template progressively on a level-39 character.
    hereticDetected = (spellbook.mending and spellbook.mending.learned)
        or (spellbook.blade and spellbook.blade.learned)
        or (spellbook.malevolence and spellbook.malevolence.learned)
        or false
end

local function AuraFromIterator(unit, helpful, spellID, names)
    if not UnitExists(unit) then return nil end
    local lookup = {}
    if names then
        for _, n in ipairs(names) do lookup[Lower(n)] = true end
    end
    if spellID then
        local idName = SafeGetSpellInfo(spellID)
        if idName then lookup[Lower(idName)] = true end
    end

    local fn = nil
    if helpful == true and UnitBuff then fn = UnitBuff end
    if helpful == false and UnitDebuff then fn = UnitDebuff end
    if not fn then return nil end

    for i=1,40 do
        local name, rank, icon, count, debuffType, duration, expirationTime, caster,
              isStealable, shouldConsolidate, auraID = fn(unit, i)
        if not name then break end
        local match = false
        if spellID and auraID and auraID == spellID then match = true end
        if lookup[Lower(name)] then match = true end
        if match then
            return {
                name=name, icon=icon, count=count or 0,
                duration=duration or 0, expiration=expirationTime or 0,
                caster=caster, spellID=auraID,
            }
        end
    end
    return nil
end

local function FindAura(unit, spellID, names)
    return AuraFromIterator(unit, true, spellID, names) or AuraFromIterator(unit, false, spellID, names)
end

local function Remaining(aura)
    if not aura or not aura.expiration or aura.expiration <= 0 then return 0 end
    return math.max(0, aura.expiration - GetTime())
end

local function GetMendingCastMS()
    local s = spellbook.mending
    if not s then return nil end
    if s.castMS ~= nil then return s.castMS end
    local n,r,icon,cost,funnel,powerType,castMS = SafeGetSpellInfo(s.name)
    if castMS == nil and s.index then
        n,r,icon,cost,funnel,powerType,castMS = SafeGetSpellInfo(s.index, BOOKTYPE_SPELL)
    end
    s.castMS = castMS
    return castMS
end

local function GetMendingInstantState(forceScan)
    -- v3.5: explicit READY state. We never let a flaky aura-removal event
    -- cancel the proc. The proc is consumed only by casting Eldritch Mending
    -- or by the 10 s timeout.
    local now = GetTime()
    if procReady and procReadyUntil > now then
        -- READY is authoritative until consumption/expiry. Re-scanning a flaky
        -- custom aura here used to waste work and could never be allowed to
        -- cancel the lock anyway.
        return true, nil, GetMendingCastMS()
    end
    if procReady and procReadyUntil <= now then
        procReady = false
        procReadyUntil = 0
        localInstantUntil = 0
    end
    if not forceScan and now - lastMendingScanAt < MENDING_SCAN_INTERVAL then
        return false, nil, GetMendingCastMS()
    end
    lastMendingScanAt = now
    local aura = FindAura("player", SPELL.MENTAL_EXPANSION, {
        "Mental Expansion", "Expansion mentale"
    })
    if aura then
        procReady = true
        local rem = Remaining(aura)
        procReadyUntil = now + ((rem and rem > 0) and rem or 10)
        localInstantUntil = procReadyUntil
        localProcProgress = 0
        return true, aura, GetMendingCastMS()
    end
    return false, nil, GetMendingCastMS()
end

local function PlayProcSound()
    local db = EnsureDB()
    if db.sound and PlaySound then pcall(PlaySound, "RaidWarning") end
end

local function Trace(msg)
    if traceEnabled then Chat("|cffc88cffTRACE|r " .. tostring(msg)) end
end

local function RecordTrace(source, eventType, spellID, spellName, amount)
    if not traceEnabled then return end
    local db = EnsureDB()
    local entries = db.eventTrace
    table.insert(entries, {
        at = time and time() or 0,
        source = tostring(source or "?"),
        event = tostring(eventType or "?"),
        spellID = tonumber(spellID),
        spellName = tostring(spellName or "?"),
        amount = tonumber(amount),
    })
    while #entries > TRACE_EVENT_LIMIT do table.remove(entries, 1) end
end

local function SetProcReady(seconds, reason)
    local now = GetTime()
    seconds = tonumber(seconds) or 10
    procReady = true
    procReadyUntil = math.max(procReadyUntil or 0, now + seconds)
    localInstantUntil = procReadyUntil
    localProcProgress = 0
    lastMalevolentStacks = 0
    lastMalevolentExpiration = 0
    Trace("PROC READY" .. (reason and (" ["..reason.."]") or ""))
end

local function ClearProcReady(reason)
    procReady = false
    procReadyUntil = 0
    localInstantUntil = 0
    localProcProgress = 0
    lastMalevolentStacks = 0
    lastMalevolentExpiration = 0
    Trace("PROC CONSUMED" .. (reason and (" ["..reason.."]") or ""))
end

-- ============================================================
-- PROC DISPLAY: only instant heal
-- ============================================================
local function BindingForActionSlot(slot)
    if slot >= 1 and slot <= 12 then return "ACTIONBUTTON" .. slot end
    if slot >= 25 and slot <= 36 then return "MULTIACTIONBAR3BUTTON" .. (slot - 24) end
    if slot >= 37 and slot <= 48 then return "MULTIACTIONBAR4BUTTON" .. (slot - 36) end
    if slot >= 49 and slot <= 60 then return "MULTIACTIONBAR2BUTTON" .. (slot - 48) end
    if slot >= 61 and slot <= 72 then return "MULTIACTIONBAR1BUTTON" .. (slot - 60) end
    return nil
end

local cachedKeybind = ""
local cachedKeybindSpell = nil
local cachedKeybindAt = 0
local function FindSpellKeybind(spell)
    if not spell or not spell.name or not GetActionInfo or not GetBindingKey then return "" end
    local now = GetTime and GetTime() or 0
    if cachedKeybindSpell == spell.name and now - cachedKeybindAt < 2 then return cachedKeybind end
    cachedKeybindSpell = spell.name
    cachedKeybindAt = now
    cachedKeybind = ""
    local slot
    for slot = 1, 120 do
        local actionType, actionID = GetActionInfo(slot)
        local actionName = nil
        if actionType == "spell" and actionID then
            actionName = SafeGetSpellInfo(actionID)
        elseif actionType == "macro" and actionID and GetMacroSpell then
            local macroSpell = GetMacroSpell(actionID)
            if type(macroSpell) == "number" or type(macroSpell) == "string" then
                actionName = SafeGetSpellInfo(macroSpell) or macroSpell
            end
        end
        if actionName and Lower(actionName) == Lower(spell.name) then
            local binding = BindingForActionSlot(slot)
            local key = binding and GetBindingKey(binding) or nil
            if key then
                cachedKeybind = GetBindingText and (GetBindingText(key, "KEY_", 1) or key) or key
                return cachedKeybind
            end
        end
    end
    return cachedKeybind
end

local procAnchor = CreateFrame("Frame", "CoAHereticProcAnchor", UIParent)
procAnchor:SetWidth(82); procAnchor:SetHeight(78)
procAnchor:SetMovable(true); procAnchor:SetClampedToScreen(true)
procAnchor:RegisterForDrag("LeftButton"); procAnchor:SetFrameStrata("HIGH")
procAnchor:EnableMouse(false)

local procEdit = CreateFrame("Frame", nil, procAnchor)
procEdit:SetAllPoints(procAnchor)
procEdit:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
procEdit:SetBackdropColor(0.02,0.06,0.10,0.28); procEdit:SetBackdropBorderColor(0.20,0.90,1.00,0.85)
procEdit:Hide()
local procEditText = procEdit:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
procEditText:SetPoint("CENTER"); procEditText:SetText("PROC\nShift + glisser"); procEditText:SetTextColor(0.45,0.95,1)

procAnchor:SetScript("OnDragStart", function(self)
    local db=EnsureDB(); if db.locked then return end
    if IsShiftKeyDown and not IsShiftKeyDown() then return end
    self:StartMoving()
end)
procAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing(); local db=EnsureDB(); local _,_,_,x,y=self:GetPoint(1); db.x=x or db.x; db.y=y or db.y
end)

local instantFrame = CreateFrame("Frame", nil, procAnchor)
instantFrame:SetWidth(72); instantFrame:SetHeight(70); instantFrame:SetPoint("CENTER"); instantFrame:Hide()
local instantIcon = instantFrame:CreateTexture(nil,"ARTWORK")
instantIcon:SetWidth(52); instantIcon:SetHeight(52); instantIcon:SetPoint("TOP",0,0); instantIcon:SetTexCoord(0.08,0.92,0.08,0.92)
local instantCooldown = CreateFrame("Cooldown", nil, instantFrame, "CooldownFrameTemplate")
instantCooldown:SetAllPoints(instantIcon)
instantCooldown:SetFrameLevel(instantFrame:GetFrameLevel() + 2)
local instantBorder = instantFrame:CreateTexture(nil,"OVERLAY")
instantBorder:SetWidth(62); instantBorder:SetHeight(62); instantBorder:SetPoint("CENTER",instantIcon,"CENTER")
instantBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); instantBorder:SetBlendMode("ADD"); instantBorder:SetVertexColor(0.28,0.92,1.00,0.95)
local instantGlow = instantFrame:CreateTexture(nil,"OVERLAY")
instantGlow:SetWidth(82); instantGlow:SetHeight(82); instantGlow:SetPoint("CENTER",instantIcon,"CENTER")
instantGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); instantGlow:SetBlendMode("ADD"); instantGlow:SetVertexColor(0.28,0.92,1.00,0.75)
local instantTimer = instantFrame:CreateFontString(nil,"OVERLAY","NumberFontNormal")
instantTimer:SetPoint("BOTTOMRIGHT",instantIcon,"BOTTOMRIGHT",1,1)
local instantKeybind = instantFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
instantKeybind:SetPoint("TOPRIGHT",instantIcon,"TOPRIGHT",-2,-2); instantKeybind:SetTextColor(1.0,0.88,0.40)
local instantLabel = instantFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
instantLabel:SetPoint("TOP",instantIcon,"BOTTOM",0,-1); instantLabel:SetText(""); instantLabel:SetTextColor(0.42,0.92,1.00)
instantFrame.pulse=0
instantFrame:SetScript("OnUpdate",function(self,dt)
    self.pulse=(self.pulse or 0)+dt*4.5
    instantGlow:SetAlpha(0.45+0.30*((math.sin(self.pulse)+1)/2))
end)

-- Neutral preparation progress: 1 then 2 pips only. At the third trigger the pips vanish; the heal icon appears only when the real instant proc is detected.
local progressFrame = CreateFrame("Frame", nil, procAnchor)
progressFrame:SetWidth(58); progressFrame:SetHeight(16); progressFrame:SetPoint("CENTER",procAnchor,"CENTER",0,-2); progressFrame:Hide()
local progressPips = {}
for i=1,2 do
    local p = progressFrame:CreateTexture(nil,"ARTWORK")
    p:SetWidth(12); p:SetHeight(12); p:SetTexture("Interface\\Buttons\\WHITE8X8")
    p:SetPoint("CENTER",progressFrame,"CENTER",(i-1.5)*20,0)
    p:SetVertexColor(0.32,0.18,0.48,0.28)
    progressPips[i]=p
end
local progressText = progressFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
progressText:SetPoint("TOP",progressFrame,"BOTTOM",0,-1); progressText:SetText("")

local function GetProcProgress()
    -- SyncMalevolentPowerState already reconciles the real aura with the local
    -- fallback. Avoid a second full player-aura scan for the same frame.
    return localProcProgress
end

local function UpdateProgressVisual(progress, testMode)
    local db=EnsureDB()
    if not db.showProgress then progressFrame:Hide(); return end
    if testMode then progress=2 end
    -- The user should only ever see preparation state 1/3 or 2/3.
    -- 3/3 is not displayed: the real proc replaces it once Mental Expansion is active.
    if not progress or progress<=0 or progress>=3 then progressFrame:Hide(); return end
    for i=1,2 do
        if i<=progress then
            progressPips[i]:SetVertexColor(0.65,0.30,1.00,0.95)
        else
            progressPips[i]:SetVertexColor(0.32,0.18,0.48,0.28)
        end
    end
    progressText:SetText("")
    progressFrame:Show()
end

-- ============================================================
-- BLACK BLOOD tracker: compact, readable, strong expiry warning
-- ============================================================
local bbFrame=CreateFrame("Frame","CoAHereticBlackBloodTracker",UIParent)
bbFrame:SetWidth(160); bbFrame:SetHeight(42); bbFrame:SetMovable(true); bbFrame:SetClampedToScreen(true)
bbFrame:RegisterForDrag("LeftButton"); bbFrame:SetFrameStrata("HIGH"); bbFrame:EnableMouse(false)

local bbIcon=bbFrame:CreateTexture(nil,"ARTWORK")
bbIcon:SetWidth(24); bbIcon:SetHeight(24); bbIcon:SetPoint("TOPLEFT",bbFrame,"TOPLEFT",0,-2)
local _,_,bbIconTexture=SafeGetSpellInfo(SPELL.BLACK_BLOOD)
bbIcon:SetTexture(bbIconTexture or "Interface\Icons\Spell_Shadow_LifeDrain02"); bbIcon:SetTexCoord(0.10,0.90,0.10,0.90)
local bbGlow=bbFrame:CreateTexture(nil,"OVERLAY")
bbGlow:SetWidth(34); bbGlow:SetHeight(34); bbGlow:SetPoint("CENTER",bbIcon,"CENTER")
bbGlow:SetTexture("Interface\Buttons\UI-ActionButton-Border"); bbGlow:SetBlendMode("ADD"); bbGlow:SetVertexColor(0.58,0.30,1.0,0.35)

local bbCount=bbFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
bbCount:SetPoint("TOPLEFT",bbIcon,"TOPRIGHT",7,0); bbCount:SetText("0/1")
local bbStack=bbFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
bbStack:SetPoint("LEFT",bbCount,"RIGHT",4,0); bbStack:SetText("")
local bbTime=bbFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
bbTime:SetPoint("TOPRIGHT",bbFrame,"TOPRIGHT",0,0); bbTime:SetText("OFF")
local bbWarn=bbFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
bbWarn:SetPoint("RIGHT",bbTime,"LEFT",-3,0); bbWarn:SetText("")

local bbBar=CreateFrame("StatusBar",nil,bbFrame)
bbBar:SetWidth(129); bbBar:SetHeight(4); bbBar:SetPoint("BOTTOMLEFT",bbFrame,"BOTTOMLEFT",31,2)
bbBar:SetStatusBarTexture("Interface\TargetingFrame\UI-StatusBar"); bbBar:SetStatusBarColor(0.52,0.24,0.92,0.90); bbBar:SetMinMaxValues(0,10); bbBar:SetValue(0)
local bbBarBg=bbBar:CreateTexture(nil,"BACKGROUND"); bbBarBg:SetAllPoints(bbBar); bbBarBg:SetTexture("Interface\Buttons\WHITE8X8"); bbBarBg:SetVertexColor(0.02,0.02,0.04,0.32)

local bbDots = {}
for i=1,40 do
    local dot=bbFrame:CreateTexture(nil,"ARTWORK")
    dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    dot:SetVertexColor(0.22,0.18,0.28,0.55)
    dot:Hide()
    bbDots[i]=dot
end

local bbEdit=CreateFrame("Frame",nil,bbFrame); bbEdit:SetAllPoints(bbFrame)
bbEdit:SetBackdrop({bgFile="Interface\Tooltips\UI-Tooltip-Background",edgeFile="Interface\Buttons\WHITE8X8",edgeSize=1})
bbEdit:SetBackdropColor(0.04,0.02,0.08,0.22); bbEdit:SetBackdropBorderColor(0.70,0.35,1.0,0.8); bbEdit:Hide()
local bbEditText=bbEdit:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); bbEditText:SetPoint("CENTER"); bbEditText:SetText("SANG NOIR  •  Shift + glisser")

bbFrame:SetScript("OnDragStart",function(self)
    local db=EnsureDB(); if db.bbLocked then return end
    if IsShiftKeyDown and not IsShiftKeyDown() then return end
    self:StartMoving()
end)
bbFrame:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing(); local db=EnsureDB(); local _,_,_,x,y=self:GetPoint(1); db.bbX=x or db.bbX; db.bbY=y or db.bbY
end)

local function GetBlackBloodFallbackDuration()
    -- Base Black Blood is 10 s. Herald of the Depths doubles HoT duration to 20 s.
    local herald = FindAura("player", SPELL.HERALD_DEPTHS, {"Herald of the Depths", "Héraut des Profondeurs", "Heraut des Profondeurs"})
        or FindAura("player", BUILDHUB_SPELL.HERALD_DEPTHS, {"Herald of the Depths", "Héraut des Profondeurs", "Heraut des Profondeurs"})
    return herald and 20 or 10
end

local function PlayBlackBloodWarning(kind, force)
    local db=EnsureDB()
    if (not db.sound and not force) or not PlaySound then return end
    if kind == "critical" or kind == "expired" then
        pcall(PlaySound, "igQuestFailed")
    else
        -- Deliberately not TellMessage: the whisper sound is too easy to miss
        -- while healing. RaidWarning is short, distinct and available on 3.3.5.
        pcall(PlaySound, "RaidWarning")
    end
end

local function GroupUnits()
    local units={}
    if GetNumRaidMembers and (GetNumRaidMembers() or 0)>0 then
        local n=GetNumRaidMembers() or 0
        for i=1,n do table.insert(units,"raid"..i) end
    else
        table.insert(units,"player")
        local n=GetNumPartyMembers and (GetNumPartyMembers() or 0) or 0
        for i=1,n do table.insert(units,"party"..i) end
    end
    return units
end

local function IsGroupGUID(guid)
    if not guid or not UnitGUID then return false end
    for _,unit in ipairs(GroupUnits()) do
        if UnitExists(unit) and UnitGUID(unit)==guid then return true end
    end
    return false
end

local function CleanupLocalBB()
    local now=GetTime()
    for guid,data in pairs(localBB) do
        if not data.expires or data.expires<=now then localBB[guid]=nil end
    end
end

local function ScanBlackBlood()
    CleanupLocalBB()
    local units=GroupUnits(); local total=0; local covered=0; local minRemain=nil
    local durationForBar=GetBlackBloodFallbackDuration(); local maxStacks=0; local details={}
    local now=GetTime()
    for _,unit in ipairs(units) do
        if UnitExists(unit) and (not UnitIsDeadOrGhost or not UnitIsDeadOrGhost(unit)) then
            total=total+1
            local aura=FindAura(unit,SPELL.BLACK_BLOOD,{"Black Blood","Sang noir"})
            local rem=0; local stacks=0
            if aura then
                rem=Remaining(aura); stacks=aura.count or 0
                if aura.duration and aura.duration>0 then durationForBar=math.max(durationForBar,aura.duration) end
            else
                local guid=UnitGUID and UnitGUID(unit) or nil
                local tracked=guid and localBB[guid] or nil
                if tracked and tracked.expires and tracked.expires>now then
                    rem=tracked.expires-now; stacks=tracked.stacks or 1
                    durationForBar=math.max(durationForBar, tracked.duration or durationForBar)
                end
            end
            if rem>0 then
                covered=covered+1
                if not minRemain or rem<minRemain then minRemain=rem end
                if stacks>maxStacks then maxStacks=stacks end
            end
            table.insert(details, {
                unit=unit,
                name=(UnitName and UnitName(unit)) or unit,
                covered=rem>0,
                remain=rem,
                stacks=stacks,
            })
        end
    end
    return covered,total,minRemain or 0,durationForBar,maxStacks,details
end

local function ReadBlackBloodState(forceScan)
    local now = GetTime()
    if forceScan or bbLastScanAt <= 0 or now - bbLastScanAt >= BLACK_BLOOD_SCAN_INTERVAL then
        local covered,total,remain,duration,maxStacks,details = ScanBlackBlood()
        bbCachedState = {
            covered=covered, total=total, remain=remain, duration=duration,
            maxStacks=maxStacks, details=details, sampledAt=now,
        }
        bbLastScanAt = now
    end
    local state = bbCachedState
    local remain = math.max(0, (state.remain or 0) - math.max(0, now - (state.sampledAt or now)))
    return state.covered or 0, state.total or 1, remain, state.duration or 10,
        state.maxStacks or 0, state.details or {}
end

local function UpdateBlackBloodDots(details, testMode)
    if testMode then
        details={
            {name="Joueur",covered=true,remain=8}, {name="Groupe 1",covered=true,remain=6},
            {name="Groupe 2",covered=true,remain=2.4}, {name="Groupe 3",covered=true,remain=5},
            {name="Groupe 4",covered=false,remain=0},
        }
    end
    local total=#details
    local size,step,columns=5,6,20
    if total<=5 then size,step,columns=9,13,5
    elseif total<=10 then size,step,columns=7,10,10 end
    local i,dot
    for i,dot in ipairs(bbDots) do
        local detail=details[i]
        if detail then
            local column=(i-1)%columns
            local row=math.floor((i-1)/columns)
            dot:ClearAllPoints()
            dot:SetWidth(size); dot:SetHeight(size)
            dot:SetPoint("TOPLEFT",bbFrame,"TOPLEFT",31+(column*step),-21-(row*step))
            if detail.covered and (detail.remain or 0)<=1.5 then
                dot:SetVertexColor(1.00,0.18,0.22,0.95)
            elseif detail.covered and (detail.remain or 0)<=3.0 then
                dot:SetVertexColor(1.00,0.52,0.10,0.95)
            elseif detail.covered then
                dot:SetVertexColor(0.56,0.34,1.00,0.95)
            else
                dot:SetVertexColor(0.95,0.20,0.30,0.88)
            end
            dot:Show()
        else
            dot:Hide()
        end
    end
end

local function UpdateBlackBlood(testMode, forceScan)
    local db=EnsureDB()
    if not db.enabled then bbFrame:Hide(); return end
    local covered,total,remain,duration,maxStacks,details=ReadBlackBloodState(forceScan)
    if testMode then covered,total,remain,duration,maxStacks=5,5,2.4,10,2 end
    total=math.max(total,1)

    bbCount:SetText(string.format("%d/%d",covered,total))
    bbStack:SetText(maxStacks>1 and ("x"..tostring(maxStacks)) or "")
    bbTime:SetText(remain>0 and string.format("%.1f",remain) or "OFF")
    bbBar:SetMinMaxValues(0,math.max(duration,1)); bbBar:SetValue(math.min(remain,duration))
    UpdateBlackBloodDots(details,testMode)

    local full = covered>=total and covered>0
    local partial = covered>0 and covered<total
    local expiring = full and remain>0 and remain<=3.0
    local critical = full and remain>0 and remain<=1.5

    -- Reset the warning latch after a successful refresh.
    if full and remain>4.0 then
        bbWarnedExpiryCycle=false
        bbWarnedCriticalCycle=false
    end
    if full then bbWarnedMissingCycle=false end

    -- Audible warnings are edge-triggered, never spammed every frame.
    if critical and not bbWarnedCriticalCycle and not testMode then
        bbWarnedCriticalCycle=true
        bbWarnedExpiryCycle=true
        PlayBlackBloodWarning("critical")
    elseif expiring and not bbWarnedExpiryCycle and not testMode then
        bbWarnedExpiryCycle=true
        PlayBlackBloodWarning("expiring")
    end
    if covered<total and bbPrevCovered>=bbPrevTotal and bbPrevTotal>0 and not bbWarnedMissingCycle and not testMode then
        bbWarnedMissingCycle=true
        PlayBlackBloodWarning(covered==0 and "expired" or "missing")
    elseif covered==0 and bbPrevCovered>0 and not bbWarnedMissingCycle and not testMode then
        bbWarnedMissingCycle=true
        PlayBlackBloodWarning("expired")
    end

    if critical then
        bbCount:SetTextColor(1.0,0.32,0.32); bbTime:SetTextColor(1.0,0.25,0.25)
        bbBar:SetStatusBarColor(1.0,0.18,0.18,0.95); bbGlow:SetVertexColor(1.0,0.18,0.22,0.90); bbWarn:SetText("!")
    elseif expiring then
        bbCount:SetTextColor(1.0,0.72,0.22); bbTime:SetTextColor(1.0,0.66,0.12)
        bbBar:SetStatusBarColor(1.0,0.48,0.08,0.95); bbGlow:SetVertexColor(1.0,0.42,0.08,0.72); bbWarn:SetText("!")
    elseif partial then
        bbCount:SetTextColor(1.0,0.42,0.28); bbTime:SetTextColor(1.0,0.65,0.35)
        bbBar:SetStatusBarColor(0.95,0.28,0.16,0.90); bbGlow:SetVertexColor(1.0,0.25,0.18,0.75); bbWarn:SetText("!")
    elseif full then
        bbCount:SetTextColor(0.72,0.92,1.0); bbTime:SetTextColor(0.72,0.92,1.0)
        bbBar:SetStatusBarColor(0.52,0.24,0.92,0.90); bbGlow:SetVertexColor(0.55,0.30,1.0,0.38); bbWarn:SetText("")
    else
        bbCount:SetTextColor(0.55,0.42,0.65); bbTime:SetTextColor(0.62,0.40,0.50)
        bbBar:SetStatusBarColor(0.36,0.18,0.42,0.55); bbGlow:SetVertexColor(0.55,0.18,0.35,0.48); bbWarn:SetText("!")
    end

    -- Strong but compact pulse only when action is actually needed.
    bbPulse = (bbPulse or 0) + UPDATE_INTERVAL * (critical and 8 or 5)
    if critical or partial or covered==0 then
        local a=0.48+0.42*((math.sin(bbPulse)+1)/2)
        bbGlow:SetAlpha(a)
        bbFrame:SetAlpha(0.86+0.14*((math.sin(bbPulse)+1)/2))
    elseif expiring then
        local a=0.42+0.30*((math.sin(bbPulse)+1)/2)
        bbGlow:SetAlpha(a); bbFrame:SetAlpha(1)
    else
        bbGlow:SetAlpha(0.55); bbFrame:SetAlpha(0.92)
    end

    bbPrevCovered=covered; bbPrevTotal=total

    if not db.bbLocked then
        bbEdit:Show(); bbFrame:EnableMouse(true); bbFrame:Show()
    else
        bbEdit:Hide(); bbFrame:EnableMouse(false)
        if db.bbAlways or covered>0 or (UnitAffectingCombat and UnitAffectingCombat("player")) or testMode then bbFrame:Show() else bbFrame:Hide() end
    end
end

-- ============================================================
-- Combat log helpers: robust BB fallback + proc progress
-- ============================================================
local function SpellNameEquals(spellName, spell)
    return spellName and spell and spell.name and spellName == spell.name
end

local function MatchesLearnedSpell(spellID, spellName, spell, aliases)
    if not spell or not spell.learned then return false end
    if spellID and spell.spellID and spellID == spell.spellID then return true end
    for _,aliasID in ipairs(aliases or {}) do
        if spellID and spellID == aliasID then return true end
    end
    return SpellNameEquals(spellName, spell)
end

local function IsMendingAbility(spellID, spellName)
    if spellID == SPELL.ELDRITCH_MENDING or spellID == BUILDHUB_SPELL.ELDRITCH_MENDING then return true end
    return MatchesLearnedSpell(spellID, spellName, spellbook.mending, {
        SPELL.ELDRITCH_MENDING, BUILDHUB_SPELL.ELDRITCH_MENDING,
    }) or NameMatches(spellName,{"Eldritch Mending","Soin occulte","Soins occultes"})
end

local function IsTrackedMeleeAbility(spellID, spellName)
    -- Strict level-aware allowlist: an ability from the final level-60 template
    -- counts only after this character has actually learned it.
    if MatchesLearnedSpell(spellID, spellName, spellbook.malevolence, {SPELL.MALEVOLENCE, BUILDHUB_SPELL.MALEVOLENCE}) then return true end
    if MatchesLearnedSpell(spellID, spellName, spellbook.blade, {SPELL.BLADE_EMPIRE, BUILDHUB_SPELL.BLADE_EMPIRE}) then return true end
    if MatchesLearnedSpell(spellID, spellName, spellbook.entropic, {BUILDHUB_SPELL.ENTROPIC_SLAM}) then return true end
    if MatchesLearnedSpell(spellID, spellName, spellbook.hammer, {BUILDHUB_SPELL.HAMMER_TWILIGHT}) then return true end
    return false
end

local function ArmInstantProc(seconds, reason)
    SetProcReady(seconds, reason)
end

local function ConsumeInstantProc(reason)
    ClearProcReady(reason)
end

local function OnPlayerMeleeAbilitySuccess(spellID, spellName)
    local instant = GetMendingInstantState()
    if instant then return end
    if not IsTrackedMeleeAbility(spellID, spellName) then return end

    local now = GetTime()
    -- The same custom cast can occasionally surface twice on Ascension. Never count it twice.
    if (now - (lastProcessedMeleeAt or 0)) < MELEE_DUPLICATE_WINDOW then
        Trace("melee duplicate ignored: "..tostring(spellName or spellID))
        return
    end
    lastProcessedMeleeAt = now
    lastQualifyingCastAt = now
    pendingMelee = true
    pendingMeleeAt = now
    Trace("melee queued: "..tostring(spellName or spellID).." progress="..tostring(localProcProgress))
end

local function OnCombatLogEvent(...)
    local timestamp,eventType,hideCaster,sourceGUID,sourceName,sourceFlags,sourceRaidFlags,destGUID,destName,destFlags,destRaidFlags,spellID,spellName,spellSchool,auraType,amount

    if CombatLogGetCurrentEventInfo then
        timestamp,eventType,hideCaster,sourceGUID,sourceName,sourceFlags,sourceRaidFlags,destGUID,destName,destFlags,destRaidFlags,spellID,spellName,spellSchool,auraType,amount = CombatLogGetCurrentEventInfo()
    else
        timestamp,eventType,sourceGUID,sourceName,sourceFlags,destGUID,destName,destFlags,spellID,spellName,spellSchool,auraType,amount = ...
    end

    local playerGUID = UnitGUID and UnitGUID("player") or nil
    local playerRelevant = playerGUID and (sourceGUID == playerGUID or destGUID == playerGUID)
    if playerRelevant and (eventType == "SPELL_CAST_SUCCESS" or string.find(tostring(eventType or ""), "SPELL_AURA_", 1, true) == 1) then
        RecordTrace("CLEU", eventType, spellID, spellName, amount)
    end

    -- Malevolent Power stack tracking. The critical transition is 2 stacks -> aura disappears:
    -- on CoA that is how the every-third-melee proc often presents itself to addons.
    -- We keep a hard READY lock once this happens, so it cannot immediately fall back to 1/3.
    if playerGUID and destGUID == playerGUID and NameMatches(spellName,{"Malevolent Power","Pouvoir malveillant"}) then
        if not procReady then
            if eventType == "SPELL_AURA_APPLIED" then
                pendingMelee = false
                localProcProgress = 1
                lastMalevolentStacks = 1
                lastMalevolentAuraSeen = GetTime()
                Trace("MP applied=1")
            elseif eventType == "SPELL_AURA_APPLIED_DOSE" then
                pendingMelee = false
                local stacks = tonumber(amount) or 2
                lastMalevolentStacks = stacks
                lastMalevolentAuraSeen = GetTime()
                if stacks >= 3 then
                    ArmInstantProc(10, "MP dose 3")
                else
                    localProcProgress = math.min(2, stacks)
                    Trace("MP dose="..tostring(stacks))
                end
            elseif eventType == "SPELL_AURA_REMOVED_DOSE" then
                pendingMelee = false
                local stacks = tonumber(amount) or 1
                lastMalevolentStacks = stacks
                localProcProgress = math.min(2, stacks)
                lastMalevolentAuraSeen = GetTime()
                Trace("MP removed dose="..tostring(stacks))
            elseif eventType == "SPELL_AURA_REMOVED" then
                pendingMelee = false
                local now = GetTime()
                -- If we were at 2 stacks and the aura vanished immediately around a melee ability,
                -- that is the third-trigger transition. Do NOT reset to 0/1.
                local recentCast = (now - (lastQualifyingCastAt or 0)) <= 0.60
                if (lastMalevolentStacks or localProcProgress or 0) >= 2 and recentCast then
                    ArmInstantProc(10, "MP 2->removed")
                elseif (lastMalevolentStacks or localProcProgress or 0) >= 2 and (now - (lastMalevolentAuraSeen or 0)) <= 0.30 then
                    ArmInstantProc(10, "MP removed apres 2")
                else
                    localProcProgress = 0
                    lastMalevolentStacks = 0
                    lastMalevolentExpiration = 0
                    Trace("MP removed/reset")
                end
                lastMalevolentAuraSeen = now
            end
        end
    end

    -- Mental Expansion is a confirmation signal only. Its REMOVED event is intentionally ignored:
    -- custom CoA auras can flicker/translate inconsistently. READY is cleared only by actually
    -- casting Eldritch Mending or by timeout.
    if playerGUID and destGUID == playerGUID and ((spellID == SPELL.MENTAL_EXPANSION) or NameMatches(spellName,{"Mental Expansion","Expansion mentale"})) then
        if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
            ArmInstantProc(10, "Mental Expansion")
        elseif eventType == "SPELL_AURA_REMOVED" then
            Trace("Mental Expansion removed (ignore)")
        end
    end

    if sourceGUID and playerGUID and sourceGUID == playerGUID then
        if eventType == "SPELL_CAST_SUCCESS" then
            -- Casting Eldritch Mending consumes the prepared instant-heal proc.
            if IsMendingAbility(spellID, spellName) then
                ConsumeInstantProc("Eldritch Mending cast")
            else
                OnPlayerMeleeAbilitySuccess(spellID, spellName)
            end
        end
    end

    -- Black Blood is a triggered aura. Some CoA builds attribute the aura event to the
    -- trigger rather than directly to the player, so exact spellID + group destination
    -- is accepted even when sourceGUID is unusual. This makes the timer much more stable.
    local bbName = SafeGetSpellInfo(SPELL.BLACK_BLOOD)
    local isBB = (spellID == SPELL.BLACK_BLOOD) or (bbName and spellName == bbName) or NameMatches(spellName,{"Black Blood","Sang noir"})
    local bbSourceOK = (sourceGUID and playerGUID and sourceGUID == playerGUID) or (spellID == SPELL.BLACK_BLOOD)
    if isBB and bbSourceOK and destGUID and IsGroupGUID(destGUID) then
        if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
            local d=GetBlackBloodFallbackDuration(); localBB[destGUID] = {expires=GetTime()+d, duration=d, stacks=1}
        elseif eventType == "SPELL_AURA_APPLIED_DOSE" then
            local d=GetBlackBloodFallbackDuration(); localBB[destGUID] = {expires=GetTime()+d, duration=d, stacks=tonumber(amount) or 2}
        elseif eventType == "SPELL_AURA_REMOVED" then
            localBB[destGUID] = nil
        elseif eventType == "SPELL_AURA_REMOVED_DOSE" then
            local d=localBB[destGUID]
            if d then d.stacks=math.max(1,(tonumber(amount) or d.stacks or 1)) end
        end
    end
end

-- ============================================================
-- Compact control button/menu
-- ============================================================
local control=CreateFrame("Button","CoAHereticHUDControl",UIParent)
control:SetWidth(32); control:SetHeight(32); control:SetMovable(true); control:SetClampedToScreen(true); control:RegisterForDrag("LeftButton"); control:SetFrameStrata("DIALOG")
control:RegisterForClicks("LeftButtonUp")
local controlIcon=control:CreateTexture(nil,"BACKGROUND")
controlIcon:SetWidth(22); controlIcon:SetHeight(22); controlIcon:SetPoint("CENTER",control,"CENTER",0,0)
controlIcon:SetTexture("Interface\\Icons\\Spell_Shadow_LifeDrain02"); controlIcon:SetTexCoord(0.08,0.92,0.08,0.92)
local controlBorder=control:CreateTexture(nil,"OVERLAY")
controlBorder:SetWidth(52); controlBorder:SetHeight(52); controlBorder:SetPoint("TOPLEFT",control,"TOPLEFT",0,0)
controlBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
local controlHighlight=control:CreateTexture(nil,"HIGHLIGHT")
controlHighlight:SetWidth(32); controlHighlight:SetHeight(32); controlHighlight:SetPoint("CENTER",control,"CENTER",0,0)
controlHighlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); controlHighlight:SetBlendMode("ADD")

local menu=CreateFrame("Frame","CoAHereticHUDMenu",UIParent)
menu:SetWidth(286); menu:SetHeight(358); menu:SetClampedToScreen(true); menu:SetFrameStrata("DIALOG")
menu:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
menu:SetBackdropColor(0.012,0.025,0.055,0.97); menu:SetBackdropBorderColor(0.25,0.88,1.0,0.90); menu:Hide()
local mt=menu:CreateFontString(nil,"OVERLAY","GameFontNormal"); mt:SetPoint("TOPLEFT",12,-12); mt:SetText("HERETIC • PROC HUD"); mt:SetTextColor(0.45,0.95,1)
local md=menu:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); md:SetPoint("TOPLEFT",12,-34); md:SetWidth(260); md:SetJustifyH("LEFT"); md:SetText("Soin occulte : icone uniquement quand le proc est pret.\nSang noir : un point par membre du groupe.\nAucun sort n'est lance automatiquement.")
local function MenuButton(text,x,y,w)
    local b=CreateFrame("Button",nil,menu,"UIPanelButtonTemplate"); b:SetWidth(w or 122); b:SetHeight(22); b:SetPoint("TOPLEFT",x,y); b:SetText(text); return b
end
local bTest=MenuButton("TEST",12,-92,122)
local bProcMove=MenuButton("DEPLACER PROC",148,-92,126)
local bBBMove=MenuButton("DEPLACER SANG NOIR",12,-122,122)
local bSound=MenuButton("SON : ON",148,-122,126)
local bProgress=MenuButton("PROGRESSION : ON",12,-152,122)
local bBBAlways=MenuButton("BB TOUJOURS : ON",148,-152,126)
local bKeybind=MenuButton("TOUCHE : ON",12,-182,122)
local bMinimap=MenuButton("BOUTON : ON",148,-182,126)
local bPresetCompact=MenuButton("COMPACT",12,-212,82)
local bPresetCentral=MenuButton("CENTRAL",102,-212,82)
local bPresetHealer=MenuButton("SOIGNEUR",192,-212,82)
local bScaleMinus=MenuButton("PROC -",12,-242,80)
local bScalePlus=MenuButton("PROC +",98,-242,80)
local bBBScaleMinus=MenuButton("BB -",184,-242,42)
local bBBScalePlus=MenuButton("BB +",232,-242,42)
local bBBAlert=MenuButton("TEST ALERTE BB",12,-272,262)
local bDebug=MenuButton("DIAGNOSTIC",12,-302,122)
local bReset=MenuButton("RESET",148,-302,126)

local hubManaged=false
local controlWasDragged=false
local function Atan2(y,x)
    if x>0 then return math.atan(y/x) end
    if x<0 and y>=0 then return math.atan(y/x)+math.pi end
    if x<0 and y<0 then return math.atan(y/x)-math.pi end
    if x==0 and y>0 then return math.pi/2 end
    if x==0 and y<0 then return -math.pi/2 end
    return 0
end

local function PositionControlButton()
    local db=EnsureDB()
    control:ClearAllPoints()
    if Minimap then
        local radius=80
        control:SetPoint("CENTER",Minimap,"CENTER",math.cos(db.buttonAngle or 4.15)*radius,math.sin(db.buttonAngle or 4.15)*radius)
    else
        control:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-210,-58)
    end
end

local function ApplyPositions()
    local db=EnsureDB()
    procAnchor:ClearAllPoints(); procAnchor:SetPoint("CENTER",UIParent,"CENTER",db.x,db.y); procAnchor:SetScale(db.procScale)
    bbFrame:ClearAllPoints(); bbFrame:SetPoint("CENTER",UIParent,"CENTER",db.bbX,db.bbY); bbFrame:SetScale(db.bbScale)
    PositionControlButton()
end

local function ApplyPreset(name)
    local db=EnsureDB()
    name=string.lower(name or "compact")
    if name=="central" then
        db.x,db.y=0,-105; db.bbX,db.bbY=0,-165; db.procScale,db.bbScale=1.05,1.0
    elseif name=="healer" or name=="soigneur" then
        name="healer"
        db.x,db.y=-185,-85; db.bbX,db.bbY=-185,-145; db.procScale,db.bbScale=1.15,1.10
    else
        name="compact"
        db.x,db.y=-250,-205; db.bbX,db.bbY=-250,-262; db.procScale,db.bbScale=0.90,0.90
    end
    db.hudPreset=name
    ApplyPositions()
end

local function UpdateMenu()
    local db=EnsureDB()
    md:SetText("Cultist Heretic • niveau "..tostring(playerLevel > 0 and playerLevel or "?").." • mode "..tostring(db.hudPreset or "compact")..".\nSoin occulte apparait seulement quand il est instantane.\nChaque point represente un membre pour Sang noir.")
    bProcMove:SetText(db.locked and "DEPLACER PROC" or "VERROUILLER PROC")
    bBBMove:SetText(db.bbLocked and "DEPLACER SANG NOIR" or "VERROUILLER SANG NOIR")
    bSound:SetText("SON : "..(db.sound and "ON" or "OFF"))
    bProgress:SetText("PROGRESSION : "..(db.showProgress and "ON" or "OFF"))
    bBBAlways:SetText("BB TOUJOURS : "..(db.bbAlways and "ON" or "OFF"))
    bKeybind:SetText("TOUCHE : "..(db.showKeybind and "ON" or "OFF"))
    bMinimap:SetText("BOUTON : "..(db.buttonHidden and "OFF" or "ON"))
end

local function ToggleHereticMenu(centered)
    if menu:IsShown() then
        menu:Hide()
        return
    end
    menu:ClearAllPoints()
    if centered or not control:IsVisible() then
        menu:SetPoint("CENTER",UIParent,"CENTER",0,0)
    else
        menu:SetPoint("TOPLEFT",control,"BOTTOMRIGHT",5,-5)
    end
    UpdateMenu()
    menu:Show()
end

control:SetScript("OnMouseDown",function() controlWasDragged=false end)
control:SetScript("OnDragStart",function(self)
    controlWasDragged=true
    self:SetScript("OnUpdate",function()
        if not Minimap then return end
        local cursorX,cursorY=GetCursorPosition()
        local scale=UIParent:GetEffectiveScale() or 1
        local minimapX,minimapY=Minimap:GetCenter()
        if not minimapX or not minimapY then return end
        cursorX,cursorY=cursorX/scale,cursorY/scale
        EnsureDB().buttonAngle=Atan2(cursorY-minimapY,cursorX-minimapX)
        PositionControlButton()
    end)
end)
control:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil); PositionControlButton() end)
control:SetScript("OnClick",function()
    if controlWasDragged then controlWasDragged=false; return end
    ToggleHereticMenu(false)
end)
control:SetScript("OnEnter",function(self) if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("CoA Heretic Helper",0.55,0.88,1); GameTooltip:AddLine("Clic : reglages",1,1,1); GameTooltip:AddLine("Glisser : deplacer autour de la minicarte",0.7,0.9,1); GameTooltip:Show() end end)
control:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)

local function SyncMalevolentPowerState(forceScan)
    if procReady then
        pendingMelee = false
        return
    end

    local now = GetTime()
    if not forceScan and not pendingMelee and now - lastMalevolentScanAt < MALEVOLENT_SCAN_INTERVAL then return end
    lastMalevolentScanAt = now
    local aura = FindAura("player", nil, {"Malevolent Power", "Pouvoir malveillant"})

    -- Real aura always wins when CoA exposes it.
    if aura and aura.count and aura.count > 0 then
        local c = tonumber(aura.count) or 1
        lastMalevolentStacks = c
        lastMalevolentExpiration = aura.expiration or 0
        lastMalevolentAuraSeen = now
        if c >= 3 then
            pendingMelee = false
            ArmInstantProc(10, "poll aura>=3")
            return
        end
        localProcProgress = math.min(2, c)

        -- Give the aura up to 0.32 s to change after a qualifying cast. If the client
        -- still reports 2/3 after the third cast, the local state safely promotes READY.
        if pendingMelee and (now - pendingMeleeAt) >= 0.32 then
            if localProcProgress >= 2 then
                pendingMelee = false
                ArmInstantProc(10, "3e melee - aura stale a 2")
            else
                pendingMelee = false
            end
        end
        return
    end

    -- If the aura vanished from 2 stacks shortly after a melee ability, that is the
    -- normal consume-to-proc transition on CoA.
    if lastMalevolentStacks >= 2 then
        local early = lastMalevolentExpiration and lastMalevolentExpiration > 0 and now < (lastMalevolentExpiration - 0.10)
        local recentCast = (now - (lastQualifyingCastAt or 0)) <= 0.65
        if early or recentCast then
            pendingMelee = false
            ArmInstantProc(10, early and "poll 2->absent early" or "poll 2->absent cast")
            return
        end
    end

    -- Hidden/localized aura fallback. We do not count immediately on SPELL_CAST_SUCCESS;
    -- waiting 0.18 s prevents races where the real aura arrives just after the cast event.
    if pendingMelee and (now - pendingMeleeAt) >= 0.18 then
        pendingMelee = false
        if (localProcProgress or 0) >= 2 then
            ArmInstantProc(10, "3e melee fallback")
        else
            localProcProgress = math.min(2, (localProcProgress or 0) + 1)
            lastMalevolentStacks = localProcProgress
            Trace("fallback committed="..tostring(localProcProgress))
        end
    end
end

local function Refresh(forceAuraScan)
    local db=EnsureDB(); local now=GetTime(); local testMode=testUntil>now; local context=hereticDetected or testMode
    if bbSoundTestAt>0 and now>=bbSoundTestAt then
        bbSoundTestAt=0
        PlayBlackBloodWarning("critical", true)
    end
    if context and not hubManaged and not db.buttonHidden then control:Show() else control:Hide() end
    if not context then menu:Hide() end
    if not db.enabled or not context then instantFrame:Hide(); progressFrame:Hide(); procAnchor:Hide(); bbFrame:Hide(); return end

    SyncMalevolentPowerState(forceAuraScan)
    local instant,aura,castMS=GetMendingInstantState(forceAuraScan)
    if testMode then
        local since=testUntil-now
        if since>4 then instant=false; aura=nil else instant=true end
    end

    if instant then
        progressFrame:Hide()
        instantIcon:SetTexture((spellbook.mending and spellbook.mending.icon) or (aura and aura.icon) or "Interface\\Icons\\Spell_Holy_FlashHeal")
        local rem=0
        local duration=10
        if aura then rem=Remaining(aura)
        elseif localInstantUntil and localInstantUntil>now then rem=localInstantUntil-now
        elseif testMode then rem=math.max(0,testUntil-now) end
        if aura and aura.duration and aura.duration>0 then duration=aura.duration end
        instantTimer:SetText(rem>0 and string.format("%.1f",rem) or "")
        instantLabel:SetText((spellbook.mending and spellbook.mending.name) or "Soin occulte")
        instantKeybind:SetText(db.showKeybind and FindSpellKeybind(spellbook.mending) or "")
        if instantCooldown and instantCooldown.SetCooldown then
            if rem>0 then instantCooldown:SetCooldown(now + rem - duration, duration)
            else instantCooldown:SetCooldown(0, 0) end
        end
        instantFrame:Show(); procAnchor:Show()
    else
        instantFrame:Hide()
        local progress = GetProcProgress()
        UpdateProgressVisual(progress, testMode)
        if progressFrame:IsShown() or not db.locked then procAnchor:Show() else procAnchor:Hide() end
    end

    if instant and not lastInstant then
        localProcProgress=0
        if not testMode then PlayProcSound() end
    end
    lastInstant=instant

    if not db.locked then procEdit:Show(); procAnchor:EnableMouse(true); procAnchor:Show() else procEdit:Hide(); procAnchor:EnableMouse(false) end
    UpdateBlackBlood(testMode, forceAuraScan)
end

local function HandleCommand(msg)
    local db=EnsureDB(); msg=string.lower((msg or ""):gsub("^%s+",""):gsub("%s+$",""))
    if msg=="" or msg=="menu" or msg=="help" then
        ToggleHereticMenu(true)
    elseif msg=="test" then testUntil=GetTime()+8; Chat("test 8 s : progression -> proc instant + Sang noir.")
    elseif msg=="unlock" then db.locked=false
    elseif msg=="lock" then db.locked=true
    elseif msg=="bbunlock" then db.bbLocked=false
    elseif msg=="bblock" then db.bbLocked=true
    elseif msg=="sound" then db.sound=not db.sound
    elseif msg=="bbsound" then
        PlayBlackBloodWarning("expiring", true)
        bbSoundTestAt=GetTime()+0.8
        Chat("test Sang noir : avertissement, puis alarme critique.")
    elseif msg=="progress" then db.showProgress=not db.showProgress
    elseif msg=="keybind" then db.showKeybind=not db.showKeybind
    elseif msg=="button" then db.buttonHidden=not db.buttonHidden
    elseif string.match(msg,"^preset%s+") then
        local preset=string.match(msg,"^preset%s+(%S+)$")
        if preset=="compact" or preset=="central" or preset=="healer" or preset=="soigneur" then
            ApplyPreset(preset)
            Chat("mode visuel "..tostring(db.hudPreset).." applique.")
        else
            Chat("Usage : /hh preset compact|central|healer")
        end
    elseif msg=="trace" then traceEnabled=not traceEnabled; Chat("trace combat="..(traceEnabled and "ON" or "OFF"))
    elseif msg=="trace clear" then db.eventTrace={}; Chat("journal des evenements efface.")
    elseif msg=="events" then
        local entries=db.eventTrace or {}; local first=math.max(1,#entries-11)
        if #entries==0 then Chat("aucun evenement capture : active /hh trace avant le combat.") end
        for i=first,#entries do
            local e=entries[i]
            Chat(string.format("%s %s id=%s name=%s amount=%s",tostring(e.source),tostring(e.event),tostring(e.spellID or "?"),tostring(e.spellName or "?"),tostring(e.amount or "-")))
        end
    elseif msg=="bbalways" then db.bbAlways=not db.bbAlways
    elseif msg=="reset" then
        db.buttonAngle=4.15; db.buttonHidden=false; db.showKeybind=true; ApplyPreset("compact"); localProcProgress=0; localInstantUntil=0; procReady=false; procReadyUntil=0; lastMalevolentAuraSeen=0; lastMalevolentStacks=0; lastMalevolentExpiration=0; lastQualifyingCastAt=0; pendingMelee=false; pendingMeleeAt=0; lastProcessedMeleeAt=0; lastMalevolentScanAt=0; lastMendingScanAt=0; bbPrevCovered=0; bbPrevTotal=0; bbWarnedExpiryCycle=false; bbWarnedCriticalCycle=false; bbWarnedMissingCycle=false; bbLastScanAt=0; bbCachedState={covered=0,total=1,remain=0,duration=10,maxStacks=0,details={},sampledAt=0}; localBB={}; Chat("positions et trackers reinitialises.")
    elseif msg=="debug" then
        RefreshSpecDetection(); local instant,aura,castMS=GetMendingInstantState(); local c,t,r,d,s=ScanBlackBlood()
        Chat("Profil="..BUILD_PROFILE.name.." | niveau="..tostring(playerLevel).." | Heretic="..tostring(hereticDetected).." | Soin appris="..tostring(spellbook.mending and spellbook.mending.learned or false).." | cast="..tostring(castMS).."ms | instant="..tostring(instant))
        Chat("Progression="..tostring(localProcProgress).."/3 | MP last="..tostring(lastMalevolentStacks).." | READY="..tostring(procReady).." | Mental Expansion="..tostring(aura and aura.name or "non visible").." | reste="..string.format("%.1f",math.max(0,(procReadyUntil or 0)-GetTime())))
        Chat("Sang noir="..tostring(c).."/"..tostring(t).." | min="..string.format("%.1f",r).."s | max stacks="..tostring(s))
    else
        local v=string.match(msg,"^scale%s+([%d%.]+)$")
        if v then db.procScale=Clamp(tonumber(v),0.60,1.80); procAnchor:SetScale(db.procScale)
        else
            v=string.match(msg,"^bbscale%s+([%d%.]+)$")
            if v then db.bbScale=Clamp(tonumber(v),0.60,1.80); bbFrame:SetScale(db.bbScale)
            else Chat("/hh test | preset compact|central|healer | unlock/lock | sound | progress | keybind | button | bbalways | trace | events | debug | reset") end
        end
    end
    UpdateMenu(); Refresh()
end

bTest:SetScript("OnClick",function() HandleCommand("test") end)
bProcMove:SetScript("OnClick",function() HandleCommand(EnsureDB().locked and "unlock" or "lock") end)
bBBMove:SetScript("OnClick",function() HandleCommand(EnsureDB().bbLocked and "bbunlock" or "bblock") end)
bSound:SetScript("OnClick",function() HandleCommand("sound") end)
bProgress:SetScript("OnClick",function() HandleCommand("progress") end)
bBBAlways:SetScript("OnClick",function() HandleCommand("bbalways") end)
bKeybind:SetScript("OnClick",function() HandleCommand("keybind") end)
bMinimap:SetScript("OnClick",function() HandleCommand("button") end)
bPresetCompact:SetScript("OnClick",function() HandleCommand("preset compact") end)
bPresetCentral:SetScript("OnClick",function() HandleCommand("preset central") end)
bPresetHealer:SetScript("OnClick",function() HandleCommand("preset healer") end)
bScaleMinus:SetScript("OnClick",function() local d=EnsureDB(); d.procScale=Clamp(d.procScale-0.1,0.6,1.8); procAnchor:SetScale(d.procScale); UpdateMenu() end)
bScalePlus:SetScript("OnClick",function() local d=EnsureDB(); d.procScale=Clamp(d.procScale+0.1,0.6,1.8); procAnchor:SetScale(d.procScale); UpdateMenu() end)
bBBScaleMinus:SetScript("OnClick",function() local d=EnsureDB(); d.bbScale=Clamp(d.bbScale-0.1,0.6,1.8); bbFrame:SetScale(d.bbScale); UpdateMenu() end)
bBBScalePlus:SetScript("OnClick",function() local d=EnsureDB(); d.bbScale=Clamp(d.bbScale+0.1,0.6,1.8); bbFrame:SetScale(d.bbScale); UpdateMenu() end)
bBBAlert:SetScript("OnClick",function() HandleCommand("bbsound") end)
bDebug:SetScript("OnClick",function() HandleCommand("debug") end)
bReset:SetScript("OnClick",function() HandleCommand("reset") end)

CoAHereticHelperAPI = CoAHereticHelperAPI or {}
function CoAHereticHelperAPI:Toggle()
    ToggleHereticMenu(true)
end
function CoAHereticHelperAPI:Show()
    if not menu:IsShown() then ToggleHereticMenu(true) end
end
function CoAHereticHelperAPI:SetHubManaged(value)
    hubManaged=value and true or false
    Refresh(false)
end

-- Robust cast-consumption fallback for CoA custom spells.
-- On 3.3.5/Ascension, COMBAT_LOG_EVENT_UNFILTERED can miss or localize custom spell casts,
-- while UNIT_SPELLCAST_SUCCEEDED is generally emitted by the player unit.
local function OnUnitSpellcastSucceeded(unit, ...)
    if unit ~= "player" then return end

    local args = {...}
    local eventSpellName = nil
    local eventSpellID = nil

    -- API signatures differ across 3.3.5-derived clients.  Pick the first useful
    -- spell-name string and the last positive numeric value as the spell ID.
    for i=1,#args do
        local v = args[i]
        if type(v) == "string" and not eventSpellName and v ~= "" then
            eventSpellName = v
        elseif type(v) == "number" and v > 0 then
            eventSpellID = v
        end
    end

    local isMending = IsMendingAbility(eventSpellID, eventSpellName)

    if isMending or IsTrackedMeleeAbility(eventSpellID, eventSpellName) then
        RecordTrace("UNIT", "UNIT_SPELLCAST_SUCCEEDED", eventSpellID, eventSpellName)
    end

    if isMending then
        -- Consume immediately on a successful player cast.  This is intentionally
        -- unconditional: even if CoA fails to remove Mental Expansion promptly,
        -- the HUD must disappear as soon as the heal was actually used.
        ClearProcReady("UNIT_SPELLCAST_SUCCEEDED")
        Trace("Mending success via UNIT_SPELLCAST_SUCCEEDED id="..tostring(eventSpellID).." name="..tostring(eventSpellName))
    elseif IsTrackedMeleeAbility(eventSpellID, eventSpellName) then
        -- CoA emits this more consistently than the combat log for several
        -- custom melee abilities. The duplicate window merges both sources.
        OnPlayerMeleeAbilitySuccess(eventSpellID, eventSpellName)
        Trace("melee success via UNIT_SPELLCAST_SUCCEEDED id="..tostring(eventSpellID).." name="..tostring(eventSpellName))
    end
end

SLASH_COAHERETICHUD1="/hh"
SLASH_COAHERETICHUD2="/heretichud"
SlashCmdList.COAHERETICHUD=HandleCommand

local events=CreateFrame("Frame")
for _,ev in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEVEL_UP","PLAYER_TALENT_UPDATE","SPELLS_CHANGED","UNIT_AURA","UNIT_SPELLCAST_SUCCEEDED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE","COMBAT_LOG_EVENT_UNFILTERED"}) do
    pcall(events.RegisterEvent,events,ev)
end
events:SetScript("OnEvent",function(self,event,...)
    if event=="PLAYER_LOGIN" then
        EnsureDB(); ApplyPositions(); RefreshSpecDetection(); Chat("v3.8.0 charge : HUD compact, touche du proc et points Sang noir par membre. /hh")
    elseif event=="SPELLS_CHANGED" or event=="PLAYER_TALENT_UPDATE" or event=="PLAYER_LEVEL_UP" or event=="PLAYER_ENTERING_WORLD" then
        RefreshSpecDetection()
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        OnUnitSpellcastSucceeded(...)
    elseif event=="COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent(...)
    end
    local forceAuraScan = event=="UNIT_AURA" or event=="PARTY_MEMBERS_CHANGED"
        or event=="RAID_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD"
    Refresh(forceAuraScan)
end)
events:SetScript("OnUpdate",function(self,dt)
    elapsed=elapsed+dt
    if elapsed<UPDATE_INTERVAL then return end
    elapsed=0
    Refresh(false)
end)

EnsureDB(); ApplyPositions(); RefreshSpecDetection(); Refresh()
