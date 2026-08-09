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
});

test('manager installs genuine EventAlert with a repair-resistant CoA companion and backs up both folders', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-eventalert-manager-'));
  const addonsDir = path.join(root, 'Ascension', 'Interface', 'AddOns');
  let server;
  try {
    const upstreamStage = path.join(root, 'upstream-stage', 'EventAlert');
    await mkdir(upstreamStage, { recursive: true });
    await writeFile(path.join(upstreamStage, 'EventAlert.toc'), '## Interface: 30300\n## Title: EventAlert\n## Version: 4.3.6\n\nEventAlert.xml\n');
    await writeFile(path.join(upstreamStage, 'EventAlert.xml'), '<Ui>\n<Script file="EventAlert.lua"/>\n<Script file="EventAlertSpellArray.lua"/>\n</Ui>\n');
    await writeFile(path.join(upstreamStage, 'EventAlert.lua'), '-- genuine upstream fixture\n');
    const upstreamArchive = path.join(root, 'EventAlert-4.3.6.zip');
    await writeZip(path.join(root, 'upstream-stage'), upstreamArchive);
    const upstreamBytes = await readFile(upstreamArchive);

    const patchStage = path.join(root, 'patch-stage', 'EventAlertCoA');
    await mkdir(patchStage, { recursive: true });
    await writeFile(path.join(patchStage, 'EventAlertCoA.lua'), '-- CoA patch fixture\n');
    await writeFile(path.join(patchStage, 'EventAlertCoA.toc'), '## Interface: 30300\n## Title: EventAlert - Compatibilite CoA\n## Version: 1.2.1\n## RequiredDeps: EventAlert\n\nEventAlertCoA.lua\n');
    const patchArchive = path.join(root, 'EventAlertCoA.zip');
    await writeZip(path.join(root, 'patch-stage'), patchArchive);
    const patchBytes = await readFile(patchArchive);

    for (const folder of ['EventAlert', 'CoAEventAlert']) {
      await mkdir(path.join(addonsDir, folder), { recursive: true });
      await writeFile(path.join(addonsDir, folder, `${folder}.toc`), `## Interface: 30300\n## Title: Old ${folder}\n## Version: 1.1.1\n`);
      await writeFile(path.join(addonsDir, folder, 'local.txt'), `old ${folder}`);
    }
    const addonState = path.join(root, 'Ascension', 'WTF', 'Account', 'Test', 'Realm', 'Character', 'AddOns.txt');
    await mkdir(path.dirname(addonState), { recursive: true });
    await writeFile(addonState, 'EventAlert: enabled\r\nCoAEventAlert: disabled\r\nEventAlertCoA: disabled\r\n');

    const archives = { '/EventAlert-4.3.6.zip': upstreamBytes, '/EventAlertCoA.zip': patchBytes };
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
      version: '1.2.1', artifacts: [{
        name: 'EventAlert 4.3.6 + compatibilité CoA', component: 'event-alert', version: '1.2.1',
        targetFolder: 'EventAlert', file: 'EventAlertCoA.zip', url: `${origin}/EventAlertCoA.zip`,
        sha256: sha256(patchBytes), size: patchBytes.length,
        upstream: {
          name: 'EventAlert', version: '4.3.6', targetFolder: 'EventAlert', file: 'EventAlert-4.3.6.zip',
          url: `${origin}/EventAlert-4.3.6.zip`, sha256: sha256(upstreamBytes), size: upstreamBytes.length
        }
      }]
    };
    const manager = new AddonManager({
      dataDir: path.join(root, 'data'), canonicalPath: addonsDir, manifestUrl: `${origin}/manifest.json`,
      environmentPath: null, downloadPolicy: url => url.origin === origin
    });

    const before = await manager.inventory();
    assert.equal(before.managed[0].action, 'install');
    assert.equal(before.regular.some(item => item.folder === 'CoAEventAlert'), false);
    const installed = await manager.install('event-alert');
    assert.ok(installed.backup);
    assert.equal(installed.enabledProfiles, 1);
    assert.doesNotMatch(await readFile(path.join(addonsDir, 'EventAlert', 'EventAlert.xml'), 'utf8'), /EventAlertCoA\.lua/);
    assert.doesNotMatch(await readFile(path.join(addonsDir, 'EventAlert', 'EventAlert.toc'), 'utf8'), /X-CoA-Compatibility-Version/);
    assert.match(await readFile(path.join(addonsDir, 'EventAlertCoA', 'EventAlertCoA.toc'), 'utf8'), /RequiredDeps: EventAlert/);
    assert.match(await readFile(path.join(addonsDir, 'EventAlertCoA', 'EventAlertCoA.toc'), 'utf8'), /Version: 1\.2\.1/);
    assert.match(await readFile(path.join(addonsDir, 'EventAlertCoA', 'EventAlertCoA.lua'), 'utf8'), /CoA patch fixture/);
    assert.equal(await stat(path.join(addonsDir, 'CoAEventAlert')).then(() => true, () => false), false);
    assert.match(await readFile(addonState, 'utf8'), /^EventAlertCoA: enabled$/m);
    assert.equal(installed.inventory.managed[0].action, 'reinstall');

    // Project Ascension may restore every official EventAlert file on launch.
    // The companion remains loadable and the manager still recognizes it.
    await writeFile(path.join(addonsDir, 'EventAlert', 'EventAlert.xml'), '<Ui>official repair</Ui>\n');
    await writeFile(path.join(addonsDir, 'EventAlert', 'EventAlert.toc'), '## Interface: 30300\n## Title: EventAlert\n## Version: 4.3.6\n\nEventAlert.xml\n');
    const afterRepair = await manager.inventory();
    assert.equal(afterRepair.managed[0].installed, true);
    assert.equal(afterRepair.managed[0].localVersion, '1.2.1');
    assert.equal(afterRepair.managed[0].action, 'reinstall');

    await manager.rollback('event-alert', installed.backup);
    assert.equal(await readFile(path.join(addonsDir, 'EventAlert', 'local.txt'), 'utf8'), 'old EventAlert');
    assert.equal(await readFile(path.join(addonsDir, 'CoAEventAlert', 'local.txt'), 'utf8'), 'old CoAEventAlert');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
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
      version,
      artifacts: [
        { name: 'CoA Combat Assistant', component: 'combat-assistant', version, targetFolder: 'CoACombatAssistant', file: 'combat.zip', url: `${origin}/combat.zip`, sha256: sha256(combatBytes), size: combatBytes.length },
        { name: 'CoA UI Manager', component: 'ui-manager', version, targetFolder: 'CoAUIManager', file: 'ui.zip', url: `${origin}/ui.zip`, sha256: sha256(uiBytes), size: uiBytes.length }
      ]
    };
    const manager = new AddonManager({ dataDir, canonicalPath: addonsDir, manifestUrl: `${origin}/manifest.json`, environmentPath: null, downloadPolicy: url => url.origin === origin });

    let inventory = await manager.inventory();
    assert.equal(inventory.detectionSource, 'project-ascension');
    assert.equal(inventory.localCount, 1);
    assert.equal(inventory.regular[0].title, 'AdiBags');
    assert.deepEqual(inventory.managed.map(item => item.action), ['install', 'install']);

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
    assert.deepEqual(updated.updated, ['ui-manager']);
    inventory = updated.inventory;
    assert.equal(inventory.localCount, 3);
    assert.equal(inventory.managed.every(item => item.installed), true);
    assert.equal(inventory.managed.every(item => item.action === 'reinstall'), true);
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

