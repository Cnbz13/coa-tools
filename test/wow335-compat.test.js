import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const addons = ['CoACombatAssistant', 'CoAUIManager'];
const forbiddenRetailApis = [
  'BackdropTemplate', 'SetShown', 'SetSize', 'SetObeyStepOnDrag', 'C_Timer',
  'GetSpecialization', 'CombatLogGetCurrentEventInfo', 'RegisterUnitEvent',
  'AuraUtil', 'CreateFromMixins', 'Mixin(', 'Enum.', 'ENCOUNTER_START', 'ENCOUNTER_END'
];

for (const name of addons) {
  test(`${name} targets Ascension 3.3.5 and parses as Lua 5.1`, async () => {
    const toc = await readFile(`addons/${name}/${name}.toc`, 'utf8');
    const lua = await readFile(`addons/${name}/${name}.lua`, 'utf8');
    assert.match(toc, /^## Interface: 30300$/m);
    assert.match(toc, /^## SavedVariables: \S+$/m);
    for (const api of forbiddenRetailApis) assert.equal(lua.includes(api), false, `${name} contains forbidden Retail API: ${api}`);
    assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  });
}

test('Combat Assistant uses the 3.3.5 spellbook and combat-log fallback without casting', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellName', 'UnitLevel', 'UnitClass',
    'GetNumTalentTabs', 'GetTalentTabInfo', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED',
    'COMBAT_LOG_EVENT_UNFILTERED', 'CoACombatAssistantDB.mobs', 'Command: Animates',
    'March of the Dead', 'SLASH_COACOMBATASSISTANT1 = "/cca"'
  ]) assert.ok(lua.includes(required), `Combat Assistant is missing ${required}`);
  for (const command of ['status', 'scan', 'unlock', 'lock', 'memory']) assert.match(lua, new RegExp(`command == "${command}"`));
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
});

test('UI Manager provides persistent movers and never applies frames during combat', async () => {
  const lua = await readFile('addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  for (const frame of [
    'PlayerFrame', 'TargetFrame', 'FocusFrame', 'PetFrame', 'PartyMemberFrame4',
    'MinimapCluster', 'BuffFrame', 'WatchFrame', 'CastingBarFrame', 'MainMenuBar',
    'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft',
    'CoACombatAssistantFrame', 'CoAUIManagerPanel'
  ]) assert.ok(lua.includes(`"${frame}"`), `UI Manager is missing mover target ${frame}`);
  for (const required of [
    'profiles.global', 'profiles.characters', 'characterModes', 'customFrames',
    'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA',
    'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'InCombatLockdown',
    'SLASH_COAUI1 = "/cui"'
  ]) assert.ok(lua.includes(required), `UI Manager is missing ${required}`);
  for (const command of ['unlock', 'lock', 'profile', 'add', 'select', 'scale', 'alpha', 'size', 'reset']) {
    assert.match(lua, new RegExp(`command == "${command}"`));
  }
});
