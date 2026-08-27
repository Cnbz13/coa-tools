import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const luaPromise = readFile('addons/CoAEssentialAssistant/CoAEssentialAssistant.lua', 'utf8');
const dataPromise = readFile('addons/CoAEssentialAssistant/CoAEssentialData.lua', 'utf8');
const tocPromise = readFile('addons/CoAEssentialAssistant/CoAEssentialAssistant.toc', 'utf8');

test('Essential Assistant covers every CoA class and specialization without a rotation', async () => {
  const [lua, data] = await Promise.all([luaPromise, dataPromise]);
  for (const className of [
    'Barbarian', 'Witch Doctor', 'Felsworn', 'Witch Hunter', 'Stormbringer',
    'Knight of Xoroth', 'Guardian', 'Templar', 'Bloodmage', 'Ranger',
    'Chronomancer', 'Necromancer', 'Pyromancer', 'Cultist', 'Starcaller',
    'Sun Cleric', 'Tinker', 'Venomancer', 'Reaper', 'Primalist', 'Runemaster'
  ]) assert.ok(data.includes(`Theme("${className}"`), `missing class theme ${className}`);
  assert.ok((data.match(/^Profile\("/gm) ?? []).length >= 70, 'all CoA specializations need an essential-mechanic profile');
  assert.doesNotMatch(lua, /SelectActionHUDEntry|BuildGuide|BuildRotation|priorityList|nextSpell/);
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
});

test('Essential Assistant detects only live high-confidence mechanics', async () => {
  const [lua, data] = await Promise.all([luaPromise, dataPromise]);
  for (const required of [
    'ScanSpellbook', 'ScanTalents', 'ResolveCharacter', 'C_ClassInfo.GetAllSpecs',
    'C_ClassInfo.GetSpecInfo', 'GetSpecializationInfo', 'UnitBuff', 'UnitDebuff',
    'AuraTooltip', 'ExplicitMechanic', 'for talentName in pairs(talents)', 'procSemantics', 'IsNoise', 'score < 80',
    'duration) > 90', 'settings.ignored[key]', 'RememberSignal', 'ReadResource'
  ]) assert.ok(lua.includes(required) || data.includes(required), `adaptive detector is missing ${required}`);
  for (const noise of ["keeper's scroll", 'well fed', 'gathering speed', 'pve mode']) {
    assert.ok(data.includes(`"${noise}"`), `noise filter is missing ${noise}`);
  }
  assert.match(lua, /if not explicit and not semantic then return nil, true end/);
  for (const performanceGuard of [
    'auraTooltipCache', 'if not exists then break end', 'coverageDirty',
    'coverageInterval=raidCount>0 and 0.90 or 0.40', 'ScheduleFullScan'
  ]) assert.ok(lua.includes(performanceGuard), `missing aura performance guard: ${performanceGuard}`);
});

test('Essential Assistant provides class-adaptive movable and personal visual modules', async () => {
  const [lua, data] = await Promise.all([luaPromise, dataPromise]);
  const layouts = new Set([...data.matchAll(/Theme\("[^"]+", "([A-Z]+)"/g)].map(match => match[1]));
  assert.ok(layouts.size >= 12, 'visual disposition must materially vary between classes');
  for (const required of [
    'CoAEssentialAssistantHUD', 'CoAEssentialResourceHUD', 'CoAEssentialTargetHUD', 'CoAEssentialCoverageHUD',
    'CoAEssentialAssistantSettings', 'CoAEssentialAssistantMinimapButton',
    'CreateMover', 'SaveModulePosition', 'settings.modules', 'settings.positions',
    'scale', 'alpha', 'GLOBAL', 'CHARACTER', 'PositionProcCards', 'ApplyTheme',
    'ScanCoverage', 'Contains(first,"party")', 'Contains(first,"raid")', 'COUVERTURE DU GROUPE', 'ABSENT DU GROUPE',
    'MÉCANISMES APPRIS', 'panelWidgets.mechanicRows', 'APERÇU 10 S', 'RÉACTIVER TOUS', 'Clic droit : ne plus afficher'
  ]) assert.ok(lua.includes(required), `custom UI is missing ${required}`);
  assert.match(lua, /if db\.minimap then minimapButton:Show\(\)/);
});

test('Essential Assistant delegates the exact Heretic HUD and suppresses competing rotation helpers', async () => {
  const lua = await luaPromise;
  for (const required of [
    'specialistDelegated', 'CoAHereticHelperAPI', 'Sang noir / soin instantané',
    'CoARotationGuideAPI.SetHUDEnabled', 'CoAStormbringerHelperAPI.SetUniversalManaged',
    'CoAPrimalistHelperAPI.SetUniversalManaged'
  ]) assert.ok(lua.includes(required), `companion policy is missing ${required}`);
});

test('Essential Assistant is strict Lua 5.1 / Ascension 3.3.5', async () => {
  const [lua, data, toc] = await Promise.all([luaPromise, dataPromise, tocPromise]);
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 1\.21\.0$/m);
  assert.match(toc, /^## SavedVariables: CoAEssentialAssistantDB$/m);
  for (const forbidden of [
    'BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer', 'CombatLogGetCurrentEventInfo',
    'RegisterUnitEvent', 'AuraUtil', 'CreateFromMixins', 'Mixin(', 'Enum.',
    'ENCOUNTER_START', 'ENCOUNTER_END'
  ]) assert.equal(lua.includes(forbidden), false, `contains Retail API ${forbidden}`);
  assert.doesNotThrow(() => luaparse.parse(`${data}\n${lua}`, { luaVersion: '5.1', comments: false, locations: true }));
});
