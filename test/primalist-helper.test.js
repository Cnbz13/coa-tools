import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const tocPath = 'addons/CoAPrimalistHelper/CoAPrimalistHelper.toc';
const luaPath = 'addons/CoAPrimalistHelper/CoAPrimalistHelper.lua';

test('Primalist Helper is a strict Lua 5.1 recommendation HUD', async () => {
  const [toc, lua] = await Promise.all([readFile(tocPath, 'utf8'), readFile(luaPath, 'utf8')]);
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 1\.1\.0$/m);
  assert.match(toc, /^## SavedVariables: CoAPrimalistHelperDB$/m);
  assert.match(toc, /^CoAPrimalistUpdates\.lua\r?\nCoAPrimalistHelper\.lua$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack|TargetUnit)\b/);
  for (const api of ['BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer', 'CombatLogGetCurrentEventInfo', 'AuraUtil', 'Enum.']) {
    assert.equal(lua.includes(api), false, `forbidden Retail API: ${api}`);
  }
});

test('Primalist Helper follows level, specialization, spellbook and live CoA talents', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'SOURCE_DATE = "2026-08-26"', 'UnitLevel("player")', 'ScanSpellbook', 'ScanTalents',
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellBookItemName', 'GetNumTalentTabs',
    'C_ClassInfo.GetAllSpecs', 'C_ClassInfo.GetSpecInfo', 'CoALootDeciderAPI.GetAdaptiveBuild',
    'Wildwalker', 'Geomancy', 'Grovekeeper', 'Mountain King', 'Initiation', 'PLAYER_LEVEL_UP',
    'SPELLS_CHANGED', 'ACTIVE_TALENT_GROUP_CHANGED', 'CHARACTER_POINTS_CHANGED',
    'évolution détectée automatiquement'
  ]) assert.ok(lua.includes(required), `missing adaptive feature: ${required}`);
});

test('Primalist Helper models all four roles, Rage, procs, pets and targets', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'ReadRage', 'UnitPowerMax', 'EarthshapingStacks', 'DetectProc', 'PetPresent', 'SPELL_SUMMON',
    'ownedSummons', 'activeEnemies', 'COMBAT_LOG_EVENT_UNFILTERED', 'HealingContext', 'DispellableDebuff',
    'Totemic Smash', 'Primal Shred', "Rylak's Bite", 'Wildclaw', 'Terrasurge', 'Lithic Lance',
    'Seismic Tremor', 'Geode Barrage', 'Seismic Wave', 'Spirit Charge', 'Sacred Grove',
    'Mountain Fury', 'Quake', 'Rock Barrier', 'Earthen Avatar', 'GetSpellCooldown',
    'IsUsableSpell', 'IsSpellInRange', 'ActionKeybind'
  ]) assert.ok(lua.includes(required), `missing Primalist mechanic: ${required}`);
  assert.match(lua, /minEarthshaping = 5/);
  assert.match(lua, /minLowAllies = 3/);
  assert.match(lua, /targetCasting = true/);
  assert.match(lua, /petMissing = true/);
});

test('Primalist Helper stays compact, movable, targeted and explainable', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'CoAPrimalistHUD', 'CoAPrimalistMenu', 'CoAPrimalistLevelToast', 'CooldownFrameTemplate',
    'UI-ActionButton-Border', 'OnDragStop', 'TargetLabel', 'db.x', 'db.y',
    'PRIMALIST • GLISSER POUR DÉPLACER', 'Aucun sort ne sera lancé',
    'SLASH_COAPRIMALIST1 = "/primal"', 'CoAPrimalistHelperAPI', 'SetHubManaged', 'SetUniversalManaged'
  ]) assert.ok(lua.includes(required), `missing visual or diagnostic feature: ${required}`);
  for (const command of ['status', 'scan', 'unlock', 'lock', 'test', 'sound', 'text', 'burst', 'debug', 'reset']) {
    assert.match(lua, new RegExp(`command == "${command}"`));
  }
});

test('Primalist Helper receives official update notices from the Manager', async () => {
  const [lua, updates, manager] = await Promise.all([
    readFile(luaPath, 'utf8'),
    readFile('addons/CoAPrimalistHelper/CoAPrimalistUpdates.lua', 'utf8'),
    readFile('src/core/addons.js', 'utf8')
  ]);
  for (const required of ['PromptPrimalistUpdates', 'CoARotationUpdateFeed.items', 'db.updateSeen', 'MISE À JOUR ASCENSION', 'CoAMessageCenter.AddMessage']) {
    assert.ok(lua.includes(required), `missing update warning: ${required}`);
  }
  assert.match(updates, /CoARotationUpdateFeed/);
  assert.match(manager, /CoAPrimalistUpdates\.lua/);
  assert.match(manager, /preservedPrimalistFeed/);
});
