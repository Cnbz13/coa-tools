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
    folder: 'AdiBags', title: 'AdiBags', version: 'v1.2.3', notes: 'Inventory', tocFile: 'AdiBags.toc'
  });
  assert.ok(compareAddonVersions('1.0.4', 'v1.0.3') > 0);
  assert.equal(compareAddonVersions('1.0.4', '1.0.4'), 0);
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

let realAscensionExists = false;
try { realAscensionExists = (await stat(ASCENSION_ADDONS)).isDirectory(); } catch { /* CI does not have Project Ascension. */ }
test('scanner reads the real Project Ascension installation when present', { skip: !realAscensionExists }, async () => {
  const manager = new AddonManager({ dataDir: path.join(tmpdir(), 'coa-real-scan'), manifestUrl: 'http://invalid.local/manifest.json' });
  const addons = await manager.scan(ASCENSION_ADDONS);
  assert.ok(addons.length > 0);
  assert.equal(addons.every(item => item.folder && item.title && item.version && item.tocFile.endsWith('.toc')), true);
});
