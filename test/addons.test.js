import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { AddonManager, ASCENSION_ADDONS, compareAddonVersions, parseToc } from '../src/core/addons.js';
import { writeZip } from '../src/lib/zip.js';

const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

async function addonZip(root, folder, title, version) {
  const stage = path.join(root, `stage-${folder}`);
  await mkdir(path.join(stage, folder), { recursive: true });
  await writeFile(path.join(stage, folder, `${folder}.toc`), `## Interface: 110200\n## Title: ${title}\n## Notes: Fixture distante vérifiée\n## Version: ${version}\n\n${folder}.lua\n`);
  await writeFile(path.join(stage, folder, `${folder}.lua`), `-- ${title}\n`);
  const archive = path.join(root, `${folder}.zip`);
  await writeZip(stage, archive);
  return readFile(archive);
}

test('TOC metadata and addon versions are parsed tolerantly', () => {
  assert.deepEqual(parseToc('\uFEFF## Title: |cffffcc00AdiBags|r\r\n## Version: v1.2.3\r\n## Notes: Inventory', 'AdiBags'), {
    folder: 'AdiBags', title: 'AdiBags', version: 'v1.2.3', coaCompatibilityVersion: '', notes: 'Inventory', tocFile: 'AdiBags.toc'
  });
  assert.ok(compareAddonVersions('1.0.4', 'v1.0.3') > 0);
  assert.equal(compareAddonVersions('1.0.4', '1.0.4'), 0);
  assert.ok(compareAddonVersions('1.9.1', '1.9.0-Heretic-Sanguine-BagAware') > 0,
    'the repaired release must update the real custom 1.9.0 installation');
});

