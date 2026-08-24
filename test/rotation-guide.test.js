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
    'Avant le combat :', 'Avant le pull :', 'CoARotationGuideFrame',
    'CoARotationGuideMinimapButton', 'CoARotationGuideAPI:SetHubManaged',
    'SLASH_COAROTATIONGUIDE1 = "/rotation"', 'buttons.sources',
    'viewMode == "SOURCES"', 'Banque hors ligne', 'Pourquoi ça marche',
    'série de questions', 'on suit une priorité, pas une macro apprise par cœur',
    'local PAGE_SIZE = 5', 'local MAX_ENTRIES = 15', 'buttons.previous', 'buttons.next',
    'buttons.learn', 'buttons.rotation', 'buttons.situations', 'buttons.updates'
  ]) assert.ok(lua.includes(required), `UI is missing ${required}`);
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
  assert.doesNotMatch(lua, /BackdropTemplate|SetShown|SetSize|C_Timer|CombatLogGetCurrentEventInfo|RegisterUnitEvent|AuraUtil|Enum\./);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
});

test('Rotation Guide teaches each specialization from fundamentals to situational play', async () => {
  const [lua, data] = await Promise.all([luaPromise, dataPromise]);
  for (const required of [
    'LevelChapter', 'On pose les bases', 'Tu découvres vraiment la spécialisation',
    'La boucle complète est presque là', 'Tu rends le jeu plus propre', 'Tu peux maintenant affiner',
    'Voilà ce que tu joues vraiment', 'Le moteur de ton gameplay',
    'À quoi ressemble un combat', 'Ce que tu peux travailler maintenant', 'Le conseil que je te donnerais',
    'Quand ta ressource change', 'Une cible ou plusieurs ?', 'Quand il faut casser la rotation',
    'viewMode == "LEARN"', 'viewMode == "SITUATIONS"', 'viewMode ~= "ROTATION"'
  ]) assert.ok(lua.includes(required), `learning journey is missing ${required}`);
  for (const required of [
    'Tu joues un chef d\'armee', 'Tu es un soigneur de melee',
    'La Glory donne le rythme', 'Monte a 20 Solar Power pour Dawn',
    'situational = { "Eldritch Mending", "Void Shield" }'
  ]) assert.ok(data.includes(required), `curated teaching is missing ${required}`);
  assert.ok(lua.includes('NameInList(curated.situational, spell.name)'), 'situational spells must leave the fixed rotation');
});

test('Rotation Guide uses a warmer navigable card layout', async () => {
  const lua = await luaPromise;
  for (const required of [
    'Ton guide de specialisation', 'On va prendre le temps de comprendre ton personnage',
    'RoleColor', 'guideFrame.planBox:SetBackdropBorderColor',
    'row.accent:SetVertexColor', 'COMPRENDRE', 'ROTATION', 'SITUATIONS', 'ACTUS', 'SOURCES',
    'Choisis ton contexte ; le guide s\'adapte tout de suite.',
    'guideFrame:SetHeight(720)', 'GameTooltip.SetSpellBookItem'
  ]) assert.ok(lua.includes(required), `visual redesign is missing ${required}`);
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
    'entry.explanation = "Pourquoi ça marche', 'a.curatedRank < b.curatedRank',
    'Et juste après :', 'REPÈRE PRUDENT', 'guide.plan'
  ]) assert.ok(lua.includes(required), `explanation engine is missing ${required}`);
});

test('Rotation Guide filters the manager feed and warns once in game', async () => {
  const [lua, updates, toc] = await Promise.all([
    luaPromise,
    readFile('addons/CoARotationGuide/CoARotationUpdates.lua', 'utf8'),
    readFile('addons/CoARotationGuide/CoARotationGuide.toc', 'utf8')
  ]);
  for (const required of [
    'RelevantUpdates', 'UpdateMatchesCharacter', 'UpdateAcknowledgements',
    'PromptForRelevantUpdates', 'CoARotationGuideUpdatePopup', 'Le jeu a changé depuis ton dernier passage',
    'CoAMessageCenter:AddMessage', 'viewMode == "UPDATES"', '/rotation actus'
  ]) assert.ok(lua.includes(required), `in-game update alert is missing ${required}`);
  assert.match(updates, /CoARotationUpdateFeed = \{/);
  assert.match(toc, /^CoARotationUpdates\.lua\r?\nCoARotationData\.lua\r?\nCoARotationGuide\.lua$/m);
});

test('Rotation Guide release metadata targets Ascension 3.3.5', async () => {
  const toc = await readFile('addons/CoARotationGuide/CoARotationGuide.toc', 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 1\.15\.1$/m);
  assert.match(toc, /^## SavedVariables: CoARotationGuideDB$/m);
  assert.match(toc, /^CoARotationUpdates\.lua\r?\nCoARotationData\.lua\r?\nCoARotationGuide\.lua$/m);
});
