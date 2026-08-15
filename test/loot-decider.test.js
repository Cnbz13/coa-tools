import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const tocPath = 'addons/CoALootDecider/CoALootDecider.toc';
const luaPath = 'addons/CoALootDecider/CoALootDecider.lua';

test('CoA Loot Decider targets Ascension 3.3.5 and parses as Lua 5.1', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## SavedVariables: CoALootDeciderDB$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));

  for (const retailApi of [
    'BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer',
    'C_Item', 'Enum.', 'CreateFromMixins', 'RegisterUnitEvent'
  ]) assert.equal(lua.includes(retailApi), false, `forbidden Retail API: ${retailApi}`);
});

test('CoA Loot Decider uses the exact CoA specialization catalog and compares the correct equipment slots', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'GetInventoryItemLink("player", slot)', 'GetItemStats', 'GetItemInfo',
    'INVTYPE_FINGER = { 11, 12 }', 'INVTYPE_TRINKET = { 13, 14 }',
    'INVTYPE_2HWEAPON = { 16, 17 }', 'ComparisonFor', 'CompatibilityProblem',
    'CoALootDeciderDB.threshold', 'CoALootDeciderDB.customWeights',
    'C_ClassInfo.GetAllSpecs', 'C_ClassInfo.GetSpecInfo', 'GetSpecialization',
    'GetSpecializationInfo', 'specializationIndex',
    'GetUnitPrimaryStat', 'ResolvePrimaryStats', 'UNIT_PRIMARY_STAT_NAMES',
    'specInfo.PrimaryStats', 'specInfo.CasterDPS', 'specInfo.MeleeDPS',
    'specInfo.RangedDPS', 'specInfo.Healer', 'specInfo.Tank',
    'PrimaryStats absentes pour'
  ]) assert.ok(lua.includes(required), `missing comparison feature: ${required}`);
  assert.match(lua, /local combined = ScoreItem\(main\) \+ ScoreItem\(off\)/);
  assert.match(lua, /if lowestScore == nil or score < lowestScore/);
  assert.match(lua, /GetSpecializationInfo, specializationIndex[\s\S]+catalogID == specializationID/,
    'the active specialization index must be resolved to its CoA catalog ID');
  assert.match(lua, /specInfo\.PrimaryStats[\s\S]+GetUnitPrimaryStat, "player"[\s\S]+primarySource/,
    'an empty CoA PrimaryStats table must fall back to the active character primary stat');
});

test('CoA Loot Decider rejects incompatible power families before scoring item level', async () => {
  const lua = await readFile(luaPath, 'utf8');
  assert.match(lua, /if not profile\.caster then[\s\S]+SPELL_POWER_STATS[\s\S]+puissance des sorts interdite/);
  assert.match(lua, /if not profile\.physical then[\s\S]+PHYSICAL_POWER_STATS[\s\S]+puissance physique interdite/);
  assert.match(lua, /local compatibilityProblem = CompatibilityProblem\(candidate\)[\s\S]+if compatibilityProblem then[\s\S]+ScoreItem\(candidate\)/);
  assert.match(lua, /Une surcharge ne peut jamais reactiver une famille interdite par CoA/);
});

test('CoA Loot Decider makes only NEED or PASS decisions and handles item-cache delay', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'START_LOOT_ROLL', 'CANCEL_LOOT_ROLL', 'CONFIRM_LOOT_ROLL',
    'GetLootRollItemLink', 'GetLootRollItemInfo', 'RollOnLoot', 'ConfirmLootRoll',
    'local ROLL_PASS = 0', 'local ROLL_NEED = 1', 'ITEM_CACHE_TIMEOUT = 3',
    'LeaveUnknownRoll', 'CHOIX MANUEL', 'NEED indisponible pour cet objet',
    'SLASH_COALOOTDECIDER1 = "/cld"'
  ]) assert.ok(lua.includes(required), `missing roll feature: ${required}`);
  assert.doesNotMatch(lua, /ROLL_GREED|ROLL_DISENCHANT/);
  assert.match(lua, /local rollType = decision\.need and ROLL_NEED or ROLL_PASS/);
  assert.match(lua, /strictSafetyVersion ~= 2[\s\S]+passUnknown = false/);
  assert.match(lua, /candidate\.equipLoc == "INVTYPE_TRINKET"[\s\S]+decision manuelle requise/);
  assert.match(lua, /HasUnscoredEffect\(candidate\.link\)[\s\S]+effet Equipe\/Utiliser non chiffrable/);
});
