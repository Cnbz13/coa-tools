import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const tocPath = 'addons/CoAHereticHelper/CoAHereticHelper.toc';
const luaPath = 'addons/CoAHereticHelper/CoAHereticHelper.lua';

test('CoA Heretic Helper v3.9.0 remains a Lua 5.1 information HUD, never a rotation bot', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 3\.9\.0$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
  assert.doesNotMatch(lua, /lance Malevolence maintenant/i);
});

test('Heretic settings panel is draggable, persistent and never obscures its tests', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'menu:SetMovable(true)', 'menuDragHandle:RegisterForDrag("LeftButton")',
    'menu:StartMoving()', 'menu:StopMovingOrSizing()',
    'db.menuX=menuX-parentX', 'db.menuY=menuY-parentY',
    'type(db.menuX)=="number"', 'PositionHereticMenu(centered)'
  ]) assert.ok(lua.includes(required), `missing movable menu feature: ${required}`);
  assert.match(lua, /elseif msg=="test" then menu:Hide\(\); testUntil=/,
    'the visual test must hide the settings panel first');
  assert.match(lua, /elseif msg=="bbsound" then\s+menu:Hide\(\)/,
    'the Black Blood sound test must hide the settings panel first');
  assert.match(lua, /db\.menuX=nil; db\.menuY=nil; ApplyPreset\("compact"\); PositionHereticMenu\(true\)/,
    'reset must clear and recenter the saved menu position');
});

test('Heretic 3.9 provides a compact proc and per-member Black Blood HUD', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'CooldownFrameTemplate', 'instantCooldown:SetCooldown', 'FindSpellKeybind',
    'BindingForActionSlot', 'instantKeybind', 'for i=1,2 do',
    'local bbDots = {}', 'for i=1,40 do', 'UpdateBlackBloodDots',
    'details=details', 'ApplyPreset', 'preset compact|central|healer',
    'CoAHereticHelperAPI', 'SetHubManaged', 'CoAHereticHUDControl',
    'MiniMap-TrackingBorder', 'buttonAngle'
  ]) assert.ok(lua.includes(required), `missing Heretic visual feature: ${required}`);
  assert.match(lua, /if total<=5 then size,step,columns=9,13,5/,
    'party coverage must use large individual dots');
  assert.match(lua, /elseif total<=10 then size,step,columns=7,10,10/,
    'larger groups must compact the per-member visualization');
});

test('instant Eldritch Mending is locked until successful consumption or timeout', async () => {
  const lua = await readFile(luaPath, 'utf8');
  assert.match(lua, /if procReady and procReadyUntil > now then[\s\S]+return true, nil, GetMendingCastMS\(\)/);
  assert.match(lua, /local isMending = IsMendingAbility\(eventSpellID, eventSpellName\)[\s\S]+ClearProcReady\("UNIT_SPELLCAST_SUCCEEDED"\)/);
  assert.match(lua, /SPELL_AURA_REMOVED" then[\s\S]+Mental Expansion removed \(ignore\)/);
  assert.match(lua, /if instant then[\s\S]+progressFrame:Hide\(\)/);
});

test('Malevolent Power merges exact spell IDs, combat log and UNIT_SPELLCAST_SUCCEEDED', async () => {
  const lua = await readFile(luaPath, 'utf8');
  assert.match(lua, /local function SpellIDAt\(index\)/);
  assert.match(lua, /spellID=SpellIDAt\(i\)/);
  assert.match(lua, /MELEE_DUPLICATE_WINDOW = 0\.25/);
  assert.match(lua, /elseif IsTrackedMeleeAbility\(eventSpellID, eventSpellName\) then[\s\S]+OnPlayerMeleeAbilitySuccess\(eventSpellID, eventSpellName\)/);
  assert.match(lua, /if \(localProcProgress or 0\) >= 2 then[\s\S]+ArmInstantProc\(10, "3e melee fallback"\)/);
});

test('the Build Hub profile is level-aware and only accepts abilities learned by this character', async () => {
  const lua = await readFile(luaPath, 'utf8');
  assert.match(lua, /id = "5ba4e749-4871-4e36-aeeb-52c0678bc26c"/);
  assert.match(lua, /playerLevel = \(UnitLevel and UnitLevel\("player"\)\) or 0/);
  assert.match(lua, /learned=true/);
  assert.match(lua, /if not spell or not spell\.learned then return false end/);
  assert.match(lua, /BUILDHUB_SPELL\.ELDRITCH_MENDING/);
  assert.match(lua, /BUILDHUB_SPELL\.BLADE_EMPIRE/);
  assert.match(lua, /BUILDHUB_SPELL\.MALEVOLENCE/);
  assert.doesNotMatch(lua, /if spellID == SPELL\.MALEVOLENCE or spellID == SPELL\.BLADE_EMPIRE then return true end/);
  assert.doesNotMatch(lua, /Abyssal Strike|Frappe abyssale/);
});

test('Black Blood uses two strong alerts without the whisper sound and throttles group scans', async () => {
  const lua = await readFile(luaPath, 'utf8');
  assert.match(lua, /BLACK_BLOOD_SCAN_INTERVAL = 0\.20/);
  assert.match(lua, /now - bbLastScanAt >= BLACK_BLOOD_SCAN_INTERVAL/);
  assert.match(lua, /events:SetScript\("OnUpdate"/);
  assert.doesNotMatch(lua, /procAnchor:SetScript\("OnUpdate"/);
  assert.match(lua, /PlayBlackBloodWarning\("expiring"\)/);
  assert.match(lua, /PlayBlackBloodWarning\("critical"\)/);
  assert.match(lua, /pcall\(PlaySound, "RaidWarning"\)/);
  assert.match(lua, /pcall\(PlaySound, "igQuestFailed"\)/);
  assert.doesNotMatch(lua, /PlaySound, "TellMessage"/);
  assert.match(lua, /TEST ALERTE BB/);
});

test('Heretic 3.9 exposes explainable proc state and independently configurable Black Blood alerts', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'db.procSound', 'db.bbSound', 'db.bbWarnSeconds', 'db.bbCriticalSeconds',
    'lastProcReason', 'procInfo', 'bbInfo', 'ReadBlackBloodState(false)',
    'SON PROC', 'SON BB', 'ALERTE : ', 'CycleBlackBloodTiming',
    'msg=="procsound"', 'msg=="bbmute"', 'msg=="bbtiming"'
  ]) assert.ok(lua.includes(required), `missing Heretic 3.9 diagnostic feature: ${required}`);
  assert.match(lua, /remain<=db\.bbWarnSeconds/);
  assert.match(lua, /remain<=db\.bbCriticalSeconds/);
  assert.match(lua, /not db\.bbSound and not force/,
    'Black Blood sound must be independently muteable');
  assert.match(lua, /if db\.procSound and PlaySound/,
    'proc sound must be independently muteable');
  assert.doesNotMatch(lua, /remain<=3\.0[\s\S]+remain<=1\.5/,
    'runtime alert thresholds must no longer be hard-coded');
});
