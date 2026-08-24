import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const tocPath = 'addons/CoALootDecider/CoALootDecider.toc';
const luaPath = 'addons/CoALootDecider/CoALootDecider.lua';
const profilesPath = 'addons/CoALootDecider/CoALootProfiles.lua';
const talentDataPath = 'addons/CoALootDecider/CoALootTalentData.lua';
const adaptationPath = 'addons/CoALootDecider/CoALootAdaptation.lua';
const advisorPath = 'addons/CoALootDecider/CoALootAdvisor.lua';

test('CoA Loot Decider targets Ascension 3.3.5 and parses as Lua 5.1', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  const profiles = await readFile(profilesPath, 'utf8');
  const talentData = await readFile(talentDataPath, 'utf8');
  const adaptation = await readFile(adaptationPath, 'utf8');
  const advisor = await readFile(advisorPath, 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## SavedVariables: CoALootDeciderDB$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotThrow(() => luaparse.parse(profiles, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotThrow(() => luaparse.parse(talentData, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotThrow(() => luaparse.parse(adaptation, { luaVersion: '5.1', comments: false, locations: true }));
  assert.doesNotThrow(() => luaparse.parse(advisor, { luaVersion: '5.1', comments: false, locations: true }));
  assert.match(toc, /CoALootTalentData\.lua\s+CoALootAdaptation\.lua\s+CoALootProfiles\.lua\s+CoALootDecider\.lua/,
    'talent data, adaptation and profiles must load before the decision engine');

  for (const retailApi of [
    'BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer',
    'C_Item', 'Enum.', 'CreateFromMixins', 'RegisterUnitEvent'
  ]) {
    assert.equal(lua.includes(retailApi), false, `forbidden Retail API in engine: ${retailApi}`);
    assert.equal(adaptation.includes(retailApi), false, `forbidden Retail API in adaptive engine: ${retailApi}`);
    assert.equal(advisor.includes(retailApi), false, `forbidden Retail API in advisor: ${retailApi}`);
  }
});

