import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import luaparse from 'luaparse';
import { AddonManager } from '../src/core/addons.js';
import { writeZip } from '../src/lib/zip.js';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const warmaneFiles = [
  'warmane-addons/CoAUIManager/CoAUIManager.lua',
  'warmane-addons/CoALootDecider/CoALootProfiles.lua',
  'warmane-addons/CoALootDecider/CoALootDecider.lua',
  'warmane-addons/CoALootDecider/CoALootAdvisor.lua'
];

test('Warmane editions are strict Lua 5.1 / WotLK 3.3.5 addons', async () => {
  const contents = [];
  for (const file of warmaneFiles) {
    const lua = await readFile(file, 'utf8');
    assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1' }), file);
    contents.push(lua);
  }
  const all = contents.join('\n');
  assert.doesNotMatch(all, /BackdropTemplate|SetShown|GetItemInfoInstant|C_ClassInfo|C_CharacterAdvancement|GetSpecialization|GetSpecializationInfo/);
  assert.match(all, /GetNumTalentTabs/);
  assert.match(all, /GetTalentTabInfo/);

  for (const folder of ['CoAUIManager', 'CoALootDecider']) {
    const toc = await readFile(`warmane-addons/${folder}/${folder}.toc`, 'utf8');
    assert.match(toc, /^## Interface: 30300$/m);
    assert.match(toc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
  }
});

test('Warmane Loot Decider covers every WotLK class and talent tree', async () => {
  const profiles = await readFile('warmane-addons/CoALootDecider/CoALootProfiles.lua', 'utf8');
  for (const token of ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'DEATHKNIGHT', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID']) {
    assert.match(profiles, new RegExp(`\\b${token}\\s*=`), token);
  }
  assert.ok([...profiles.matchAll(/\["[A-Z]+:[^"]+"\]\s*=/g)].length >= 32);
  assert.match(profiles, /Feral Cat/);
  assert.match(profiles, /Feral Bear/);
  assert.match(profiles, /Blood Tank/);
  assert.match(profiles, /Blood DPS/);
});

test('Warmane Loot Decider evaluates bag capacity and explains item choices in tooltips', async () => {
  const engine = await readFile('warmane-addons/CoALootDecider/CoALootDecider.lua', 'utf8');
  const advisor = await readFile('warmane-addons/CoALootDecider/CoALootAdvisor.lua', 'utf8');

  for (const required of [
    'INVTYPE_BAG = { 20, 21, 22, 23 }', 'CoALootDeciderBagScanner',
    'ReadBagCapacity', 'BagFamily', 'BagBaselineFor', 'AnalyzeBag',
    'for slot = 1, 23 do', 'profile.bagItems', 'slotGain = gain',
    'capacité du sac introuvable', 'sac spécialisé : choix manuel conseillé'
  ]) assert.ok(engine.includes(required), `missing bag-upgrade feature: ${required}`);

  assert.match(engine, /if candidate\.equipLoc == "INVTYPE_BAG" then\s+return AnalyzeBag\(candidate, excludeOwnedCopy\)/,
    'bags must be evaluated before the generic equipment scorer');
  assert.match(engine, /replaceableSlots[\s\S]+profile\.bagItems[\s\S]+owned\[replaceableSlots\]/,
    'the baseline must account for equipped bags, empty slots and spare bags already owned');
  assert.match(engine, /excludeOwnedCopy and not skippedCandidate/,
    'hovering an owned bag must exclude exactly that copy from its own comparison');
  assert.match(engine, /excludeOwnedCopy and not skippedOwnedCopy[\s\S]+skippedOwnedCopy = true/,
    'owned equipment comparisons must also exclude one matching copy, not every duplicate');

  for (const required of [
    'INVTYPE_BAG = "Sac"', 'SAC PLUS GRAND', 'Capacité', 'slotGain',
    'Ce qui change :', 'Pourquoi :', 'Maintiens MAJ', 'Détail du calcul',
    'Non valorisé pour ta spé', 'Gain nécessaire pour NEED',
    'TooltipOwnedBagItem', 'focus.bag', 'focus.slot', 'IsShiftKeyDown', 'CoALootAdvisorDetailed'
  ]) assert.ok(advisor.includes(required), `missing detailed tooltip feature: ${required}`);
});

test('Warmane Loot Decider validates every WotLK weapon and relic family before scoring', async () => {
  const engine = await readFile('warmane-addons/CoALootDecider/CoALootDecider.lua', 'utf8');
  const advisor = await readFile('warmane-addons/CoALootDecider/CoALootAdvisor.lua', 'utf8');

  for (const required of [
    'CLASS_WEAPON_SUBCLASSES', 'CLASS_RELIC_SUBCLASS', 'CLASS_CAN_USE_SHIELD',
    'CLASS_CAN_USE_HOLDABLE', 'WeaponCompatibility', 'WEAPON_SUBCLASS_NAMES',
    'RELIC_SUBCLASS_NAMES', 'returnedClassID', 'returnedSubClassID', 'SubclassFromText',
    'Verification manuelle : le type d\'arme n\'a pas pu etre valide',
    'manual = compatibilityManual and true or false', 'incompatible = not compatibilityManual'
  ]) assert.ok(engine.includes(required), `missing strict weapon compatibility feature: ${required}`);

  // WotLK numeric subclass IDs: wand=19; libram/idol/totem/sigil=7/8/9/10.
  assert.match(engine, /DEATHKNIGHT\s*=\s*\{[^}]*\[8\]\s*=\s*true\s*\}/s);
  assert.doesNotMatch(engine.match(/DEATHKNIGHT\s*=\s*\{[^}]*\}/s)?.[0] ?? '', /\[19\]\s*=\s*true/,
    'Death Knights must never accept wands');
  for (const token of ['MAGE', 'PRIEST', 'WARLOCK']) {
    assert.match(engine.match(new RegExp(`${token}\\s*=\\s*\\{[^}]*\\}`, 's'))?.[0] ?? '', /\[19\]\s*=\s*true/,
      `${token} must accept wands`);
  }
  for (const [token, subclass] of [['PALADIN', 7], ['DRUID', 8], ['SHAMAN', 9], ['DEATHKNIGHT', 10]]) {
    assert.match(engine, new RegExp(`${token}\\s*=\\s*${subclass}`), `${token} relic subclass`);
  }
  for (const token of ['HUNTER', 'WARRIOR', 'ROGUE']) {
    const row = engine.match(new RegExp(`${token}\\s*=\\s*\\{[^}]*\\}`, 's'))?.[0] ?? '';
    for (const subclass of token === 'HUNTER' ? [2, 3, 18] : [2, 3, 16, 18]) {
      assert.match(row, new RegExp(`\\[${subclass}\\]\\s*=\\s*true`), `${token} ranged subclass ${subclass}`);
    }
  }

  const validation = engine.indexOf('local compatibilityProblem, compatibilityManual = CompatibilityProblem(candidate)');
  const scoring = engine.indexOf('local candidateScore = ScoreItem(candidate)', validation);
  assert.ok(validation >= 0 && scoring > validation, 'weapon compatibility must run before ScoreItem');
  assert.match(engine, /local function ScoreItem\(data\)[\s\S]*?local weaponCompatible = WeaponCompatibility\(data\)[\s\S]*?if weaponCompatible ~= true then return 0 end/,
    'ScoreItem itself must never value an incompatible wand or weapon');
  assert.match(engine, /local function AddOwned\(data, source\)[\s\S]*?WeaponCompatibility\(data\)[\s\S]*?if weaponCompatible ~= true then return end/,
    'incompatible weapons in bags must not become a comparison baseline');
  assert.match(engine, /if analysis and analysis\.manual then return nil, analysis\.reason end/,
    'unknown subtypes must never trigger an automatic NEED/PASS');
  assert.match(advisor, /if analysis\.manual then[\s\S]*SetOverlayState\(overlay, "\?"/,
    'unknown types must display the manual-review marker');
  assert.match(advisor, /if analysis\.incompatible and EnsureSettings\(\)\.showDowngrades then/,
    'red incompatible markers must obey the existing downgrade display setting');

  // The bag and detailed-tooltip features from v1.23.2 remain wired in.
  assert.match(engine, /if candidate\.equipLoc == "INVTYPE_BAG" then\s+return AnalyzeBag/);
  assert.match(advisor, /Maintiens MAJ pour afficher le calcul détaillé/);
});

test('Warmane Loot Decider cannot repeat the French DK rusty-pitchfork +99% regression', async () => {
  const engine = await readFile('warmane-addons/CoALootDecider/CoALootDecider.lua', 'utf8');
  const advisor = await readFile('warmane-addons/CoALootDecider/CoALootAdvisor.lua', 'utf8');

  // Lua 5.1 string.lower is ASCII-only. The equipped French subtype
  // "Épées à deux mains" must resolve exactly like "épées à deux mains".
  assert.match(engine, /\["É"\]\s*=\s*"e"/);
  assert.match(engine, /local function FoldItemText\(value\)[\s\S]*?string\.lower\(text\)/);
  assert.match(engine, /local function SubclassFromText\(classID, itemSubType\)[\s\S]*?FoldItemText\(itemSubType\)/);
  assert.match(engine, /normalized == FoldItemText\(localized\)/);
  assert.match(engine, /normalized == FoldItemText\(alias\)/);

  // An unvalidated equipped weapon is not an empty slot and never scores zero.
  assert.match(engine, /local function ComparableScore\(data\)[\s\S]*?if compatible ~= true then[\s\S]*?return nil, problem/);
  assert.match(engine, /local function ComparisonFor\(data\)[\s\S]*?ComparableScore\(main\)/);
  assert.match(engine, /if current and score == nil then[\s\S]*?Vérification manuelle : objet équipé non validé/);
  assert.match(engine, /if currentScore == nil then[\s\S]*?manual = true/);

  // Grey vendor trash and catastrophic raw weapon-DPS losses cannot be NEED.
  assert.match(engine, /if tonumber\(candidate\.quality\) == 0 then[\s\S]*?jamais une amélioration fiable[\s\S]*?incompatible = true/);
  assert.match(engine, /local function WeaponDpsLossProblem\(candidate, current\)[\s\S]*?candidateDps >= currentDps \* 0\.75/);
  assert.match(engine, /local weaponDpsProblem = WeaponDpsLossProblem\(candidate, currentData\)/);
  assert.match(engine, /local fitBlocked = effectiveThreshold >= 999 or weaponDpsProblem ~= nil/);
  assert.match(engine, /forcedDowngrade = weaponDpsProblem and true or false/);
  assert.match(advisor, /if analysis\.forcedDowngrade then[\s\S]*?SetOverlayState\(overlay, "-", "DPS"/);
  assert.match(advisor, /DPS ARME TROP FAIBLE/);

  // The single WotLK DPS stat key is applied only to the relevant weapon slot.
  assert.match(engine, /local function WeaponDamageMatters\(data\)/);
  assert.match(engine, /profile\.classToken == "HUNTER"[\s\S]*?IsRangedWeaponEquipLoc/);
  assert.match(engine, /MELEE_WEAPON_DPS_CLASSES\[profile\.classToken\][\s\S]*?IsMeleeWeaponEquipLoc/);
  assert.match(engine, /if key ~= "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" or WeaponDamageMatters\(data\) then/);
  assert.match(engine, /ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS ARME"/,
    'tooltips must show a readable weapon-DPS label rather than the raw API key');
});

test('Warmane UI Manager hides only gameplay spell failures and keeps the setting reversible', async () => {
  const ui = await readFile('warmane-addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  assert.match(ui, /Sound_EnableErrorSpeech/);
  assert.match(ui, /UIErrorsFrame:UnregisterEvent\("UI_ERROR_MESSAGE"\)/);
  assert.match(ui, /UIErrorsFrame:RegisterEvent\("UI_ERROR_MESSAGE"\)/);
  assert.match(ui, /command == "quiet"/);
  assert.doesNotMatch(ui, /ScriptErrors|scriptErrors|Sound_EnableSFX/);
});

test('manager migrates to one remembered Warmane installation and filters legacy artifacts', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'coa-games-'));
  try {
    const warmane = path.join(root, 'Warmane', 'Interface', 'AddOns');
    await mkdir(warmane, { recursive: true });
    await mkdir(path.join(warmane, 'WarmaneFixture'));
    await writeFile(path.join(warmane, 'WarmaneFixture', 'WarmaneFixture.toc'), '## Title: Warmane Fixture\n## Version: 1\n');
    const artifact = (component, targetFolder, gameFlavor) => ({
      name: component, component, version: pkg.version, gameFlavors: [gameFlavor], targetFolder,
      file: `${component}.zip`, url: `https://github.com/Cnbz13/coa-tools/${component}.zip`, sha256: 'a'.repeat(64), size: 1
    });
    const manifest = {
      version: pkg.version,
      artifacts: [artifact('ui-manager', 'CoAUIManager', 'ascension'), artifact('warmane-ui-manager', 'CoAUIManager', 'warmane')]
    };
    const options = {
      dataDir: path.join(root, 'data'), canonicalPath: path.join(root, 'missing'),
      environmentPath: null,
      manifestUrl: `data:application/json,${encodeURIComponent(JSON.stringify(manifest))}`
    };
    await mkdir(options.dataDir, { recursive: true });
    await writeFile(path.join(options.dataDir, 'addon-settings.json'), JSON.stringify({
      gameFlavor: 'ascension', installations: { ascension: path.join(root, 'old'), warmane }
    }));
    const manager = new AddonManager(options);
    const inventory = await manager.inventory();
    assert.equal(inventory.gameFlavor, 'warmane');
    assert.equal(inventory.addonsDir, warmane);
    assert.deepEqual(inventory.managed.map(item => item.component), ['warmane-ui-manager']);
    assert.equal(inventory.regular[0].title, 'Warmane Fixture');

    await manager.setDirectory(warmane);
    const normalizedSettings = JSON.parse(await readFile(path.join(options.dataDir, 'addon-settings.json'), 'utf8'));
    assert.equal(normalizedSettings.addonsDir, warmane);
    assert.equal('installations' in normalizedSettings, false);
    assert.equal('gameFlavor' in normalizedSettings, false);

    const restarted = new AddonManager(options);
    assert.equal((await restarted.inventory()).addonsDir, warmane);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test('manager installs the real Warmane editions with SHA-256 and enables character profiles', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'coa-warmane-install-'));
  let server;
  try {
    const addonsDir = path.join(root, 'Warmane With Spaces', 'Interface', 'AddOns');
    const profileFile = path.join(root, 'Warmane With Spaces', 'WTF', 'Account', 'TEST', 'Icecrown', 'Character', 'AddOns.txt');
    await mkdir(addonsDir, { recursive: true });
    await mkdir(path.dirname(profileFile), { recursive: true });
    await writeFile(profileFile, 'CoAUIManager: disabled\r\nCoALootDecider: disabled\r\n');

    const archives = {};
    for (const folder of ['CoAUIManager', 'CoALootDecider']) {
      const stage = path.join(root, `stage-${folder}`);
      await mkdir(stage, { recursive: true });
      const source = path.resolve('warmane-addons', folder);
      const { cp } = await import('node:fs/promises');
      await cp(source, path.join(stage, folder), { recursive: true });
      const zip = path.join(root, `${folder}.zip`);
      await writeZip(stage, zip);
      archives[`/${folder}.zip`] = await readFile(zip);
    }
    let manifest;
    server = createServer((request, response) => {
      if (request.url === '/manifest.json') {
        response.writeHead(200, { 'content-type': 'application/json' });
        return response.end(JSON.stringify(manifest));
      }
      const bytes = archives[request.url];
      if (!bytes) { response.writeHead(404); return response.end(); }
      response.writeHead(200, { 'content-type': 'application/zip' });
      response.end(bytes);
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const origin = `http://127.0.0.1:${server.address().port}`;
    const artifact = (component, folder) => ({
      name: component, component, version: pkg.version, gameFlavors: ['warmane'], targetFolder: folder,
      file: `${folder}.zip`, url: `${origin}/${folder}.zip`,
      sha256: createHash('sha256').update(archives[`/${folder}.zip`]).digest('hex'),
      size: archives[`/${folder}.zip`].length
    });
    manifest = { version: pkg.version, artifacts: [
      artifact('warmane-ui-manager', 'CoAUIManager'),
      artifact('warmane-loot-decider', 'CoALootDecider')
    ] };

    const manager = new AddonManager({
      dataDir: path.join(root, 'data'), canonicalPath: path.join(root, 'missing-ascension'),
      warmanePath: addonsDir, environmentPath: null, warmaneEnvironmentPath: null,
      manifestUrl: `${origin}/manifest.json`, downloadPolicy: url => url.origin === origin
    });
    const result = await manager.updateAll();
    assert.deepEqual(result.updated, ['warmane-ui-manager', 'warmane-loot-decider']);
    assert.match(await readFile(path.join(addonsDir, 'CoAUIManager', 'CoAUIManager.toc'), 'utf8'), /^## Interface: 30300$/m);
    assert.match(await readFile(path.join(addonsDir, 'CoALootDecider', 'CoALootDecider.toc'), 'utf8'), /^## Interface: 30300$/m);
    const profiles = await readFile(profileFile, 'utf8');
    assert.match(profiles, /^CoAUIManager: enabled$/m);
    assert.match(profiles, /^CoALootDecider: enabled$/m);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
});