test('manager scans Ascension addons and installs, backs up, restores and updates CoA addons', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-addon-manager-'));
  const addonsDir = path.join(root, 'Ascension Game With Spaces', 'Interface', 'AddOns');
  const dataDir = path.join(root, 'Local Data With Spaces');
  const regular = path.join(addonsDir, 'AdiBags');
  const version = '1.0.4';
  let server;
  try {
    await mkdir(regular, { recursive: true });
    await writeFile(path.join(regular, 'AdiBags.toc'), '## Title: AdiBags\n## Version: v2.1\n## Notes: Sacs Ascension\n');
    const combatBytes = await addonZip(root, 'CoACombatAssistant', 'CoA Combat Assistant', version);
    const uiBytes = await addonZip(root, 'CoAUIManager', 'CoA UI Manager', version);
    const rotationBytes = await addonZip(root, 'CoARotationGuide', 'CoA Rotation Guide', version);
    const essentialBytes = await addonZip(root, 'CoAEssentialAssistant', 'CoA Essential Assistant', version);
    const profileDir = path.join(root, 'Ascension Game With Spaces', 'WTF', 'Account', 'Test', 'Realm', 'Character');
    const profileAddons = path.join(profileDir, 'AddOns.txt');
    await mkdir(profileDir, { recursive: true });
    await writeFile(profileAddons, 'CoACombatAssistant: enabled\r\n');
    const archives = { '/combat.zip': combatBytes, '/ui.zip': uiBytes, '/rotation.zip': rotationBytes, '/essential.zip': essentialBytes };
    let manifest;
    server = createServer((request, response) => {
      if (request.url === '/manifest.json') {
        response.writeHead(200, { 'content-type': 'application/json' });
        return response.end(JSON.stringify(manifest));
      }
      const bytes = archives[request.url];
      if (!bytes) { response.writeHead(404); return response.end(); }
      response.writeHead(200, { 'content-type': 'application/zip' }); response.end(bytes);
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const origin = `http://127.0.0.1:${server.address().port}`;
    manifest = {
      version,
      artifacts: [
        { name: 'CoA Combat Assistant', component: 'combat-assistant', version, targetFolder: 'CoACombatAssistant', file: 'combat.zip', url: `${origin}/combat.zip`, sha256: sha256(combatBytes), size: combatBytes.length },
        { name: 'CoA UI Manager', component: 'ui-manager', version, targetFolder: 'CoAUIManager', file: 'ui.zip', url: `${origin}/ui.zip`, sha256: sha256(uiBytes), size: uiBytes.length },
        { name: 'CoA Rotation Guide', component: 'rotation-guide', version, targetFolder: 'CoARotationGuide', file: 'rotation.zip', url: `${origin}/rotation.zip`, sha256: sha256(rotationBytes), size: rotationBytes.length },
        { name: 'CoA Essential Assistant', component: 'essential-assistant', version, targetFolder: 'CoAEssentialAssistant', file: 'essential.zip', url: `${origin}/essential.zip`, sha256: sha256(essentialBytes), size: essentialBytes.length }
      ]
    };
    const manager = new AddonManager({ dataDir, canonicalPath: addonsDir, manifestUrl: `${origin}/manifest.json`, environmentPath: null, downloadPolicy: url => url.origin === origin });

    let inventory = await manager.inventory();
    assert.equal(inventory.detectionSource, 'project-ascension');
    assert.equal(inventory.localCount, 1);
    assert.equal(inventory.regular[0].title, 'AdiBags');
    assert.deepEqual(inventory.managed.map(item => item.action), ['install', 'install', 'install', 'install']);
    assert.equal(inventory.managed.find(item => item.component === 'rotation-guide').userManageable, true);

    const combatSha = manifest.artifacts[0].sha256;
    manifest.artifacts[0].sha256 = '0'.repeat(64);
    await assert.rejects(manager.install('combat-assistant'), /SHA-256/);
    assert.equal(await stat(path.join(addonsDir, 'CoACombatAssistant')).then(() => true, () => false), false);
    manifest.artifacts[0].sha256 = combatSha;
    await manager.install('combat-assistant');
    assert.match(await readFile(path.join(addonsDir, 'CoACombatAssistant', 'CoACombatAssistant.toc'), 'utf8'), /## Version: 1\.0\.4/);
    await writeFile(path.join(addonsDir, 'CoACombatAssistant', 'custom.txt'), 'local customization');
    const replaced = await manager.install('combat-assistant');
    assert.ok(replaced.backup);
    assert.equal(await stat(path.join(addonsDir, 'CoACombatAssistant', 'custom.txt')).then(() => true, () => false), false);
    await manager.rollback('combat-assistant', replaced.backup);
    assert.equal(await readFile(path.join(addonsDir, 'CoACombatAssistant', 'custom.txt'), 'utf8'), 'local customization');

    const updated = await manager.updateAll();
    assert.deepEqual(updated.updated, ['ui-manager', 'rotation-guide', 'essential-assistant']);
    inventory = updated.inventory;
    assert.equal(inventory.localCount, 5);
    assert.equal(inventory.managed.every(item => item.installed), true);
    assert.equal(inventory.managed.every(item => item.action === 'reinstall'), true);
    assert.match(await readFile(path.join(addonsDir, 'CoARotationGuide', 'CoARotationGuide.toc'), 'utf8'), /## Version: 1\.0\.4/);
    assert.match(await readFile(path.join(addonsDir, 'CoAEssentialAssistant', 'CoAEssentialAssistant.toc'), 'utf8'), /## Version: 1\.0\.4/);
    assert.match(await readFile(profileAddons, 'utf8'), /^CoARotationGuide: enabled$/m);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
});

test('managed addons can be excluded from global updates and safely uninstalled with a backup', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-addon-exclusions-'));
  const addonsDir = path.join(root, 'Ascension', 'Interface', 'AddOns');
  const dataDir = path.join(root, 'data');
  let server;
  try {
    const combatFolder = path.join(addonsDir, 'CoACombatAssistant');
    await mkdir(combatFolder, { recursive: true });
    await writeFile(path.join(combatFolder, 'CoACombatAssistant.toc'), '## Title: CoA Combat Assistant\n## Version: 1.0.0\n');
    await writeFile(path.join(combatFolder, 'local.txt'), 'conserver cette version');

    const combatBytes = await addonZip(root, 'CoACombatAssistant', 'CoA Combat Assistant', '1.1.0');
    const uiBytes = await addonZip(root, 'CoAUIManager', 'CoA UI Manager', '1.1.0');
    const archives = { '/combat.zip': combatBytes, '/ui.zip': uiBytes };
    let manifest;
    server = createServer((request, response) => {
      if (request.url === '/manifest.json') {
        response.writeHead(200, { 'content-type': 'application/json' });
        return response.end(JSON.stringify(manifest));
      }
      const bytes = archives[request.url];
      if (!bytes) { response.writeHead(404); return response.end(); }
      response.writeHead(200, { 'content-type': 'application/zip' }); response.end(bytes);
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const origin = `http://127.0.0.1:${server.address().port}`;
    manifest = {
      version: '1.1.0', artifacts: [
        { name: 'CoA Combat Assistant', component: 'combat-assistant', version: '1.1.0', targetFolder: 'CoACombatAssistant', file: 'combat.zip', url: `${origin}/combat.zip`, sha256: sha256(combatBytes), size: combatBytes.length },
        { name: 'CoA UI Manager', component: 'ui-manager', version: '1.1.0', targetFolder: 'CoAUIManager', file: 'ui.zip', url: `${origin}/ui.zip`, sha256: sha256(uiBytes), size: uiBytes.length }
      ]
    };
    const options = { dataDir, canonicalPath: addonsDir, manifestUrl: `${origin}/manifest.json`, environmentPath: null, downloadPolicy: url => url.origin === origin };
    const manager = new AddonManager(options);

    let inventory = await manager.setGlobalUpdateExclusion('combat-assistant', true);
    assert.equal(inventory.managed.find(item => item.component === 'combat-assistant').excludedFromGlobalUpdates, true);
    await assert.rejects(manager.setGlobalUpdateExclusion('composant-inconnu', true), /reste inchangé/);

    const restartedManager = new AddonManager(options);
    inventory = await restartedManager.inventory();
    assert.equal(inventory.managed.find(item => item.component === 'combat-assistant').excludedFromGlobalUpdates, true);

    const updated = await restartedManager.updateAll();
    assert.deepEqual(updated.updated, ['ui-manager']);
    assert.equal(await readFile(path.join(combatFolder, 'local.txt'), 'utf8'), 'conserver cette version');

    const uninstalled = await restartedManager.uninstall('combat-assistant');
    assert.ok(uninstalled.backup);
    assert.equal(await stat(combatFolder).then(() => true, () => false), false);
    const combatAfterRemoval = uninstalled.inventory.managed.find(item => item.component === 'combat-assistant');
    assert.equal(combatAfterRemoval.installed, false);
    assert.equal(combatAfterRemoval.excludedFromGlobalUpdates, true);
    assert.equal(combatAfterRemoval.canRollback, true);

    await restartedManager.rollback('combat-assistant', uninstalled.backup);
    assert.equal(await readFile(path.join(combatFolder, 'local.txt'), 'utf8'), 'conserver cette version');
    inventory = await restartedManager.setGlobalUpdateExclusion('combat-assistant', false);
    assert.equal(inventory.managed.find(item => item.component === 'combat-assistant').excludedFromGlobalUpdates, false);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
});

test('a manually selected AddOns path is remembered when standard detection fails', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-addon-settings-'));
  try {
    const selected = path.join(root, 'Manual', 'Interface', 'AddOns');
    await mkdir(selected, { recursive: true });
    const options = { dataDir: path.join(root, 'data'), canonicalPath: path.join(root, 'missing'), manifestUrl: 'data:application/json,%7B%22version%22%3A%221.0.4%22%2C%22artifacts%22%3A%5B%5D%7D', environmentPath: null };
    const first = new AddonManager(options);
    await assert.rejects(first.setDirectory(''), /Sélectionnez un dossier/);
    await first.setDirectory(selected);
    const second = new AddonManager(options);
    assert.deepEqual(await second.detectDirectory(), { directory: selected, exists: true, source: 'saved' });
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('a manually selected AddOns path overrides another valid Ascension installation', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-addons-'));
  try {
    const canonical = path.join(root, 'My PC', 'Interface', 'AddOns');
    const selected = path.join(root, 'Wife PC', 'Interface', 'AddOns');
    const dataDir = path.join(root, 'data');
    await mkdir(canonical, { recursive: true });
    await mkdir(selected, { recursive: true });
    const manager = new AddonManager({ dataDir, canonicalPath: canonical, environmentPath: null, manifestUrl: 'http://127.0.0.1:1/manifest.json' });

    assert.deepEqual(await manager.detectDirectory(), { directory: canonical, exists: true, source: 'project-ascension' });
    await manager.setDirectory(selected);
    assert.deepEqual(await manager.detectDirectory(), { directory: selected, exists: true, source: 'saved' });
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('installing GridCoA requires Grid and enables both addons in existing character profiles', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-grid-manager-'));
  const addonsDir = path.join(root, 'Ascension', 'Interface', 'AddOns');
  let server;
  try {
    const gridBytes = await addonZip(root, 'GridCoA', 'Grid - Compatibilite CoA', '1.3.0');
    let manifest;
    server = createServer((request, response) => {
      if (request.url === '/manifest.json') {
        response.writeHead(200, { 'content-type': 'application/json' });
        return response.end(JSON.stringify(manifest));
      }
      if (request.url === '/grid.zip') {
        response.writeHead(200, { 'content-type': 'application/zip' });
        return response.end(gridBytes);
      }
      response.writeHead(404); response.end();
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const origin = `http://127.0.0.1:${server.address().port}`;
    manifest = { version: '1.3.0', artifacts: [{
      name: 'Grid - Compatibilite CoA', component: 'grid-compat', version: '1.3.0', targetFolder: 'GridCoA',
      file: 'grid.zip', url: `${origin}/grid.zip`, sha256: sha256(gridBytes), size: gridBytes.length
    }] };
    const manager = new AddonManager({
      dataDir: path.join(root, 'data'), canonicalPath: addonsDir, manifestUrl: `${origin}/manifest.json`,
      environmentPath: null, downloadPolicy: url => url.origin === origin
    });
    await mkdir(addonsDir, { recursive: true });
    await assert.rejects(manager.install('grid-compat'), /Grid doit être installé/);

    await mkdir(path.join(addonsDir, 'Grid'), { recursive: true });
    await writeFile(path.join(addonsDir, 'Grid', 'Grid.toc'), '## Interface: 30300\n## Title: Grid\n## Version: 1.30300.1308\n');
    const addonState = path.join(root, 'Ascension', 'WTF', 'Account', 'Test', 'Realm', 'Character', 'AddOns.txt');
    await mkdir(path.dirname(addonState), { recursive: true });
    await writeFile(addonState, 'Grid: disabled\r\nGridCoA: disabled\r\n');
    const installed = await manager.install('grid-compat');
    assert.equal(installed.enabledProfiles, 2);
    const state = await readFile(addonState, 'utf8');
    assert.match(state, /^Grid: enabled$/m);
    assert.match(state, /^GridCoA: enabled$/m);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
});

let realAscensionExists = false;
try { realAscensionExists = (await stat(ASCENSION_ADDONS)).isDirectory(); } catch { /* CI does not have Project Ascension. */ }
test('scanner reads the real Project Ascension installation when present', { skip: !realAscensionExists }, async () => {
  const manager = new AddonManager({ dataDir: path.join(tmpdir(), 'coa-real-scan'), manifestUrl: 'http://invalid.local/manifest.json' });
  const addons = await manager.scan(ASCENSION_ADDONS);
  assert.ok(addons.length > 0);
  assert.equal(addons.every(item => item.folder && item.title && item.version && item.tocFile.endsWith('.toc')), true);
});
