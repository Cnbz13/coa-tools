import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const manifest = JSON.parse(await readFile('manifest.json', 'utf8'));

test('release manifest describes every managed component and the official EventAlert source', () => {
  assert.equal(manifest.version, pkg.version);
  assert.deepEqual(manifest.artifacts.map(item => item.component).sort(), ['addon-manager', 'combat-assistant', 'event-alert', 'grid-compat', 'heretic-helper', 'loot-decider', 'message-center', 'ui-manager']);
  for (const artifact of manifest.artifacts) {
    assert.equal(artifact.version, pkg.version);
    assert.match(artifact.sha256, /^[a-f0-9]{64}$/);
    assert.notEqual(artifact.sha256, '0'.repeat(64));
    assert.equal(artifact.url.endsWith(`/${artifact.file}`), true);
    assert.ok(artifact.targetFolder);
  }
  const hereticHelper = manifest.artifacts.find(item => item.component === 'heretic-helper');
  assert.equal(hereticHelper.contentVersion, '3.7.1');
  assert.equal(hereticHelper.targetFolder, 'CoAHereticHelper');
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
  assert.match(launcher, /Stage-LatestManagerUpdate/);
  assert.match(launcher, /Apply-PendingManagerUpdate/);
  assert.match(launcher, /Stop-CoAManagerProcesses/);
  assert.match(launcher, /function Get-Sha256Hex/);
  assert.match(launcher, /Security\.Cryptography\.SHA256/);
  assert.match(launcher, /CoAAddonManager\/ready\.json|updatesRoot 'ready\.json'/);
  assert.match(command, /chcp 65001/);
  assert.match(workflow, /runs-on: windows-latest/);
  assert.match(workflow, /test-windows-package\.ps1/);
  assert.match(workflow, /verify-eventalert-package\.mjs/);
  assert.match(workflow, /EventAlertCoA-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /GridCoA-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoALootDecider-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoAMessageCenter-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoAHereticHelper-v\*\.zip/);
});

test('Windows AddOns picker is owned and forced to the foreground', async () => {
  const picker = await readFile('src/lib/windows-folder-picker.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  assert.match(picker, /System\.Windows\.Forms\.FolderBrowserDialog/);
  assert.match(picker, /\$owner\.TopMost = \$true/);
  assert.match(picker, /ShowDialog\(\$owner\)/);
  assert.match(app, /button\.textContent = 'Ouverture/);
  assert.match(app, /button\.disabled = true/);
});

test('addon manager exposes recoverable progress for individual and global updates', async () => {
  const server = await readFile('src/server.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  const html = await readFile('public/index.html', 'utf8');
  const addons = await readFile('src/core/addons.js', 'utf8');
  assert.match(server, /\/api\/addons\/operations\/current/);
  assert.match(server, /addonOperations\.start\(input\.action, input\.component\)/);
  assert.match(app, /setTimeout\(pollAddonOperation, 500\)/);
  assert.match(app, /resumeAddonOperation/);
  assert.match(app, /addonProgressBytes/);
  assert.match(html, /id="addonProgressBar"/);
  assert.match(html, /Délai réseau maximal : 2 minutes par fichier/);
  assert.match(addons, /Délai réseau dépassé après 2 minutes/);
  assert.match(addons, /phasePercent/);
});

test('manager can exclude or safely uninstall selected addons without changing EventAlert', async () => {
  const server = await readFile('src/server.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  const addons = await readFile('src/core/addons.js', 'utf8');
  assert.match(server, /global-update-exclusion/);
  assert.match(app, /data-exclusion=/);
  assert.match(app, /data-uninstall=/);
  assert.match(app, /Une sauvegarde sera créée/);
  assert.match(addons, /excludedFromGlobalUpdates/);
  assert.match(addons, /'uninstall'/);
  assert.match(addons, /component !== 'event-alert'/);
  assert.match(addons, /ne peut pas être désinstallé ici/);
});

test('manager checks hourly, alerts Windows and can update addons automatically', async () => {
  const app = await readFile('public/app.js', 'utf8');
  const html = await readFile('public/index.html', 'utf8');
  const uiManager = await readFile('src/core/ui-manager.js', 'utf8');
  const server = await readFile('src/server.js', 'utf8');
  const monitor = await readFile('src/core/update-monitor.js', 'utf8');
  assert.match(app, /UPDATE_CHECK_INTERVAL_MS = 60 \* 60 \* 1000/);
  assert.match(app, /startAutomaticAddonUpdates/);
  assert.match(app, /managerUpdateAlerts/);
  assert.match(html, /id="autoUpdateAddons"/);
  assert.match(html, /id="managerUpdateAlerts"/);
  assert.match(uiManager, /autoUpdateAddons: true/);
  assert.match(uiManager, /managerUpdateAlerts: true/);
  assert.match(server, /updateMonitor\.start\(\)/);
  assert.match(monitor, /MANAGER_UPDATE_INTERVAL_MS = 60 \* 60 \* 1000/);
  assert.match(monitor, /System\.Windows\.Forms\.MessageBox/);
});

test('addon manager exposes sourced CoA watch recommendations without automatic addon edits', async () => {
  const server = await readFile('src/server.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  const html = await readFile('public/index.html', 'utf8');
  assert.match(server, /pathname === '\/api\/watch'/);
  assert.match(server, /pathname === '\/api\/watch\/check'/);
  assert.match(app, /loadCoaWatch/);
  assert.match(app, /Les recommandations restent soumises à validation/);
  assert.match(html, /id="checkCoaWatch"/);
  assert.match(html, /aucune logique d’addon n’est modifiée automatiquement/);
});

test('WoW addon metadata matches the package version', async () => {
  for (const name of ['CoACombatAssistant', 'CoAUIManager', 'CoALootDecider', 'CoAMessageCenter', 'GridCoA']) {
    const toc = await readFile(`addons/${name}/${name}.toc`, 'utf8');
    assert.match(toc, /^## Interface: \d+/m);
    assert.match(toc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
    assert.match(toc, new RegExp(`^${name}\\.lua$`, 'm'));
  }
  const hereticToc = await readFile('addons/CoAHereticHelper/CoAHereticHelper.toc', 'utf8');
  assert.match(hereticToc, /^## Version: 3\.7\.1$/m);
  assert.match(hereticToc, /^CoAHereticHelper\.lua$/m);
  const compatibilityToc = await readFile('patches/EventAlertCoA/EventAlertCoA/EventAlertCoA.toc', 'utf8');
  const patch = await readFile('patches/EventAlertCoA/EventAlertCoA/EventAlertCoA.lua', 'utf8');
  assert.match(compatibilityToc, /^## Interface: 30300$/m);
  assert.match(compatibilityToc, /^## RequiredDeps: EventAlert$/m);
  assert.match(compatibilityToc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
  assert.match(patch, new RegExp(`local COA_COMPAT_VERSION = "${pkg.version.replaceAll('.', '\\.')}"`));
});
