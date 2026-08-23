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
  assert.doesNotMatch(lua, /math\.mod\s*\(/, 'Ascension Lua does not expose math.mod; use the Lua 5.1 modulo operator');
  assert.match(lua, /math\.floor\(elapsed \/ 60\), elapsed % 60/);
  assert.match(lua, /UPDATE_INTERVAL = 0\.20/, 'recommendations must not rebuild more than five times per second');
  assert.match(lua, /TARGET_PROFILE_CACHE_SECONDS = 3/, 'historical target profiles must be cached between refreshes');
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
    'coa status', 'coa learn', 'coa scan', 'coa buffs',
    'ResolveActiveProfile', 'C_ClassInfo.GetAllSpecs', 'C_ClassInfo.GetSpecInfo',
    'GetSpecializationInfo', 'PLAYER_SPECIALIZATION_CHANGED', 'PLAYER_TALENT_UPDATE',
    'ACTIVE_TALENT_GROUP_CHANGED', 'UNIT_AURA', 'ScanActiveAuras', 'ProcessPendingAuras'
  ]) assert.ok(lua.includes(required), `EventAlert CoA patch is missing ${required}`);
  assert.equal(lua.includes('EA_Items[playerClassToken]'), false, 'Genuine EventAlert uses flat spell-ID tables');
  assert.equal(lua.includes('EventAlert_LoadSpellArray ='), false, 'Companion must not replace the genuine spell loader');
  for (const api of forbiddenRetailApis.filter(api => api !== 'GetSpecialization')) {
    assert.equal(lua.includes(api), false, `EventAlert patch contains forbidden Retail API: ${api}`);
  }
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.equal(lua.includes('CoAEventAlertFrame'), false);
  assert.equal(lua.includes('SLASH_COAEVENTALERT'), false);
  assert.match(lua, /local rawSpellId = select\(9, \.\.\.\)[\s\S]+local spellId = tonumber\(rawSpellId\)/);
  assert.doesNotMatch(lua, /tonumber\s*\(\s*select\s*\(/, 'select must be truncated before tonumber to avoid treating spellName as its base');
  assert.match(lua, /local function SafePositionFrames\(\)/);
  assert.match(lua, /for _, spellId in ipairs\(active\) do[\s\S]+frame:ClearAllPoints\(\)[\s\S]+local previous = EA_Main_Frame[\s\S]+for _, spellId in ipairs\(active\) do/,
    'EventAlert frames must all be detached before rebuilding the anchor chain');
  assert.doesNotMatch(lua, /prevFrame == eaf/, 'the compatibility positioner must not preserve EventAlert 4.3.6 cyclic-anchor logic');
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText|PetAttack)\b/);
  for (const required of [
    'EventAlertCoABuffManagerFrame', 'UICheckButtonTemplate', 'UIPanelButtonTemplate',
    'EA_Config.CoA.KnownBuffs', 'EA_Config.CoA.DisabledBuffs', 'SetLearnedBuffEnabled',
    'EA_CustomItems[spellId] = nil', 'RemoveActiveBuff(spellId)', 'IsBuffDisabled(spellId)',
    'Apprendre automatiquement les nouveaux procs'
  ]) assert.ok(lua.includes(required), `EventAlert buff manager is missing ${required}`);
  assert.match(lua, /if EA_Config\.CoA\.ManualBuffs\[spellId\] == false then return false end[\s\S]+EA_CustomItems\[spellId\] = true/,
    'manually ignored buffs must not be learned again');
  for (const required of [
    'IsLikelyUsefulProc', 'FindPlayerAura', 'UnitBuff("player", index)',
    'EventAlertCoAProcScannerTooltip', 'GameTooltipTemplate', 'SetUnitBuff',
    'PROC_MAX_DURATION = 60', 'ignoredNameFragments', 'ignoredExactNames',
    'confirmedUsefulProcNames', 'actionableTooltipFragments', 'passiveTooltipFragments', 'AutoIgnoreAura',
    'EA_Config.CoA.ManualBuffs', 'EA_Config.CoA.FilterReasons',
    'buff permanent ou passif', 'buff longue duree', 'effet passif temporaire',
    'candidat observe sans action immediate confirmee', 'sort lance manuellement',
    'EA_Config.CoA.Profiles', 'EA_Config.CoA.ActiveProfileKey', 'ProfileStorageVersion',
    'coaSpecializationCatalog', 'confirmedProcProfiles', 'TooltipReferencesLearnedSpell',
    'RecordCandidate', 'QueueAuraEvaluation', 'aura en attente de verification',
    'buff externe au personnage', 'proc repertorie pour une autre specialisation'
  ]) assert.ok(lua.includes(required), `EventAlert smart proc filter is missing ${required}`);
  assert.match(lua, /"keeper's scroll:"[\s\S]+\["heat"\] = true[\s\S]+\["ember"\] = true/);
  for (const proc of ['flamecasting', 'sageweaving', 'fired up!', 'superheated']) {
    assert.ok(lua.includes(`["${proc}"] = true`), `confirmed CoA proc is missing ${proc}`);
  }
  const coaSpecs = {
    barbarian: ['brutality', 'headhunting', 'ancestry'],
    witchdoctor: ['voodoo', 'brewing', 'shadowhunting'],
    felsworn: ['slayer', 'infernal', 'tyrant'],
    witchhunter: ['boltslinger', 'houndmaster', 'blackknight', 'inquisition'],
    stormbringer: ['lightning', 'wind', 'maelstrom'],
    knightofxoroth: ['hellfire', 'war', 'defiance'],
    guardian: ['vanguard', 'inspiration', 'gladiator'],
    templar: ['zealot', 'oathkeeper', 'crusader'],
    bloodmage: ['sanguine', 'accursed', 'eternal', 'fleshweaver'],
    ranger: ['farstrider', 'archery', 'brigand'],
    chronomancer: ['infinite', 'artificer', 'time'],
    necromancer: ['death', 'rime', 'animation'],
    pyromancer: ['flameweaving', 'incineration', 'draconic'],
    cultist: ['godblade', 'corruption', 'heretic', 'dreadnought'],
    starcaller: ['moonguard', 'moonpriest', 'sentinel', 'warden'],
    suncleric: ['piety', 'blessings', 'seraphim', 'valkyrie'],
    tinker: ['demolition', 'invention', 'mechanics'],
    venomancer: ['venom', 'stalking', 'fortitude', 'vizier'],
    reaper: ['harvest', 'soul', 'domination'],
    primalist: ['primal', 'geomancy', 'life', 'mountainking'],
    runemaster: ['runic', 'arcane', 'riftblade']
  };
  for (const [className, specs] of Object.entries(coaSpecs)) {
    assert.ok(lua.includes(`${className} = {`), `CoA specialization catalog is missing ${className}`);
    for (const spec of specs) assert.ok(lua.includes(`${spec} = true`), `CoA specialization catalog is missing ${className}/${spec}`);
  }
  assert.match(lua, /aura\.duration <= 0[\s\S]+aura\.duration > PROC_MAX_DURATION/);
  assert.match(lua, /if actionable and learnedSpellReference then return true[\s\S]+if actionable then return true[\s\S]+if passive then return false/);
  assert.doesNotMatch(lua, /aura\.duration <= 20[\s\S]+return true/, 'a short unknown aura must not be accepted without actionable evidence');
  assert.match(lua, /ApplyStaticFilterToKnownBuffs[\s\S]+FindPlayerAura\(spellId, name\)[\s\S]+IsLikelyUsefulProc\(spellId, name, activeAura\)/,
    'already-active learned buffs must be filtered during login');
  assert.match(lua, /not activeAuraIds\[spellId\]/, 'unchanged buffs must not be reclassified on every UNIT_AURA');
  assert.match(lua, /pendingElapsed < 0\.08/, 'pending aura retries must be throttled');
  assert.match(lua, /if aura\.tooltip == nil then aura\.tooltip = AuraTooltipText\(aura\.index\) end/,
    'aura tooltips must be loaded lazily after cheap filters');
});

