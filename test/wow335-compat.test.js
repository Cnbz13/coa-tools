import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
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
    const luaFiles = (await readdir(`addons/${name}`, { recursive: true })).filter(file => file.endsWith('.lua'));
    const lua = (await Promise.all(luaFiles.map(file => readFile(`addons/${name}/${file}`, 'utf8')))).join('\n');
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

test('EventAlert CoA patch extends the genuine 3.3.5 addon without replacing its UI', async () => {
  const toc = await readFile('patches/EventAlertCoA/EventAlertCoA/EventAlertCoA.toc', 'utf8');
  const lua = await readFile('patches/EventAlertCoA/EventAlertCoA/EventAlertCoA.lua', 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## RequiredDeps: EventAlert$/m);
  assert.match(toc, /^EventAlertCoA\.lua$/m);
  for (const required of [
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellName', 'GetSpellLink',
    'UnitClass', 'EA_Items[spellId]', 'EA_AltItems[spellId]', 'EA_CustomItems[spellId]',
    'EventAlert_PositionFrames', 'EventAlert_DoAlert', 'frame.spellCounter',
    'COMBAT_LOG_EVENT_UNFILTERED', 'SPELL_AURA_APPLIED', 'SPELL_AURA_APPLIED_DOSE', 'SPELL_AURA_REFRESH',
    'COMBAT_TEXT_UPDATE', 'SPELL_ACTIVE', 'sourceGUID == playerGUID', 'WasDirectlyCast(spellId, spellName)',
    'IsOwnedSource(sourceGUID, sourceFlags)', 'COMBATLOG_OBJECT_AFFILIATION_MINE', 'UnitGUID("pet")',
    'coa status', 'coa learn', 'coa scan'
  ]) assert.ok(lua.includes(required), `EventAlert CoA patch is missing ${required}`);
  assert.equal(lua.includes('EA_Items[playerClassToken]'), false, 'Genuine EventAlert uses flat spell-ID tables');
  assert.equal(lua.includes('EventAlert_LoadSpellArray ='), false, 'Companion must not replace the genuine spell loader');
  for (const api of forbiddenRetailApis) assert.equal(lua.includes(api), false, `EventAlert patch contains forbidden Retail API: ${api}`);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.equal(lua.includes('CoAEventAlertFrame'), false);
  assert.equal(lua.includes('SLASH_COAEVENTALERT'), false);
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
});

test('Combat Assistant tracks owned pets, summons and guardians into persistent mob memory', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'local ownedSummons = {}', 'COMBATLOG_OBJECT_AFFILIATION_MINE',
    'SPELL_SUMMON', 'SPELL_CREATE', 'UNIT_PET', 'RegisterOwnedSummon',
    'IsOwnedActor(sourceGUID, sourceFlags, sourceName)', 'IsOwnedActor(destGUID, destFlags, destName)',
    'UnitGUID("target")', 'TARGET_FALLBACK', 'PARTY_KILL', 'UNIT_DIED'
  ]) assert.ok(lua.includes(required), `Summon tracking is missing ${required}`);
  for (const field of [
    'guid = guid', 'encounters = 0', 'deaths = 0', 'combatTime = 0',
    'damageTaken = 0', 'damageDone = 0', 'lastEncounter = nowEpoch', 'zone = CurrentZone()'
  ]) assert.ok(lua.includes(field), `Persistent memory is missing ${field}`);
  assert.match(lua, /sourceOwned[\s\S]+RememberMob\(destGUID[\s\S]+destOwned[\s\S]+RememberMob\(sourceGUID/);
});

test('Combat Assistant provides an exact Animation priority and one contextual 3.3.5 spell icon', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  const observedAnimationSpells = [
    'Animate: Skeletal Archer', 'Bone Ward', 'Command: Undead',
    'Corpse Explosion', 'Crypt Swarm', 'Foul Mandate', 'Grave March', 'Harvest Plague',
    'Lichfrost', 'March of the Dead', 'Raise: Abomination', 'Raise: Crypt Fiend',
    'Raise: Greater Skeletal Warrior', 'Razorice', 'Runic Harvest'
  ];
  for (const spell of observedAnimationSpells) assert.ok(lua.includes(`name = "${spell}"`), `Animation priority is missing ${spell}`);
  for (const required of [
    'GetSpellTexture', 'GetSpellInfo', 'GetSpellCooldown', 'IsUsableSpell',
    'IsSpellInRange', 'UnitBuff', 'UnitDebuff', 'CooldownFrameTemplate',
    'UI-ActionButton-Border', 'GetActionInfo', 'GetBindingKey',
    'CreateSpellVisual(frame, 56', 'frame:SetWidth(64)', 'engineFrame:SetScript("OnUpdate"',
    'currentRecommendation = currentQueue[1] and currentQueue[1].ready',
    'requiresSummon = 1', 'minEnemies = 3', 'settings.aoeThreshold',
    'UnitPower("player", powerType)', 'UnitPowerMax("player", powerType)'
  ]) assert.ok(lua.includes(required), `Priority/visual engine is missing ${required}`);
  assert.equal(lua.includes('secondVisual'), false, 'Compact mode must not render a second icon');
  assert.equal(lua.includes('thirdVisual'), false, 'Compact mode must not render a third icon');
  assert.doesNotMatch(lua, /FindFallbackSpell|string\.find\(Lower\(spell\.name\),\s*"command:"/);
});

