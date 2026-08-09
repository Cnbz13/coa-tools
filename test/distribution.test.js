import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const manifest = JSON.parse(await readFile('manifest.json', 'utf8'));

test('release manifest describes the four independent installable components', () => {
  assert.equal(manifest.version, pkg.version);
  assert.deepEqual(manifest.artifacts.map(item => item.component).sort(), ['addon-manager', 'combat-assistant', 'event-alert', 'ui-manager']);
  for (const artifact of manifest.artifacts) {
    assert.equal(artifact.version, pkg.version);
    assert.match(artifact.sha256, /^[a-f0-9]{64}$/);
    assert.notEqual(artifact.sha256, '0'.repeat(64));
    assert.equal(artifact.url.endsWith(`/${artifact.file}`), true);
    assert.ok(artifact.targetFolder);
  }
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
  assert.match(workflow, /CoAEventAlert-v\$env:RELEASE_VERSION\.zip/);
});

test('WoW addon metadata matches the package version', async () => {
  for (const name of ['CoACombatAssistant', 'CoAEventAlert', 'CoAUIManager']) {
    const toc = await readFile(`addons/${name}/${name}.toc`, 'utf8');
    assert.match(toc, /^## Interface: \d+/m);
    assert.match(toc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
    assert.match(toc, new RegExp(`^${name}\\.lua$`, 'm'));
  }
});
