import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const manifest = JSON.parse(await readFile('manifest.json', 'utf8'));

test('release manifest publishes only the Warmane manager and addons', () => {
  assert.equal(manifest.version, pkg.version);
  assert.deepEqual(manifest.artifacts.map(item => item.component).sort(), ['addon-manager', 'warmane-loot-decider', 'warmane-ui-manager']);
  for (const artifact of manifest.artifacts) {
    assert.equal(artifact.version, pkg.version);
    assert.match(artifact.sha256, /^[a-f0-9]{64}$/);
    assert.notEqual(artifact.sha256, '0'.repeat(64));
    assert.equal(artifact.url.endsWith(`/${artifact.file}`), true);
    assert.ok(artifact.targetFolder);
    assert.deepEqual(artifact.gameFlavors, ['warmane']);
  }
  assert.equal(manifest.artifacts.some(item => item.component === 'event-alert'), false);
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
  assert.doesNotMatch(workflow, /EventAlert/i);
  assert.match(workflow, /CoAUIManager-Warmane-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoALootDecider-Warmane-v\$env:RELEASE_VERSION\.zip/);
  assert.doesNotMatch(workflow, /CoACombatAssistant|GridCoA|CoARotationGuide|CoADungeonNavigator/);
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

test('manager can exclude or safely uninstall every managed addon', async () => {
  const server = await readFile('src/server.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  const addons = await readFile('src/core/addons.js', 'utf8');
  assert.match(server, /global-update-exclusion/);
  assert.match(app, /data-exclusion=/);
  assert.match(app, /data-uninstall=/);
  assert.match(app, /Une sauvegarde sera créée/);
  assert.match(app, /DÉSINSTALLÉ DURABLEMENT/);
  assert.match(app, /Réactiver l’installation/);
  assert.match(app, /item\.installationBlocked \? ''/);
  assert.match(addons, /excludedFromGlobalUpdates/);
  assert.match(addons, /\.coa-disabled-addons\.json/);
  assert.match(addons, /disableAddonForProfiles/);
  assert.match(addons, /installationBlocked/);
  assert.match(addons, /'uninstall'/);
  assert.doesNotMatch(addons, /EventAlert|event-alert/);
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

test('Warmane manager does not expose or inject the archived Ascension watch', async () => {
  const server = await readFile('src/server.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  const html = await readFile('public/index.html', 'utf8');
  assert.doesNotMatch(server, /\/api\/watch|CoaWatchService|COA_WATCH_REPORT/);
  assert.doesNotMatch(app, /loadCoaWatch|checkCoaWatch|watchRecommendations/);
  assert.doesNotMatch(html, /Project Ascension|checkCoaWatch|watchRecommendations/);
});

test('published Warmane addon metadata matches the package version', async () => {
  for (const name of ['CoAUIManager', 'CoALootDecider']) {
    const toc = await readFile(`warmane-addons/${name}/${name}.toc`, 'utf8');
    assert.match(toc, /^## Interface: 30300$/m);
    assert.match(toc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
  }
});
