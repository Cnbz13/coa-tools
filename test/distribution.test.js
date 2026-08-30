import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const manifest = JSON.parse(await readFile('manifest.json', 'utf8'));

test('release manifest describes every managed CoA Tools component', () => {
  assert.equal(manifest.version, pkg.version);
  assert.deepEqual(manifest.artifacts.map(item => item.component).sort(), ['addon-manager', 'combat-assistant', 'dungeon-navigator', 'essential-assistant', 'grid-compat', 'heretic-helper', 'loot-decider', 'message-center', 'primalist-helper', 'rotation-guide', 'stormbringer-helper', 'ui-manager', 'warmane-loot-decider', 'warmane-ui-manager']);
  for (const artifact of manifest.artifacts) {
    assert.equal(artifact.version, pkg.version);
    assert.match(artifact.sha256, /^[a-f0-9]{64}$/);
    assert.notEqual(artifact.sha256, '0'.repeat(64));
    assert.equal(artifact.url.endsWith(`/${artifact.file}`), true);
    assert.ok(artifact.targetFolder);
    assert.ok(Array.isArray(artifact.gameFlavors) && artifact.gameFlavors.length);
  }
  const hereticHelper = manifest.artifacts.find(item => item.component === 'heretic-helper');
  assert.equal(hereticHelper.contentVersion, '3.9.0');
  assert.equal(hereticHelper.targetFolder, 'CoAHereticHelper');
  const stormbringerHelper = manifest.artifacts.find(item => item.component === 'stormbringer-helper');
  assert.equal(stormbringerHelper.contentVersion, '1.1.0');
  assert.equal(stormbringerHelper.targetFolder, 'CoAStormbringerHelper');
  const primalistHelper = manifest.artifacts.find(item => item.component === 'primalist-helper');
  assert.equal(primalistHelper.contentVersion, '1.1.0');
  assert.equal(primalistHelper.targetFolder, 'CoAPrimalistHelper');
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
  assert.match(workflow, /GridCoA-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoALootDecider-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoAUIManager-Warmane-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoALootDecider-Warmane-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoAMessageCenter-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoARotationGuide-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoADungeonNavigator-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoAEssentialAssistant-v\$env:RELEASE_VERSION\.zip/);
  assert.match(workflow, /CoAHereticHelper-v\*\.zip/);
  assert.match(workflow, /CoAStormbringerHelper-v\*\.zip/);
  assert.match(workflow, /CoAPrimalistHelper-v\*\.zip/);
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

test('addon manager exposes sourced CoA watch recommendations without automatic addon edits', async () => {
  const server = await readFile('src/server.js', 'utf8');
  const addons = await readFile('src/core/addons.js', 'utf8');
  const app = await readFile('public/app.js', 'utf8');
  const html = await readFile('public/index.html', 'utf8');
  assert.match(server, /pathname === '\/api\/watch'/);
  assert.match(server, /pathname === '\/api\/watch\/check'/);
  assert.match(server, /gameFeedWriter: \(luaContents, feed\) => addons\.writeRotationUpdateFeed/);
  assert.match(addons, /async writeRotationUpdateFeed\(luaContents, feed = \{\}\)/);
  assert.match(addons, /CoAStormbringerUpdates\.lua/);
  assert.match(addons, /preservedStormbringerFeed/);
  assert.match(addons, /CoAPrimalistUpdates\.lua/);
  assert.match(addons, /preservedPrimalistFeed/);
  assert.match(addons, /CoAEssentialUpdates\.lua/);
  assert.match(addons, /preservedEssentialFeed/);
  assert.match(addons, /component === 'essential-assistant' && preservedEssentialFeed/);
  assert.match(addons, /component === 'rotation-guide' && preservedRotationFeed/);
  assert.match(app, /transmis au Guide de Rotation et aux assistants de classe installés/);
  assert.match(app, /loadCoaWatch/);
  assert.match(app, /Les recommandations restent soumises à validation/);
  assert.match(html, /id="checkCoaWatch"/);
  assert.match(html, /aucune logique d’addon n’est modifiée automatiquement/);
});

test('WoW addon metadata matches the package version', async () => {
  for (const name of ['CoACombatAssistant', 'CoAUIManager', 'CoALootDecider', 'CoAMessageCenter', 'CoARotationGuide', 'CoADungeonNavigator', 'CoAEssentialAssistant', 'GridCoA']) {
    const toc = await readFile(`addons/${name}/${name}.toc`, 'utf8');
    assert.match(toc, /^## Interface: \d+/m);
    assert.match(toc, new RegExp(`^## Version: ${pkg.version.replaceAll('.', '\\.')}$`, 'm'));
    assert.match(toc, new RegExp(`^${name}\\.lua$`, 'm'));
  }
  const hereticToc = await readFile('addons/CoAHereticHelper/CoAHereticHelper.toc', 'utf8');
  assert.match(hereticToc, /^## Version: 3\.9\.0$/m);
  assert.match(hereticToc, /^CoAHereticHelper\.lua$/m);
  const stormToc = await readFile('addons/CoAStormbringerHelper/CoAStormbringerHelper.toc', 'utf8');
  assert.match(stormToc, /^## Version: 1\.1\.0$/m);
  assert.match(stormToc, /^CoAStormbringerHelper\.lua$/m);
  const primalistToc = await readFile('addons/CoAPrimalistHelper/CoAPrimalistHelper.toc', 'utf8');
  assert.match(primalistToc, /^## Version: 1\.1\.0$/m);
  assert.match(primalistToc, /^CoAPrimalistHelper\.lua$/m);
});
