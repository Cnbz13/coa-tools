import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const luaPromise = readFile('addons/CoARotationGuide/CoARotationGuide.lua', 'utf8');
const dataPromise = readFile('addons/CoARotationGuide/CoARotationData.lua', 'utf8');

test('Rotation Guide embeds all CoA class/spec profiles and dated sources', async () => {
  const data = await dataPromise;
  for (const className of [
    'Barbarian', 'Witch Doctor', 'Felsworn', 'Witch Hunter', 'Stormbringer',
    'Knight of Xoroth', 'Guardian', 'Templar', 'Bloodmage', 'Ranger',
    'Chronomancer', 'Necromancer', 'Pyromancer', 'Cultist', 'Starcaller',
    'Sun Cleric', 'Tinker', 'Venomancer', 'Reaper', 'Primalist', 'Runemaster'
  ]) assert.ok(data.includes(`Add("${className}"`), `missing CoA class ${className}`);
  assert.ok((data.match(/^Add\("/gm) ?? []).length >= 69, 'offline bank must cover the full CoA specialization roster');
  for (const source of ['ascension.gg/en/changelog/4', 'coabuildhub.com/', 'github.com/srhinos/coa-datamine']) {
    assert.ok(data.includes(source), `missing source ${source}`);
  }
  assert.match(data, /schema = 2/);
  assert.match(data, /sourceDate = "2026-08-24"/);
  assert.match(data, /talentPatch = "2026-08-19"/);
  assert.match(data, /officialPatchThrough = "2026-08-22"/);
});

test('Rotation Guide filters sourced priorities through the learned spellbook', async () => {
  const [lua, data] = await Promise.all([luaPromise, dataPromise]);
  for (const required of [
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellName', 'IsPassiveSpell',
    'CoARotationGuideScannerTooltip', 'SetSpellBookItem', 'ScanSpellbook',
    'GetNumTalentTabs', 'GetNumTalents', 'GetTalentInfo', 'ScanTalents',
    'C_ClassInfo.GetAllSpecs', 'C_ClassInfo.GetSpecInfo', 'GetSpecializationInfo',
    'UnitLevel("player")', 'ResolveActiveSpecialization', 'TalentPromotion',
    'if spellbook[Lower(name)]', 'if not spell or spell.passive',
    'CoARotationGuideDB.context', 'CoARotationGuideDB.content'
  ]) assert.ok(lua.includes(required), `adaptive engine is missing ${required}`);
  for (const profile of ['Guardian:Gladiator', 'Necromancer:Animation', 'Cultist:Heretic', 'Sun Cleric:Valkyrie']) {
    assert.ok(data.includes(`["${profile}"]`), `curated profile missing ${profile}`);
  }
  assert.match(data, /"Ram", "Centurion Strike", "Reprisal", "Pulverize"/);
  assert.match(data, /"Harvest Plague"[\s\S]+"Command: Undead"[\s\S]+"Blight"/);
  assert.match(data, /"Malevolence", "Blade of the Empire", "Hammer of Twilight"/);
  assert.match(data, /"Dawn", "Paragon", "Dawnfall"/);
});

test('Rotation Guide keeps preparation separate and never automates gameplay', async () => {
  const lua = await luaPromise;
  for (const required of [
    'Preparation separee', 'Avant le pull, pas au milieu du cycle', 'CoARotationGuideFrame',
    'CoARotationGuideMinimapButton', 'CoARotationGuideAPI:SetHubManaged',
    'SLASH_COAROTATIONGUIDE1 = "/rotation"', 'buttons.sources',
    'viewMode == "SOURCES"', 'Banque hors ligne', 'Pourquoi ici ?',
    'Lis de haut en bas', 'la liste est une priorite, pas une macro figee',
    'local PAGE_SIZE = 5', 'local MAX_ENTRIES = 15', 'buttons.previous', 'buttons.next'
  ]) assert.ok(lua.includes(required), `UI is missing ${required}`);
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
  assert.doesNotMatch(lua, /BackdropTemplate|SetShown|SetSize|C_Timer|CombatLogGetCurrentEventInfo|RegisterUnitEvent|AuraUtil|Enum\./);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
});

test('Rotation Guide explains sourced transitions in familiar and explicit language', async () => {
  const [lua, data] = await Promise.all([luaPromise, dataPromise]);
  assert.doesNotThrow(() => luaparse.parse(data, { luaVersion: '5.1', comments: false, locations: true }));
  for (const phrase of [
    'Tu fermes la distance tout de suite',
    'Le Tomb King doit etre actif avant de commander',
    'Avec trois cibles ou plus, Entropic Slam passe devant',
    'Vers 7 a 10 stacks de Dawn'
  ]) assert.ok(data.includes(phrase), `missing explicit sourced explanation: ${phrase}`);
  for (const required of [
    'CuratedExplanation', 'GenericWhy', 'GenericAfter', 'ExplainEntry',
    'entry.explanation = "Pourquoi ici ?', 'a.curatedRank < b.curatedRank',
    'A faire :', 'DEDUIT DU TOOLTIP', 'guide.plan'
  ]) assert.ok(lua.includes(required), `explanation engine is missing ${required}`);
});

test('Rotation Guide release metadata targets Ascension 3.3.5', async () => {
  const toc = await readFile('addons/CoARotationGuide/CoARotationGuide.toc', 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 1\.12\.0$/m);
  assert.match(toc, /^## SavedVariables: CoARotationGuideDB$/m);
  assert.match(toc, /^CoARotationData\.lua\r?\nCoARotationGuide\.lua$/m);
});