test('CoA Loot Decider adapts all 70 profiles to live CoA talents, level and spellbook', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  const profiles = await readFile(profilesPath, 'utf8');
  const talentData = await readFile(talentDataPath, 'utf8');
  const adaptation = await readFile(adaptationPath, 'utf8');
  const generator = await readFile('scripts/generate-loot-talent-data.mjs', 'utf8');
  const nodeRows = talentData.match(/^\s*\{ id=\d+, level=\d+, tab="[^"]+", name=/gm) ?? [];
  const classRows = talentData.match(/^\s*\["[^"]+"\] = \{ classID=\d+, sourceClass=/gm) ?? [];
  const profileSection = talentData.match(/profileTabs = \{([\s\S]*?)\n\s*\},\n\s*classes = \{/m)?.[1] ?? '';
  const profileTabs = profileSection.match(/^\s*\["[^"]+:[^"]+"\] = "[^"]+"/gm) ?? [];
  const weightRows = profiles.match(/^\s*\["[^"]+:[^"]+"\]\s*=\s*\{[^\n]+\},?$/gm) ?? [];

  assert.match(toc, /^## Version: 1\.15\.0$/m);
  assert.equal(nodeRows.length, 3618, 'the pinned live CoA dataset must remain complete');
  assert.equal(classRows.length, 21, 'every CoA class must have an adaptive talent dataset');
  assert.equal(profileTabs.length, 70, 'every shipped loot profile must resolve to a live talent tab');
  assert.equal(weightRows.filter(row => /\b(?:str|agi|int|spi|ap|sp|crit|sta)=/.test(row)).length, 70);

  for (const required of [
    'C_CharacterAdvancement.GetTalentRankByID',
    'C_CharacterAdvancement.GetTalentRankBySpellID',
    'SpellbookCount', 'ApplyLevelBand', 'SavedFallback', 'SaveSnapshot',
    'selectedSignalCount', 'weaponSignals', 'MAX_SIGNAL_BONUS',
    'GetAdaptiveBuild', 'PrintAdaptiveDetails', 'SPELLS_CHANGED', 'PLAYER_LEVEL_UP'
  ]) assert.ok(adaptation.includes(required) || lua.includes(required), `missing adaptive feature: ${required}`);

  assert.match(generator, /Expected 70 loot profiles/,
    'generation must fail rather than silently dropping a specialization');
  assert.match(generator, /No live talent tab for/,
    'generation must fail when a profile no longer maps to the current CoA trees');
  assert.match(talentData, /source = "srhinos\/coa-datamine@8c051d20a1e999839a7783651c1c9d1cd3fbd477"/);
  assert.match(talentData, /signalNodeCount = 580/,
    'the conservative gear-signal snapshot must only change after a reviewed regeneration');
  assert.match(talentData, /name="Power of Yogg-Saron"[^\n]+signals=\{ crit=2 \}/,
    'Heretic level-50 crit scaling must be detected from the live talent text');
  assert.match(talentData, /name="Void Strikes"[^\n]+signals=\{ defense=2 \}/,
    'Dreadnought defense-rating scaling must be detected');
  assert.match(talentData, /name="Libram of Fervor"[^\n]+signals=\{ agi=2, int=2 \}/,
    'hybrid primary-stat conversion must influence the active build');
  assert.match(talentData, /name="Brutal Spirit"[^\n]+signals=\{\}/,
    'CoA mechanics named Spirit must not be mistaken for the equipment stat');
  assert.match(adaptation, /if key and \(weights\[key\] or 0\) > 0/,
    'talents must never reactivate a stat forbidden by the specialization profile');
  assert.match(adaptation, /customWeights\[key\] ~= nil/,
    'explicit user weights must remain authoritative');
  assert.match(lua, /weaponRule\.preferDualWield[\s\S]+weaponRule\.preferShield/,
    'weapon talents must affect one-hand, off-hand and shield comparison scores');
});

test('CoA Loot Decider ships data-driven profiles for every current CoA specialization', async () => {
  const lua = await readFile(luaPath, 'utf8');
  const profiles = await readFile(profilesPath, 'utf8');
  const profileRows = profiles.match(/^\s*\["[^"]+:[^"]+"\]\s*=\s*\{[^\n]+\},?$/gm) ?? [];

  // 70 weight rows plus 5 current-name aliases and 5 weapon rules.
  assert.equal(profileRows.filter((row) => /\b(?:str|agi|int|spi|ap|sp|crit|sta)=/.test(row)).length, 70);
  for (const required of [
    '["Cultist:Heretic"] = { str=1, int=0.104, ap=1, sp=0.4, crit=3, haste=0.4',
    '["Venomancer:Venom"] = "Venomancer:Rotweaver"',
    '["Primalist:Life"] = "Primalist:Grovekeeper"',
    '["Runemaster:Runic"] = "Runemaster:Engravement"',
    'sourceDate = "2026-08-22"', 'PublicWeights', 'FindPublicPreset',
    'PROFILE_STAT_KEYS', 'weightSource'
  ]) assert.ok(profiles.includes(required) || lua.includes(required), `missing profile feature: ${required}`);
  assert.match(lua, /statProfileVersion ~= 1[\s\S]+itemLevelWeight = 0/,
    'arbitrary item-level points must not override sourced EP weights');
});

test('Heretic and weapon-dependent profiles account for weapon speed without Retail APIs', async () => {
  const lua = await readFile(luaPath, 'utf8');
  const profiles = await readFile(profilesPath, 'utf8');
  assert.match(profiles, /\["Cultist:Heretic"\][\s\S]+preferTwoHand = true, speed = "slow"/);
  assert.match(profiles, /\["Runemaster:Engravement"\][\s\S]+speed = "fast"/);
  assert.match(lua, /ReadWeaponSpeed[\s\S]+\[Ss\]peed[\s\S]+\[Vv\]itesse/);
  assert.match(lua, /weaponRule\.speed == "slow"[\s\S]+weaponRule\.speed == "fast"/);
  assert.match(lua, /presetKey == "Cultist:Heretic" and playerLevel < 50[\s\S]+effectivePreset\.crit = 0\.8/,
    'the level-50 crit-to-AP passive must not affect low-level Heretics');
  assert.match(lua, /effectivePreset\.arp[\s\S]+effectivePreset\.expertise/,
    'hybrid physical profiles must not reject their own armor penetration or expertise');
  assert.equal(lua.includes('C_TooltipInfo'), false);
});

test('CoA Loot Decider uses the exact CoA specialization catalog and compares the correct equipment slots', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'GetInventoryItemLink("player", slot)', 'GetItemStats', 'GetItemInfo',
    'INVTYPE_FINGER = { 11, 12 }', 'INVTYPE_TRINKET = { 13, 14 }',
    'INVTYPE_2HWEAPON = { 16, 17 }', 'ComparisonFor', 'CompatibilityProblem',
    'CoALootDeciderDB.threshold', 'CoALootDeciderDB.customWeights',
    'CoALootDeciderDB.thresholdsBySpec', 'DEFAULT_CLASS_THRESHOLDS',
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
  assert.match(lua, /PYROMANCER = 10[\s\S]+ThresholdKey[\s\S]+ActiveThreshold/,
    'Pyromancer must inherit a stricter class threshold with per-spec overrides');
  assert.match(lua, /thresholdPolicyVersion ~= 3[\s\S]+CoALootDeciderDB\.threshold = 5/,
    'all non-Pyromancer profiles must migrate from 1% to the safer 5% default');
  assert.match(lua, /thresholdsBySpec\[key\] = threshold[\s\S]+les autres specialisations ne changent pas/,
    'the threshold command must only change the active specialization');
});

test('CoA Loot Decider rejects incompatible power families before scoring item level', async () => {
  const lua = await readFile(luaPath, 'utf8');
  assert.match(lua, /if not profile\.caster then[\s\S]+SPELL_POWER_STATS[\s\S]+puissance des sorts interdite/);
  assert.match(lua, /if not profile\.physical then[\s\S]+PHYSICAL_POWER_STATS[\s\S]+puissance physique interdite/);
  assert.match(lua, /local compatibilityProblem = CompatibilityProblem\(candidate\)[\s\S]+if compatibilityProblem then[\s\S]+ScoreItem\(candidate\)/);
  assert.match(lua, /Une surcharge ne peut jamais reactiver une famille interdite par CoA/);
});

test('CoA Loot Decider uses NEED/PASS with a GREED fallback only for locked chests', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'START_LOOT_ROLL', 'CANCEL_LOOT_ROLL', 'CONFIRM_LOOT_ROLL',
    'GetLootRollItemLink', 'GetLootRollItemInfo', 'RollOnLoot', 'ConfirmLootRoll',
    'local ROLL_PASS = 0', 'local ROLL_NEED = 1', 'local ROLL_GREED = 2', 'ITEM_CACHE_TIMEOUT = 3',
    'LeaveUnknownRoll', 'CHOIX MANUEL', 'NEED indisponible pour cet objet',
    'SLASH_COALOOTDECIDER1 = "/cld"'
  ]) assert.ok(lua.includes(required), `missing roll feature: ${required}`);
  assert.doesNotMatch(lua, /ROLL_DISENCHANT/);
  assert.match(lua, /if decision\.lockedChest and decision\.need and not canNeed and canGreed then[\s\S]+rollType = ROLL_GREED/);
  assert.match(lua, /local _, _, _, _, _, canNeed, canGreed = GetLootRollItemInfo\(rollID\)/);
  assert.match(lua, /if not rollType then rollType = decision\.need and ROLL_NEED or ROLL_PASS end/);
  assert.match(lua, /strictSafetyVersion ~= 2[\s\S]+passUnknown = false/);
  assert.match(lua, /candidate\.equipLoc == "INVTYPE_TRINKET"[\s\S]+verification manuelle recommandee/);
  assert.match(lua, /HasUnscoredEffect\(candidate\.link\)[\s\S]+effet Equipe\/Utiliser non chiffrable/);
  assert.match(lua, /analysis and analysis\.manual[\s\S]+return nil, analysis\.reason/,
    'unknown effects must never trigger an automatic roll');
});

