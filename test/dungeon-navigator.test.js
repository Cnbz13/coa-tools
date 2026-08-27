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
  const guide = await readFile('addons/CoADungeonNavigator/CoADungeonGuide.lua', 'utf8');
  const routes = await readFile('addons/CoADungeonNavigator/CoADungeonRoutes.lua', 'utf8');
  const allLua = `${lua}\n${guide}\n${routes}`;
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## SavedVariables: CoADungeonNavigatorDB$/m);
  assert.match(toc, /^CoADungeonNavigator\.lua$/m);
  assert.match(toc, /^CoADungeonRoutes\.lua$/m);
  assert.match(toc, /^CoADungeonGuide\.lua$/m);
  for (const source of [lua, guide, routes]) {
    assert.doesNotThrow(() => luaparse.parse(source, { luaVersion: '5.1', comments: false, locations: true }));
  }
  for (const api of forbiddenRetailApis) assert.equal(allLua.includes(api), false, `forbidden Retail API: ${api}`);
  assert.doesNotMatch(allLua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
  assert.doesNotMatch(lua, /\b(?:LootSlot|RollOnLoot|ConfirmLootRoll|ConfirmLootSlot|UseContainerItem)\s*\(/,
    'the recorder must observe loot without taking items or choosing rolls');
  assert.doesNotMatch(lua, /tonumber\s*\(\s*select\s*\(/,
    'combat-log values must be truncated before tonumber to avoid treating the next value as its base');
  assert.match(lua, /local rawAmount = nil[\s\S]+rawAmount = select\(9, \.\.\.\)[\s\S]+rawAmount = select\(12, \.\.\.\)[\s\S]+return tonumber\(rawAmount\) or 0/);
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
  assert.match(lua, /if subevent == "UNIT_DIED" then[\s\S]+if not string\.find\(subevent, "_DAMAGE", 1, true\) then return end/,
    'high-volume combat log events must be discarded before flag calculations');
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

test('learning mode records observed dungeon loot for the future character-aware catalogue', async () => {
  const lua = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  for (const required of [
    'LOOT_OPENED', 'CaptureLootWindow', 'GetNumLootItems()', 'LootSlotIsItem(slot)',
    'GetLootSlotInfo(slot)', 'GetLootSlotLink(slot)', 'GetItemInfo(link or visibleName)',
    'lastKilledEnemy', 'sourceBossCandidate', 'activeSession.loot', 'activeSession.lootSeen',
    'lootCaptureUntil = Now() + 1.5', 'lootRetryElapsed >= 0.20',
    '"L", tostring(loot.t or 0)', 'objets vus'
  ]) assert.ok(lua.includes(required), `missing loot-learning feature: ${required}`);
});

test('Dungeon Navigator integrates with the shared CoA hub and remains independently accessible', async () => {
  const navigator = await readFile('addons/CoADungeonNavigator/CoADungeonNavigator.lua', 'utf8');
  const guide = await readFile('addons/CoADungeonNavigator/CoADungeonGuide.lua', 'utf8');
  const uiManager = await readFile('addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  for (const required of [
    'CoADungeonNavigatorLearningFrame', 'CoADungeonNavigatorRecorder', 'CoADungeonNavigatorMinimapButton',
    'function API:SetHubManaged(value)', 'minimapButton:Hide()', 'minimapButton:Show()'
  ]) assert.ok(navigator.includes(required), `missing standalone/hub feature: ${required}`);
  for (const required of [
    'CoADungeonNavigatorFrame', 'CoADungeonNavigatorHUD', 'function API:Toggle()', 'function API:Recalibrate()'
  ]) assert.ok(guide.includes(required), `missing live-guide integration: ${required}`);
  for (const required of [
    'CoADungeonNavigatorFrame', 'CoADungeonNavigatorHUD', 'CoADungeonNavigatorLearningFrame',
    'CoADungeonNavigatorRecorder', 'HubButton("Donjons"',
    'CoADungeonNavigatorAPI:Toggle()', 'CoADungeonNavigatorAPI:SetHubManaged(true)'
  ]) assert.ok(uiManager.includes(required), `UI Manager is missing Dungeon Navigator integration: ${required}`);
});

test('live guide provides offline routes, visual direction and safe contextual progression', async () => {
  const guide = await readFile('addons/CoADungeonNavigator/CoADungeonGuide.lua', 'utf8');
  const routeData = await readFile('addons/CoADungeonNavigator/CoADungeonRoutes.lua', 'utf8');
  const compiler = await readFile('scripts/compile-dungeon-routes.mjs', 'utf8');
  for (const required of [
    'CoADungeonRouteData.routeCount', 'SelectRoute(false)', 'FindNearestStep', 'Recalibrate',
    'RelativeAngle', 'RotateTexture', 'DirectionText', 'DistanceText', 'RouteProgress',
    'step.kind == "pack" or step.kind == "boss" or step.kind == "danger"',
    'PLAYER_REGEN_ENABLED', 'Combat terminé — on continue', 'Boss repéré',
    'TRACE DE L\'ÉTAGE ACTUEL', 'CE QUI T\'ATTEND', 'BUTIN POUR TON PERSONNAGE',
    'CoALootDeciderAPI.AnalyzeItem', 'SLASH_COADUNGEONGUIDE1 = "/cdg"'
  ]) assert.ok(guide.includes(required), `missing live guidance feature: ${required}`);
  assert.match(routeData, /\["routeCount"\] = 15/);
  for (const dungeon of [
    'blackfathom deeps', 'blackrock caverns', 'gnomeregan', 'shadowfang keep',
    'sunken temple', 'vaults of the inquisition', 'wailing caverns'
  ]) assert.ok(routeData.includes(`["${dungeon}"]`), `missing compiled route: ${dungeon}`);
  assert.doesNotMatch(routeData, /characterClass|characterLevel|startedAt|@(?:gmail|hotmail|outlook)/i);
  assert.ok(Buffer.byteLength(routeData) < 400000, 'compiled routes should stay lightweight');
  assert.match(compiler, /Contains only anonymized dungeon geometry and encounter data/);
  assert.match(compiler, /simplifyRoute/);
  assert.match(compiler, /routeScore/);
  for (const guard of [
    'heavyRefreshElapsed', 'refreshElapsed < 0.12', 'heavyRefreshElapsed >= 1.0',
    'UpdateDisplays(false)', 'refreshDetails ~= false', 'lastNearestScanAt'
  ]) assert.ok(guide.includes(guard), `missing live-guide performance guard: ${guard}`);
});

test('live dungeon guidance is a non-invasive wayfinder above the character', async () => {
  const guide = await readFile('addons/CoADungeonNavigator/CoADungeonGuide.lua', 'utf8');
  for (const required of [
    'hud:SetWidth(190)', 'hud:SetHeight(116)', 'hudArrow:SetWidth(38)',
    'hud:EnableMouse(false)', '"CENTER", "CENTER", 0, 145',
    'hudDistance:SetText(DistanceText(lastDistance))', 'UpdateWaypointToast',
    'step.kind == "boss" and 7 or 5', 'hudToast:SetWidth(264)',
    'settings.wayfinderVersion = 2', 'SetHUDLocked(false)', 'SetHUDLocked(true)',
    'command == "unlock"', 'command == "lock"', 'Flèche : ON'
  ]) assert.ok(guide.includes(required), `missing minimal wayfinder feature: ${required}`);
  assert.doesNotMatch(guide, /hud:SetWidth\(430\)|hud:SetHeight\(154\)/,
    'the old invasive rectangular HUD must not return');
});
