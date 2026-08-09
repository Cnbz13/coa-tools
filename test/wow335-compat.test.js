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

test('Combat Assistant uses the 3.3.5 spellbook and never casts automatically', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellName', 'UnitLevel', 'UnitClass',
    'GetNumTalentTabs', 'GetTalentTabInfo', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED',
    'COMBAT_LOG_EVENT_UNFILTERED', 'CoACombatAssistantDB.mobs', 'Command: Undead',
    'March of the Dead', 'SLASH_COACOMBATASSISTANT1 = "/cca"'
  ]) assert.ok(lua.includes(required), `Combat Assistant is missing ${required}`);
  for (const command of ['status', 'scan', 'unlock', 'lock', 'memory', 'debug', 'aoe']) assert.match(lua, new RegExp(`command == "${command}"`));
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
});

test('Combat Assistant tracks owned pets, summons and guardians into persistent mob memory', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'local ownedSummons = {}', 'COMBATLOG_OBJECT_AFFILIATION_MINE',
    'SPELL_SUMMON', 'SPELL_CREATE', 'UNIT_PET', 'RegisterOwnedSummon',
    'IsOwnedActor(sourceGUID, sourceFlags)', 'IsOwnedActor(destGUID, destFlags)',
    'UnitGUID("target")', 'TARGET_FALLBACK', 'PARTY_KILL', 'UNIT_DIED'
  ]) assert.ok(lua.includes(required), `Summon tracking is missing ${required}`);
  for (const field of [
    'guid = guid', 'encounters = 0', 'deaths = 0', 'combatTime = 0',
    'damageTaken = 0', 'damageDone = 0', 'lastEncounter = nowEpoch', 'zone = CurrentZone()'
  ]) assert.ok(lua.includes(field), `Persistent memory is missing ${field}`);
  assert.match(lua, /sourceOwned[\s\S]+RememberMob\(destGUID[\s\S]+destOwned[\s\S]+RememberMob\(sourceGUID/);
});

test('Combat Assistant provides an exact Animation priority queue and 3.3.5 spell visuals', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  const observedAnimationSpells = [
    'Animate: Skeletal Archer', 'Bone Ward', 'Call of The Scourge', 'Command: Undead',
    'Corpse Explosion', 'Crypt Swarm', 'Foul Mandate', 'Grave March', 'Harvest Plague',
    'Lichfrost', 'March of the Dead', 'Raise: Abomination', 'Raise: Crypt Fiend',
    'Raise: Greater Skeletal Warrior', 'Razorice', 'Runic Harvest'
  ];
  for (const spell of observedAnimationSpells) assert.ok(lua.includes(`name = "${spell}"`), `Animation priority is missing ${spell}`);
  for (const required of [
    'GetSpellTexture', 'GetSpellInfo', 'GetSpellCooldown', 'IsUsableSpell',
    'IsSpellInRange', 'UnitBuff', 'UnitDebuff', 'CooldownFrameTemplate',
    'UI-ActionButton-Border', 'GetActionInfo', 'GetBindingKey',
    'currentQueue[2]', 'currentQueue[3]', 'requiresSummon = 1',
    'minEnemies = 3', 'settings.aoeThreshold'
  ]) assert.ok(lua.includes(required), `Priority/visual engine is missing ${required}`);
  assert.doesNotMatch(lua, /FindFallbackSpell|string\.find\(Lower\(spell\.name\),\s*"command:"/);
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