test('production manager pins the exact official EventAlert source', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'coa-eventalert-pin-'));
  const addonsDir = path.join(root, 'Interface', 'AddOns');
  try {
    await mkdir(addonsDir, { recursive: true });
    const tampered = {
      version: '1.2.0', artifacts: [{
        name: 'EventAlert', component: 'event-alert', version: '1.2.0', targetFolder: 'EventAlert',
        file: 'patch.zip', url: 'https://github.com/Cnbz13/coa-tools/releases/download/v1.2.0/patch.zip', sha256: '1'.repeat(64), size: 1,
        upstream: { version: '4.3.6', targetFolder: 'EventAlert', file: 'EventAlert-4.3.6.zip', url: 'https://edge.forgecdn.net/files/456/081/EventAlert-4.3.6.zip', sha256: '2'.repeat(64), size: 27480 }
      }]
    };
    const manifestUrl = `data:application/json,${encodeURIComponent(JSON.stringify(tampered))}`;
    const manager = new AddonManager({ dataDir: path.join(root, 'data'), canonicalPath: addonsDir, environmentPath: null, manifestUrl });
    await assert.rejects(manager.install('event-alert'), /Source officielle EventAlert modifiée/);
  } finally { await rm(root, { recursive: true, force: true }); }
});

let realAscensionExists = false;
try { realAscensionExists = (await stat(ASCENSION_ADDONS)).isDirectory(); } catch { /* CI does not have Project Ascension. */ }
test('scanner reads the real Project Ascension installation when present', { skip: !realAscensionExists }, async () => {
  const manager = new AddonManager({ dataDir: path.join(tmpdir(), 'coa-real-scan'), manifestUrl: 'http://invalid.local/manifest.json' });
  const addons = await manager.scan(ASCENSION_ADDONS);
  assert.ok(addons.length > 0);
  assert.equal(addons.every(item => item.folder && item.title && item.version && item.tocFile.endsWith('.toc')), true);
});
