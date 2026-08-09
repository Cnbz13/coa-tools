import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { AddonManager } from '../src/core/addons.js';

const manifest = JSON.parse(await readFile('dist/manifest.json', 'utf8'));
const artifact = manifest.artifacts.find(item => item.component === 'event-alert');
if (!artifact) throw new Error('EventAlert artifact missing from dist/manifest.json');
const patchBytes = await readFile(path.join('dist', artifact.file));
const root = await mkdtemp(path.join(tmpdir(), 'coa-eventalert-e2e-'));
const addonsDir = path.join(root, 'Ascension Desktop Test', 'Interface', 'AddOns');
let server;

try {
  const legacy = path.join(addonsDir, 'CoAEventAlert');
  const companion = path.join(addonsDir, 'EventAlertCoA');
  await mkdir(legacy, { recursive: true });
  await writeFile(path.join(legacy, 'CoAEventAlert.toc'), '## Interface: 30300\n## Title: Legacy CoA Event Alert\n## Version: 1.1.1\n');

  let localManifest;
  server = createServer((request, response) => {
    if (request.url === '/manifest.json') {
      response.writeHead(200, { 'content-type': 'application/json' });
      return response.end(JSON.stringify(localManifest));
    }
    if (request.url === `/${artifact.file}`) {
      response.writeHead(200, { 'content-type': 'application/zip' });
      return response.end(patchBytes);
    }
    response.writeHead(404); response.end();
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  localManifest = { ...manifest, artifacts: [{ ...artifact, url: `${origin}/${artifact.file}` }] };

  const manager = new AddonManager({
    dataDir: path.join(root, 'manager-data'), canonicalPath: addonsDir, environmentPath: null,
    manifestUrl: `${origin}/manifest.json`,
    downloadPolicy: url => url.origin === origin
      || (url.protocol === 'https:' && url.hostname === 'edge.forgecdn.net' && url.pathname === '/files/456/081/EventAlert-4.3.6.zip')
  });
  const result = await manager.install('event-alert');
  const installed = path.join(addonsDir, 'EventAlert');
  for (const file of ['EventAlert.lua', 'EventAlert.xml', 'EventAlert.toc', 'EventAlertSpellArray.lua']) {
    assert.ok((await stat(path.join(installed, file))).isFile(), `${file} was not installed`);
  }
  assert.ok((await stat(path.join(companion, 'EventAlertCoA.lua'))).isFile(), 'CoA compatibility loader was not installed');
  const companionToc = await readFile(path.join(companion, 'EventAlertCoA.toc'), 'utf8');
  assert.match(companionToc, /^## RequiredDeps: EventAlert$/m);
  assert.match(companionToc, new RegExp(`^## Version: ${manifest.version.replaceAll('.', '\\.')}$`, 'm'));
  assert.doesNotMatch(await readFile(path.join(installed, 'EventAlert.xml'), 'utf8'), /EventAlertCoA\.lua/);
  assert.equal(await stat(legacy).then(() => true, () => false), false, 'obsolete CoAEventAlert must be removed');

  // Ascension may repair the official folder on launch. The separate loader must survive.
  await writeFile(path.join(installed, 'EventAlert.xml'), '<Ui>official launcher repair</Ui>\n');
  await writeFile(path.join(installed, 'EventAlert.toc'), '## Interface: 30300\n## Title: EventAlert\n## Version: 4.3.6\n\nEventAlert.xml\n');
  const repairedInventory = await manager.inventory();
  assert.equal(repairedInventory.managed[0].installed, true);
  assert.equal(repairedInventory.managed[0].localVersion, manifest.version);
  assert.equal(result.upstreamVersion, '4.3.6');
  assert.equal(result.inventory.managed[0].action, 'reinstall');
  console.log(`EventAlert ${result.upstreamVersion} + CoA ${manifest.version}: genuine package installed and verified`);
} finally {
  if (server) await new Promise(resolve => server.close(resolve));
  await rm(root, { recursive: true, force: true });
}