test('locked loot chests are always rolled instead of being discarded as non-equippable', async () => {
  const lua = await readFile(luaPath, 'utf8');
  const advisor = await readFile(advisorPath, 'utf8');
  for (const required of [
    'CoALootDeciderDB.needLockedChests', 'CoALootDeciderLockedChestScanner',
    'LOCKED_CHEST_CONTAINER_WORDS', 'LOCKED_CHEST_LOCK_WORDS',
    '"locked"', '"lockbox"', '"coffre"', '"verrou"', '"crochetage"',
    'IsLockedChest(candidate)', 'lockedChest = true',
    'coffre verrouillé : NEED', 'command == "chests" or command == "coffres"',
    'decision.rollDecision = "GREED"'
  ]) assert.ok(lua.includes(required), `missing locked-chest loot policy: ${required}`);
  assert.match(lua, /if IsLockedChest\(candidate\) then[\s\S]+if not EQUIP_SLOTS\[candidate\.equipLoc\] then/,
    'locked chests must be recognized before the ordinary non-equippable PASS rule');
  assert.match(lua, /AddHistory\(rollID, decision, automatic\)/,
    'the NEED/GREED chest decision must remain visible in history');
  for (const required of ['analysis.lockedChest', 'COFFRE', 'À RÉCUPÉRER', 'CUPIDITÉ']) {
    assert.ok(advisor.includes(required), `the advisor must explain locked chests: ${required}`);
  }
});