test('GridCoA shows one center icon for actionable dispels, dangerous crowd control and snares', async () => {
  const toc = await readFile('addons/GridCoA/GridCoA.toc', 'utf8');
  const lua = await readFile('addons/GridCoA/GridCoA.lua', 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## RequiredDeps: Grid$/m);
  assert.match(toc, /^## SavedVariables: GridCoADB$/m);
  for (const required of [
    'Grid:GetModule("GridStatus")', 'GridStatus:GetModule("GridStatusAuras")',
    'Grid:GetModule("GridFrame")', 'Grid:GetModule("GridRoster")',
    '"debuff_magic"', '"debuff_curse"', '"debuff_disease"', '"debuff_poison"',
    'GetNumSpellTabs', 'GetSpellTabInfo', 'GetSpellName', 'GetSpellLink',
    'GridCoASpellScannerTooltip', 'GameTooltipTemplate',
    'ParseDispelTypes', 'classicDispelDefinitions', 'CanDispelType(debuffType, unit)',
    'settings.enable = false', 'statusmap.icon[mappedStatus] = false', 'statusmap.icon[STATUS] = true',
    'UnitAura(unit, index, "HARMFUL")',
    'AuraTooltipText', 'tooltip.SetUnitDebuff', 'ClassifyControl', 'IsDangerousControl', 'IsSnare',
    'if dispellable or learned or dangerousControl or snare then', 'colors.Control', 'colors.Snare',
    '"Controle: " .. selected.name', '"Ralentissement: " .. selected.name',
    'GridStatus:SendStatusGained', 'GridStatus:SendStatusLost', 'PARTY_MEMBERS_CHANGED',
    'RAID_ROSTER_UPDATE', 'UNIT_AURA', 'SPELLS_CHANGED', 'LEARNED_SPELL_IN_TAB',
    'COMBAT_LOG_EVENT_UNFILTERED', 'SPELL_DISPEL', 'GridCoADB.knownDispellable',
    'GridCoADB.learnedDispelSpells', 'pcall(tooltip.SetSpell, tooltip, index, book)',
    'debuff_coa_dispellable', 'SLASH_GRIDCOA1 = "/gridcoa"'
  ]) assert.ok(lua.includes(required), `GridCoA is missing ${required}`);
  for (const spellId of [4987, 527, 2782, 51886, 475, 19505]) {
    assert.match(lua, new RegExp(`id = ${spellId}`), `GridCoA is missing classic dispel ${spellId}`);
  }
  assert.doesNotMatch(lua, /statusmap\.icon\[status\] = true/);
  assert.match(lua, /local dispellable = debuffType and CanDispelType\(debuffType, unit\)/);
  assert.match(lua, /local learned = not debuffType and KnownAuraCanBeDispelled\(key, unit\)/);
  assert.match(lua, /local dangerousControl = IsDangerousControl\(unit, index, key, name\)/);
  assert.match(lua, /local snare = IsSnare\(unit, index, key, name\)/);
  assert.match(lua, /if actionable then score = score \+ 100 end[\s\S]+if dangerousControl then score = score \+ 200 end[\s\S]+if snare and not dangerousControl then score = score \+ 25 end/);
  for (const snareWord of ['snare', 'slowed', 'movement speed reduced', 'ralent']) {
    assert.ok(lua.includes(`"${snareWord}"`), `GridCoA is missing snare keyword ${snareWord}`);
  }
  for (const rootWord of ['root', 'immobil', 'enracin', 'unable to move', 'ne peut plus se déplacer']) {
    assert.ok(lua.includes(`"${rootWord}"`), `GridCoA is missing root keyword ${rootWord}`);
  }
  assert.match(lua, /UNKNOWN_CONTROL_RECHECK = 5/);
  assert.match(lua, /KNOWN_NON_CONTROL_RECHECK = 300/);
  assert.match(lua, /now - \(cached\.checkedAt or 0\) < \(cached\.retryAfter or UNKNOWN_CONTROL_RECHECK\)/);
  assert.match(lua, /FALLBACK_SCAN_INTERVAL = 8/);
  assert.doesNotMatch(lua, /CAPABILITY_RESCAN_INTERVAL/, 'the spellbook must not be scanned by a permanent timer');
  for (const api of forbiddenRetailApis) assert.equal(lua.includes(api), false, `GridCoA contains forbidden Retail API: ${api}`);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotMatch(lua, /\b(?:CastSpell|CastSpellByName|UseAction|RunMacroText)\b/);
});

test('Combat Assistant tracks owned pets, summons and guardians into persistent mob memory', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  assert.doesNotMatch(lua, /tonumber\s*\(\s*select\s*\(/, 'combat-log values must be truncated before tonumber');
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
    'Blight', 'Command: Undead', 'Corpse Explosion', 'Crypt Swarm',
    'Grave March', 'Lichfrost', 'March of the Dead', 'Razorice'
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

test('summons remain tracked for combat ownership but never become icon recommendations', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  for (const required of [
    'CountMatchingSummons', 'NormalizedSummonName', 'RegisterOwnedSummon',
    'SPELL_SUMMON', 'CountOwnedSummons', 'IsOwnedActor'
  ]) assert.ok(lua.includes(required), `Summon combat tracking is missing ${required}`);
  const priority = lua.slice(lua.indexOf('local animationPriority = {'), lua.indexOf('local trackedSelfBuffs'));
  assert.doesNotMatch(priority, /name = "(?:Raise:|Animate:|Bone Ward|Foul Mandate|Unholy Frenzy|Runic Harvest)/);
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
  assert.match(lua, /name = "Blight"[^\n]+targetDebuffMissing = "Blight"/);
});

test('the compact recommendation is strictly offensive and disappears without a hostile target', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  const priority = lua.slice(lua.indexOf('local animationPriority = {'), lua.indexOf('local trackedSelfBuffs'));
  assert.doesNotMatch(priority, /name = "(?:Raise:|Animate:|Bone Ward|Foul Mandate|Unholy Frenzy|Runic Harvest|Sacrifice Undead)/);
  for (const line of priority.split('\n').filter(line => line.includes('{ name ='))) assert.match(line, /requiresTarget = true/);
  for (const required of [
    'TargetIsValid()', 'currentRecommendation = currentQueue[1] and currentQueue[1].ready',
    'CoACombatAssistantDB.visible and currentRecommendation', 'frame:Hide()',
    'lastCasts[SpellKey(rule.name)]'
  ]) assert.ok(lua.includes(required), `Offensive-only display is missing ${required}`);
});

test('Animation priority follows the learned level-30 generator/spender loop', async () => {
  const lua = await readFile('addons/CoACombatAssistant/CoACombatAssistant.lua', 'utf8');
  const priority = lua.slice(lua.indexOf('local animationPriority = {'), lua.indexOf('local trackedSelfBuffs'));
  const score = (name) => Number(priority.match(new RegExp(`name = "${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"[^\\n]+score = (\\d+)`))?.[1]);
  assert.ok(score('Command: Undead') > score('Crypt Swarm'));
  assert.ok(score('Crypt Swarm') > score('Lichfrost'));
  assert.match(priority, /name = "Command: Undead"[^\n]+requiresSummon = 1[^\n]+minRunic = 20/);
  assert.match(priority, /name = "Crypt Swarm"[^\n]+requiresTarget = true[^\n]+directDamage = true/);
  assert.doesNotMatch(priority, /name = "Crypt Swarm"[^\n]+mode = "AOE"/);
  assert.doesNotMatch(priority, /name = "Call of The Scourge"/);
  assert.match(priority, /name = "Blight"[^\n]+openingOnly = true/);
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
    'rule.channel', 'cible trop proche de mourir',
    'ce type de créature meurt trop vite', 'sort souvent immunisé', 'sort souvent résisté',
    'efficacité observée sur ce type de créature'
  ]) assert.ok(lua.includes(required), `Adaptive scoring is missing ${required}`);
  assert.match(lua, /name = "Blight"[^\n]+minTargetHealth = 70[^\n]+openingOnly = true[^\n]+longSetup = true/);
  assert.match(lua, /rule\.openingOnly and phase == "established"/);
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

test('UI Manager provides a persistent draggable minimap menu button', async () => {
  const lua = await readFile('addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  for (const required of [
    'CoAUIManagerMinimapButton', 'INV_Misc_Gear_01', 'BuildMinimapButton',
    'CoAUIManagerDB.minimap.angle', 'CoAUIManagerDB.minimap.hidden',
    'RegisterForClicks("LeftButtonUp", "RightButtonUp")', 'RegisterForDrag("LeftButton")',
    'GetCursorPosition()', 'PositionMinimapButton', 'TogglePanel',
    'command == "minimap"', '/cui minimap show|hide|reset'
  ]) assert.ok(lua.includes(required), `UI Manager minimap button is missing ${required}`);
  assert.match(lua, /if button == "RightButton" then[\s\S]+LockMovers\(\)[\s\S]+ShowMovers\(\)/,
    'right-click must toggle UI movers');
  assert.match(lua, /math\.cos\(angle\) \* radius, math\.sin\(angle\) \* radius/,
    'the button must remain anchored to the minimap ring');
});
