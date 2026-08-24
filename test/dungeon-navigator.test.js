import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const forbiddenRetailApis = [
  'BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer', 'CombatLogGetCurrentEventInfo',
  'RegisterUnitEvent', 'AuraUtil', 'CreateFromMixins', 'Mixin(', 'Enum.',
  'ENCOUNTER_START', 'ENCOUNTER_END'
];

test('Dungeon Navigator is a strict Ascension 3.3.5 addon', async () => {
  const toc = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.toc', 'utf8');
  const lua = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## SavedVariables: CoADungeonNavigatorDB$/m);
  assert.match(toc, /^CoADungeonNavigator\.lua$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  for (const api of forbiddenRetailApis) assert.equal(lua.includes(api), false, `forbidden Retail API: ${api}`);
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
});

test('learning mode records routes without collecting player names or chat', async () => {
  const lua = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  for (const required of [
    'GetInstanceInfo()', 'GetPlayerMapPosition("player")', 'GetCurrentMapDungeonLevel',
    'GetCurrentMapAreaID', 'GetPlayerFacing', 'DEFAULT_SAMPLE_INTERVAL = 0.75',
    'DEFAULT_MIN_DISTANCE = 0.0015', 'MAX_ROUTE_POINTS = 8000',
    'activeSession.points', 'coordinatesAvailable', 'AddRoutePoint(false, "sample")',
    'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'EvaluateAutoRecording',
    'instanceType == "party"', 'lastSavedElapsed', 'ancienne session interrompue',
    'Je n\'enregistre ni le chat ni le nom des joueurs'
  ]) assert.ok(lua.includes(required), `missing route recorder feature: ${required}`);
  assert.doesNotMatch(lua, /CHAT_MSG_/);
  assert.doesNotMatch(lua, /UnitName\("party|UnitName\("raid/);
});

test('combat learning tracks group pulls, enemies, kills and boss candidates', async () => {
  const lua = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  for (const required of [
    'COMBAT_LOG_EVENT_UNFILTERED', 'COMBATLOG_OBJECT_AFFILIATION_MINE',
    'COMBATLOG_OBJECT_AFFILIATION_PARTY', 'COMBATLOG_OBJECT_AFFILIATION_RAID',
    'COMBATLOG_OBJECT_REACTION_HOSTILE', 'BeginPull()', 'EndPull("fin du combat")',
    'CaptureEnemy', 'UNIT_DIED', 'enemy.damageTaken', 'enemy.damageDone',
    'activePull.enemyCount', 'activePull.kills', 'UnitClassification("target")',
    'enemy.bossCandidate', 'PLAYER_DEAD'
  ]) assert.ok(lua.includes(required), `missing combat recorder feature: ${required}`);
});

test('route annotations and privacy-safe export are usable in game', async () => {
  const lua = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  for (const required of [
    'EXPORT_FORMAT = "COADN1"', 'BuildExport', 'SortedEnemies', 'CoADungeonNavigatorExportFrame',
    'CoADungeonNavigatorExportText', 'HighlightText()', 'Raccourci', 'Pack évité',
    'marker-" .. tostring(kind)', 'SLASH_COADUNGEONNAVIGATOR1 = "/cdn"',
    'command == "start"', 'command == "stop"', 'command == "auto"',
    'command == "mark"', 'command == "export"', 'CoADungeonNavigatorAPI'
  ]) assert.ok(lua.includes(required), `missing export/annotation feature: ${required}`);
  assert.match(lua, /table\.concat\(\{ EXPORT_FORMAT, "META"/);
  assert.match(lua, /table\.concat\(\{ "END"/);
});

test('Dungeon Navigator integrates with the shared CoA hub and remains independently accessible', async () => {
  const navigator = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  const uiManager = await readFile('addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  for (const required of [
    'CoADungeonNavigatorFrame', 'CoADungeonNavigatorRecorder', 'CoADungeonNavigatorMinimapButton',
    'function API:SetHubManaged(value)', 'minimapButton:Hide()', 'minimapButton:Show()'
  ]) assert.ok(navigator.includes(required), `missing standalone/hub feature: ${required}`);
  for (const required of [
    'CoADungeonNavigatorFrame', 'CoADungeonNavigatorRecorder', 'HubButton("Donjons"',
    'CoADungeonNavigatorAPI:Toggle()', 'CoADungeonNavigatorAPI:SetHubManaged(true)'
  ]) assert.ok(uiManager.includes(required), `UI Manager is missing Dungeon Navigator integration: ${required}`);
});