test('CoA Loot Advisor compares bags, bank, merchants, loot and universal item tooltips', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  const advisor = await readFile(advisorPath, 'utf8');
  assert.match(toc, /CoALootDecider\.lua\s+CoALootAdvisor\.lua/,
    'the visual advisor must load after the scoring engine');
  for (const required of [
    'CoALootDeciderAPI', 'AnalyzeItem', 'currentStats',
    'GetContainerItemLink', 'GetContainerNumSlots', 'BANKFRAME_OPENED',
    'GetMerchantNumItems', 'GetMerchantItemLink', 'MERCHANT_SHOW',
    'GetLootSlotLink', 'LOOT_OPENED', 'OnTooltipSetItem',
    'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip1',
    'AdiBags_UpdateButton', 'AceEvent-3.0',
    'CoALootAdvisor_Toggle', 'candidat(s) utile(s)',
    'AMELIORATION', 'VERIFICATION MANUELLE', 'Confiance :'
  ]) assert.ok(lua.includes(required) || advisor.includes(required), `missing universal advisor feature: ${required}`);
  assert.match(advisor, /for merchantIndex = 1, \(tonumber\(GetMerchantNumItems\(\)\) or 0\)/,
    'the comparison window must inspect every merchant page, not only visible buttons');
  for (const verdict of ['AMELIORATION', 'GAIN SOUS LE SEUIL', 'MOINS BON', 'EQUIVALENT']) {
    assert.ok(advisor.includes(verdict), `missing visual verdict: ${verdict}`);
  }
  assert.match(advisor, /local positive = analysis\.need/,
    'visual advice must derive its verdict from the strict upgrade decision');
  assert.match(advisor, /MerchantNextPageButton:HookScript\("OnClick", RequestRefresh\)/,
    'merchant overlays must refresh when browsing NPC pages');
  assert.match(advisor, /AdiBags_UpdateButton[\s\S]+PaintButton\(button, link\)/,
    'the real Ascension AdiBags installation must receive the same visual markers');
  assert.match(advisor, /SLOT_GROUP[\s\S]+INVTYPE_ROBE = "INVTYPE_CHEST"/,
    'equivalent inventory types must compete for the same equipment slot');
  assert.match(lua, /INVTYPE_WEAPON"[\s\S]+profile\.items\[16\]\.equipLoc == "INVTYPE_2HWEAPON"/,
    'one-handed candidates must not treat the off-hand behind an equipped two-hander as free');
  assert.match(lua, /STANDARD_EQUIP_TEXT[\s\S]+isEquip and not ContainsAny\(text, STANDARD_EQUIP_TEXT\)/,
    'ordinary WotLK Equip stat lines must remain scoreable while special effects stay manual');
  assert.match(lua, /lowestLink and HasUnscoredEffect\(lowestLink\)[\s\S]+l'equipement remplace contient un effet non chiffrable/,
    'an unscored effect on currently equipped gear must lower comparison confidence');
  assert.match(lua, /INVTYPE_WEAPONOFFHAND[\s\S]+necessite aussi une arme a une main compatible/,
    'an off-hand item cannot be recommended alone behind an equipped two-hander');
});

