import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const tocPath = 'addons/CoAStormbringerHelper/CoAStormbringerHelper.toc';
const luaPath = 'addons/CoAStormbringerHelper/CoAStormbringerHelper.lua';

test('Stormbringer Helper is a strict Lua 5.1 recommendation HUD', async () => {
  const [toc, lua] = await Promise.all([readFile(tocPath, 'utf8'), readFile(luaPath, 'utf8')]);
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 1\.0\.0$/m);
  assert.match(toc, /^## SavedVariables: CoAStormbringerHelperDB$/m);
  assert.match(toc, /^CoAStormbringerUpdates\.lua\r?\nCoAStormbringerHelper\.lua$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack|TargetUnit)\b/);
  for (const api of ['BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer', 'CombatLogGetCurrentEventInfo', 'AuraUtil', 'Enum.']) {
    assert.equal(lua.includes(api), false, `forbidden Retail API: ${api}`);
  }
});

test('Stormbringer Helper follows level, specialization, spellbook and CoA talents', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'SOURCE_DATE = "2026-08-26"', 'UnitLevel("player")', 'ScanSpellbook', 'ScanTalents',
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellBookItemName', 'GetNumTalentTabs',
    'C_ClassInfo.GetAllSpecs', 'C_ClassInfo.GetSpecInfo', 'CoALootDeciderAPI.GetAdaptiveBuild',
    'Lightning', 'Maelstrom', 'Wind', 'Initiation', 'PLAYER_LEVEL_UP', 'SPELLS_CHANGED',
    'ACTIVE_TALENT_GROUP_CHANGED', 'CHARACTER_POINTS_CHANGED', 'évolution détectée automatiquement'
  ]) assert.ok(lua.includes(required), `missing adaptive feature: ${required}`);
});

test('Stormbringer Helper models Static, procs, targets, summons and spec priorities', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'UnitPowerMax', 'UnitPower', 'ReadStatic', 'ConductiveStacks', 'DetectProc',
    'SPELL_SUMMON', 'ownedSummons', 'SummonCounts', 'activeEnemies', 'COMBAT_LOG_EVENT_UNFILTERED',
    'Arm of Thorim', 'Forked Lightning', 'Volt', 'Electrocute', 'Storm Ascendance',
    'Torrential Wrath', 'Drown', 'Flow of Wrath', 'Summon: Thunder Orb',
    'Summon: Air Elemental', 'Gale', 'Aeroblast', 'Child of the Storm',
    'GetSpellCooldown', 'IsUsableSpell', 'IsSpellInRange', 'ActionKeybind'
  ]) assert.ok(lua.includes(required), `missing Stormbringer mechanic: ${required}`);
  assert.match(lua, /minStatic = 75/);
  assert.match(lua, /maxTargetHealth = 35/);
  assert.match(lua, /minConductive = 3/);
  assert.match(lua, /servantMissing = true/);
});

test('Stormbringer Helper stays compact, movable and explainable', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'CoAStormbringerHUD', 'CoAStormbringerMenu', 'CoAStormbringerLevelToast',
    'CooldownFrameTemplate', 'UI-ActionButton-Border', 'OnDragStop', 'db.x', 'db.y',
    'STORMBRINGER • GLISSER POUR DÉPLACER', 'Aucun sort ne sera lancé',
    'SLASH_COASTORMBRINGER1 = "/storm"', 'CoAStormbringerHelperAPI', 'SetHubManaged'
  ]) assert.ok(lua.includes(required), `missing visual or diagnostic feature: ${required}`);
  for (const command of ['status', 'scan', 'unlock', 'lock', 'test', 'sound', 'text', 'burst', 'debug', 'reset']) {
    assert.match(lua, new RegExp(`command == "${command}"`));
  }
});

test('Stormbringer Helper receives official update notices from the Manager', async () => {
  const [lua, updates, manager] = await Promise.all([
    readFile(luaPath, 'utf8'),
    readFile('addons/CoAStormbringerHelper/CoAStormbringerUpdates.lua', 'utf8'),
    readFile('src/core/addons.js', 'utf8')
  ]);
  for (const required of ['PromptStormUpdates', 'CoARotationUpdateFeed.items', 'db.updateSeen', 'MISE À JOUR ASCENSION', 'CoAMessageCenter.AddMessage']) {
    assert.ok(lua.includes(required), `missing update warning: ${required}`);
  }
  assert.match(updates, /CoARotationUpdateFeed/);
  assert.match(manager, /CoAStormbringerUpdates\.lua/);
  assert.match(manager, /preservedStormbringerFeed/);
});
