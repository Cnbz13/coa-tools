import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const manifest = JSON.parse(await readFile('manifest.json', 'utf8'));

test('release manifest describes five managed components and the official EventAlert source', () => {
  assert.equal(manifest.version, pkg.version);
  assert.deepEqual(manifest.artifacts.map(item => item.component).sort(), ['addon-manager', 'combat-assistant', 'event-alert', 'grid-compat', 'ui-manager']);
  for (const artifact of manifest.artifacts) {
    assert.equal(artifact.version, pkg.version);
    assert.match(artifact.sha256, /^[a-f0-9]{64}$/);
    assert.notEqual(artifact.sha256, '0'.repeat(64));
    assert.equal(artifact.url.endsWith(`/${artifact.file}`), true);
    assert.ok(artifact.targetFolder);
  }
  const eventAlert = manifest.artifacts.find(item => item.component === 'event-alert');
  assert.equal(eventAlert.targetFolder, 'EventAlert');
  assert.equal(eventAlert.upstream.version, '4.3.6');
  assert.equal(eventAlert.upstream.url, 'https://edge.forgecdn.net/files/456/081/EventAlert-4.3.6.zip');
  assert.equal(eventAlert.upstream.sha256, '48c529fe42dedae8d7ed779f529e6cb55ba13a1d185b654804080a3bb9e4aa97');
  assert.equal(eventAlert.upstream.license, 'All Rights Reserved');
});

test('Windows launcher captures Node failures and supports dynamic ports and UTF-8', async () => {
  const launcher = await readFile('packaging/windows/launcher/Start-CoAAddonManager.ps1', 'utf8');
  const command = await readFile('packaging/windows/CoAAddonManager.cmd', 'utf8');
  const workflow = await readFile('.github/workflows/release.yml', 'utf8');
  assert.match(launcher, /Get-FreePort/);
  assert.match(launcher, /RedirectStandardOutput/);
  assert.match(launcher, /RedirectStandardError/);
  assert.match(launcher, /serverProcess\.HasExited/);
  assert.match(launcher, /AddSeconds\(60\)/);
  assert.match(command, /chcp 65001/);
  assert.match(workflow, /runs-on: windows-latest/);
  assert.match(workflow, /test-windows-package\.ps1/);
  assert.match(workflow, /verify-eventalert-package\.mjs/);
  assert.match(workflow, /EventAlertCoA-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /GridCoA-v\$env:RELEASE_VERSION\.zip/);
});

test('WoW addon metadata matches the package version', async () => {
  for (const name of ['CoACombatAssistant', 'CoAUIManager', 'GridCoA']) {
    const toc = await readFile(`addons/${name}/${name}.toc`, 'utf8');
    assert.match(toc, /^## Interface: \d+/m);
    assert.match(toc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
    assert.match(toc, new RegExp(`^${name}\\.lua$`, 'm'));
  }
  const compatibilityToc = await readFile('patches/EventAlertCoA/EventAlertCoA/EventAlertCoA.toc', 'utf8');
  const patch = await readFile('patches/EventAlertCoA/EventAlertCoA/EventAlertCoA.lua', 'utf8');
  assert.match(compatibilityToc, /^## Interface: 30300$/m);
  assert.match(compatibilityToc, /^## RequiredDeps: EventAlert$/m);
  assert.match(compatibilityToc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
  assert.match(patch, new RegExp(`local COA_COMPAT_VERSION = "${pkg.version.replaceAll('.', '\\.')}"`));
});
