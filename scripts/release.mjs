import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { writeZip } from '../src/lib/zip.js';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const version = process.env.RELEASE_VERSION || pkg.version;
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`Invalid release version: ${version}`);

const output = path.resolve('dist');
const stage = path.join(output, 'stage');
await rm(output, { recursive: true, force: true });
await mkdir(stage, { recursive: true });

const managerRoot = path.join(stage, 'manager', 'CoAAddonManager');
await mkdir(managerRoot, { recursive: true });
for (const item of ['src', 'public', 'schemas']) await cp(item, path.join(managerRoot, item), { recursive: true });
for (const item of ['LICENSE', 'SECURITY.md']) await cp(item, path.join(managerRoot, item));
await cp('packaging/windows', managerRoot, { recursive: true });
await writeFile(path.join(managerRoot, 'package.json'), `${JSON.stringify({ ...pkg, version }, null, 2)}\n`);

const packages = [
  { name: 'CoA Addon Manager for Windows', component: 'addon-manager', platform: 'win32', arch: 'x64', targetFolder: 'CoAAddonManager', installPath: '.', file: `CoAAddonManager-v${version}-Windows.zip`, source: path.join(stage, 'manager') },
  { name: 'CoA Combat Assistant', component: 'combat-assistant', platform: 'any', arch: 'any', targetFolder: 'CoACombatAssistant', installPath: 'Interface/AddOns', file: `CoACombatAssistant-v${version}.zip`, source: path.resolve('addons', 'CoACombatAssistant', '..') , only: 'CoACombatAssistant' },
  { name: 'CoA UI Manager', component: 'ui-manager', platform: 'any', arch: 'any', targetFolder: 'CoAUIManager', installPath: 'Interface/AddOns', file: `CoAUIManager-v${version}.zip`, source: path.resolve('addons', 'CoAUIManager', '..'), only: 'CoAUIManager' },
  { name: 'CoA Loot Decider', component: 'loot-decider', platform: 'any', arch: 'any', targetFolder: 'CoALootDecider', installPath: 'Interface/AddOns', file: `CoALootDecider-v${version}.zip`, source: path.resolve('addons', 'CoALootDecider', '..'), only: 'CoALootDecider' },
  { name: 'CoA Message Center', component: 'message-center', platform: 'any', arch: 'any', targetFolder: 'CoAMessageCenter', installPath: 'Interface/AddOns', file: `CoAMessageCenter-v${version}.zip`, source: path.resolve('addons', 'CoAMessageCenter', '..'), only: 'CoAMessageCenter' },
  { name: 'CoA Rotation Guide', component: 'rotation-guide', platform: 'any', arch: 'any', targetFolder: 'CoARotationGuide', installPath: 'Interface/AddOns', file: `CoARotationGuide-v${version}.zip`, source: path.resolve('addons', 'CoARotationGuide', '..'), only: 'CoARotationGuide' },
  { name: 'CoA Dungeon Navigator', component: 'dungeon-navigator', platform: 'any', arch: 'any', targetFolder: 'CoADungeonNavigator', installPath: 'Interface/AddOns', file: `CoADungeonNavigator-v${version}.zip`, source: path.resolve('addons', 'CoADungeonNavigator', '..'), only: 'CoADungeonNavigator' },
  { name: 'CoA Heretic Helper', component: 'heretic-helper', contentVersion: '3.9.0', platform: 'any', arch: 'any', targetFolder: 'CoAHereticHelper', installPath: 'Interface/AddOns', file: 'CoAHereticHelper-v3.9.0.zip', source: path.resolve('addons', 'CoAHereticHelper', '..'), only: 'CoAHereticHelper' },
  { name: 'Grid - Compatibilité CoA', component: 'grid-compat', platform: 'any', arch: 'any', targetFolder: 'GridCoA', installPath: 'Interface/AddOns', file: `GridCoA-v${version}.zip`, source: path.resolve('addons', 'GridCoA', '..'), only: 'GridCoA' },
  {
    name: 'EventAlert 4.3.6 + compatibilité CoA', component: 'event-alert', platform: 'any', arch: 'any',
    targetFolder: 'EventAlert', installPath: 'Interface/AddOns', file: `EventAlertCoA-v${version}.zip`,
    source: path.resolve('patches', 'EventAlertCoA'),
    upstream: {
      name: 'EventAlert', version: '4.3.6', targetFolder: 'EventAlert', file: 'EventAlert-4.3.6.zip',
      url: 'https://edge.forgecdn.net/files/456/081/EventAlert-4.3.6.zip',
      sha256: '48c529fe42dedae8d7ed779f529e6cb55ba13a1d185b654804080a3bb9e4aa97', size: 27480,
      sourceUrl: 'https://www.curseforge.com/wow/addons/event-alert/files/456081', license: 'All Rights Reserved'
    }
  }
];

const artifacts = [];
for (const item of packages) {
  const packageStage = item.only ? path.join(stage, `addon-${item.component}`) : item.source;
  if (item.only) {
    await mkdir(packageStage, { recursive: true });
    await cp(path.join(item.source, item.only), path.join(packageStage, item.only), { recursive: true });
  }
  const zipFile = path.join(output, item.file);
  await writeZip(packageStage, zipFile);
  const bytes = await readFile(zipFile);
  const digest = createHash('sha256').update(bytes).digest('hex');
  artifacts.push({
    name: item.name, component: item.component, version, platform: item.platform, arch: item.arch,
    targetFolder: item.targetFolder, installPath: item.installPath, file: item.file,
    url: `https://github.com/Cnbz13/coa-tools/releases/download/v${version}/${item.file}`,
    sha256: digest, size: (await stat(zipFile)).size,
    ...(item.contentVersion ? { contentVersion: item.contentVersion } : {}),
    ...(item.upstream ? { upstream: item.upstream } : {})
  });
}

const manifest = {
  $schema: './schemas/manifest.schema.json',
  schemaVersion: 1, name: 'CoA Tools', version, channel: process.env.RELEASE_CHANNEL || 'stable',
  publishedAt: process.env.RELEASE_DATE || '2026-08-24T00:00:00.000Z', minimumNodeVersion: '24.14.0',
  releaseUrl: `https://github.com/Cnbz13/coa-tools/releases/tag/v${version}`, artifacts
};
const manifestText = `${JSON.stringify(manifest, null, 2)}\n`;
await writeFile(path.join(output, 'manifest.json'), manifestText);
await writeFile(path.resolve('manifest.json'), manifestText);
await writeFile(path.join(output, 'SHA256SUMS.txt'), `${artifacts.map(item => `${item.sha256}  ${item.file}`).join('\n')}\n`);
console.log(`Release ${version}: ${artifacts.length} installable ZIP files`);
for (const item of artifacts) console.log(`${item.sha256}  ${item.file}`);
