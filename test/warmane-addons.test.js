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
  assert.doesNotMatch(all, /BackdropTemplate|SetShown|C_ClassInfo|C_CharacterAdvancement|GetSpecialization|GetSpecializationInfo/);
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

test('Warmane UI Manager hides only gameplay spell failures and keeps the setting reversible', async () => {
  const ui = await readFile('warmane-addons/CoAUIManager/CoAUIManager.lua', 'utf8');
  assert.match(ui, /Sound_EnableErrorSpeech/);
  assert.match(ui, /UIErrorsFrame:UnregisterEvent\("UI_ERROR_MESSAGE"\)/);
  assert.match(ui, /UIErrorsFrame:RegisterEvent\("UI_ERROR_MESSAGE"\)/);
  assert.match(ui, /command == "quiet"/);
  assert.doesNotMatch(ui, /ScriptErrors|scriptErrors|Sound_EnableSFX/);
});

test('manager remembers separate Ascension and Warmane installations and filters artifacts', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'coa-games-'));
  try {
    const ascension = path.join(root, 'Ascension', 'Interface', 'AddOns');
    const warmane = path.join(root, 'Warmane', 'Interface', 'AddOns');
    await mkdir(ascension, { recursive: true });
    await mkdir(warmane, { recursive: true });
    await mkdir(path.join(ascension, 'AscensionFixture'));
    await writeFile(path.join(ascension, 'AscensionFixture', 'AscensionFixture.toc'), '## Title: Ascension Fixture\n## Version: 1\n');
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
      dataDir: path.join(root, 'data'), canonicalPath: ascension, warmanePath: warmane,
      environmentPath: null, warmaneEnvironmentPath: null,
      manifestUrl: `data:application/json,${encodeURIComponent(JSON.stringify(manifest))}`
    };
    const manager = new AddonManager(options);
    let inventory = await manager.inventory();
    assert.equal(inventory.gameFlavor, 'ascension');
    assert.equal(inventory.addonsDir, ascension);
    assert.deepEqual(inventory.managed.map(item => item.component), ['ui-manager']);
    assert.equal(inventory.regular[0].title, 'Ascension Fixture');

    inventory = await manager.setGameFlavor('warmane');
    assert.equal(inventory.gameFlavor, 'warmane');
    assert.equal(inventory.addonsDir, warmane);
    assert.deepEqual(inventory.managed.map(item => item.component), ['warmane-ui-manager']);
    assert.equal(inventory.regular[0].title, 'Warmane Fixture');

    const restarted = new AddonManager(options);
    assert.equal((await restarted.inventory()).gameFlavor, 'warmane');
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
    await manager.setGameFlavor('warmane');
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