test('Crypt Fiend recommendation stops after two matching summons and respects the army cap', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'CountMatchingSummons', 'NormalizedSummonName', 'desiredSummons = 2',
    'summonNames = { "Crypt Fiend" }', 'matching >= rule.desiredSummons',
    'settings.maxArmySize', 'recentLock = 3.0'
  ]) assert.ok(lua.includes(required), `Per-type summon tracking is missing ${required}`);
  assert.doesNotMatch(lua, /Raise: Crypt Fiend"[^\n]+maxSummons/);
});

test('successful casts immediately advance the recommendation and confirm buffs/debuffs', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'UNIT_SPELLCAST_SUCCEEDED', 'RecordPlayerCast(spellName)',
    'local GLOBAL_RECENT_CAST_LOCK = 1.65', 'rule.recentLock or GLOBAL_RECENT_CAST_LOCK',
    'local assumedSelfBuffs = {}', 'local assumedTargetDebuffs = {}',
    'ASSUMED_SELF_BUFF_SECONDS', 'ASSUMED_TARGET_DEBUFF_SECONDS',
    'SPELL_AURA_APPLIED', 'SPELL_AURA_REFRESH', 'SPELL_AURA_REMOVED',
    'HasSelfBuff(rule.selfBuffMissing)', 'HasTargetDebuff(rule.targetDebuffMissing)',
    'lancé récemment : proposer l\'action suivante'
  ]) assert.ok(lua.includes(required), `Cast/aura progression is missing ${required}`);
  assert.match(lua, /name = "Foul Mandate"[^\n]+selfBuffMissing = "Foul Mandate"/);
  assert.doesNotMatch(lua, /name = "Foul Mandate"[^\n]+targetDebuffMissing/);
});

test('Animation priority follows the learned level-30 generator/spender loop', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  const priority = lua.slice(lua.indexOf('local animationPriority = {'), lua.indexOf('local trackedSelfBuffs'));
  const score = (name) => Number(priority.match(new RegExp(`name = "${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"[^\\n]+score = (\\d+)`))?.[1]);
  assert.ok(score('Command: Undead') > score('Crypt Swarm'));
  assert.ok(score('Crypt Swarm') > score('Lichfrost'));
  assert.match(priority, /name = "Command: Undead"[^\n]+requiresSummon = 1[^\n]+requiresCombat = true/);
  assert.match(priority, /name = "Crypt Swarm"[^\n]+requiresTarget = true[^\n]+requiresCombat = true/);
  assert.doesNotMatch(priority, /name = "Crypt Swarm"[^\n]+mode = "AOE"/);
  assert.doesNotMatch(priority, /name = "Call of The Scourge"/);
  assert.match(priority, /name = "Harvest Plague"[^\n]+targetDebuffMissing = "Harvest Plague"/);
});

test('target profiles learn creature durability, danger and per-spell outcomes', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'BuildTargetProfile', 'UnitCreatureType("target")', 'UnitClassification("target")',
    'profile.averageDuration', 'profile.averageDanger', 'profile.shortLived', 'profile.durable',
    'spellStats = {}', 'RecordSpellOutcome', 'SPELL_', '_MISSED', 'missType == "IMMUNE"',
    'missType == "RESIST"', 'SpellExperience', 'Command: Undead',
    'GetTime() - commandAt <= 3'
  ]) assert.ok(lua.includes(required), `Adaptive target memory is missing ${required}`);
  assert.match(lua, /sameName[\s\S]+sameType[\s\S]+closeLevel/);
  assert.match(lua, /MergeSpellStats\(profile\.spells, memory\.spellStats\)/);
});

test('recommendations react to health, expected lifetime and learned immunities', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'AdaptCandidateToTarget', 'rule.minTargetHealth', 'rule.longSetup', 'rule.directDamage',
    'rule.execute', 'rule.channel', 'cible trop proche de mourir',
    'ce type de créature meurt trop vite', 'sort souvent immunisé', 'sort souvent résisté',
    'efficacité observée sur ce type de créature'
  ]) assert.ok(lua.includes(required), `Adaptive scoring is missing ${required}`);
  assert.match(lua, /name = "Blight"[^\n]+minTargetHealth = 30[^\n]+longSetup = true/);
  assert.match(lua, /name = "Ghoulify"[^\n]+directDamage = true[^\n]+execute = true/);
  assert.match(lua, /AdaptCandidateToTarget\(candidate, targetProfile, targetHealth\)/);
});

test('UI Manager provides persistent movers and never applies frames during combat', async () => {
  const lua = await readFile('addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  for (const frame of [
    'PlayerFrame', 'TargetFrame', 'FocusFrame', 'PetFrame', 'PartyMemberFrame4',
    'MinimapCluster', 'BuffFrame', 'WatchFrame', 'CastingBarFrame', 'MainMenuBar',
    'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft',
    'CoACombatAssistantFrame', 'EA_Main_Frame', 'EA_Anchor_Frame', 'CoAUIManagerPanel'
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
  assert.doesNotMatch(lua, /if not setting then\s*RestoreOriginal/, 'Unconfigured addon frames must keep their own position');
  assert.match(lua, /local function ResetFrame[\s\S]+RestoreOriginal\(name, target\)/, 'Explicit reset must still restore the captured position');
});