test('CoA Loot Decider preserves the local 1.9 BagAware and fit-scoring behavior', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  const advisor = await readFile(advisorPath, 'utf8');
  assert.match(toc, /^## Version: 1\.15\.0$/m,
    'the published addon must be newer than the installed 1.9.0 custom build');
  for (const required of [
    'ScanBagItems', 'profile.bagItems = ScanBagItems()', 'OwnedBaselineFor',
    'SameOwnedSlot', 'meilleur en sac', 'FitScore', 'FitTier',
    'RequiredUpgradeForFit', 'fitScore = fitScore', 'currentFitScore',
    'isCultistHeretic', 'isBloodmageSanguine', 'bannerPosition',
    'GetItemInfoInstant', 'classID', 'subClassID'
  ]) assert.ok(lua.includes(required), `missing merged 1.9 behavior: ${required}`);
  assert.match(lua, /baselineIndex = \(candidate\.equipLoc == "INVTYPE_FINGER"[\s\S]+pool\[baselineIndex\]/,
    'rings must compare against the second-best owned ring');
  assert.match(lua, /excludeOwnedCopy[\s\S]+data\.link == candidate\.link/,
    'an item displayed in a bag must be compared without counting itself as its baseline');
  assert.match(advisor, /Analyze\(link, source == "Sacs"\)/,
    'bag candidates must opt into self-exclusion');
  assert.equal(lua.includes('C_Container'), false,
    'the merged scanner must remain strict Ascension 3.3.5');
});

test('CoA Loot Decider uses a compact two-level visual language', async () => {
  const lua = await readFile(luaPath, 'utf8');
  const advisor = await readFile(advisorPath, 'utf8');
  for (const required of [
    'settings.visualVersion = 3', 'settings.showDowngrades = false',
    'settings.showAllCandidates = false', 'SetOverlayState',
    'overlay.markerText', 'overlay.markerBg', 'advisorWindow.profileTitle',
    'advisorWindow.mode', 'Confiance ', 'candidat(s) utile(s)',
    '? MANUEL', '+ AMELIORATION', '? CHOIX MANUEL'
  ]) assert.ok(lua.includes(required) || advisor.includes(required), `missing compact loot visual: ${required}`);
  assert.match(advisor, /analysis\.need or analysis\.manual[\s\S]+analysis\.percent/,
    'the default comparison view must hide ordinary downgrades');
  assert.match(advisor, /SetOverlayState\(overlay, "\+"[\s\S]+SetOverlayState\(overlay, "~"[\s\S]+SetOverlayState\(overlay, "-"/,
    'item overlays must remain understandable without relying on colors alone');
});

test('CoA Loot Advisor provides a persistent upgrade plan and visual decision history', async () => {
  const lua = await readFile(luaPath, 'utf8');
  const advisor = await readFile(advisorPath, 'utf8');
  for (const required of [
    'settings.sortMode', 'settings.viewMode', 'settings.windowX', 'settings.windowY',
    'Tri : gain', 'Tri : slot', 'Historique', 'Retour objets',
    'RefreshHistoryWindow', 'FormatHistoryTime', 'CoALootAdvisor_ShowHistory',
    'historyEntry', 'meilleur ', 'manualCount'
  ]) assert.ok(advisor.includes(required), `missing advanced advisor feature: ${required}`);
  assert.match(advisor, /if settings\.sortMode == "gain" then[\s\S]+leftGain > rightGain/,
    'upgrade candidates must be sortable by their real percentage gain');
  assert.match(advisor, /settings\.windowX = centerX - parentX[\s\S]+settings\.windowY = centerY - parentY/,
    'the advisor window position must persist');
  for (const required of [
    'percent = decision.percent', 'confidence = decision.confidence',
    'AddManualHistory', 'decision = "MANUEL"', 'Lower(rest) == "clear"'
  ]) assert.ok(lua.includes(required), `missing decision history data: ${required}`);
});
