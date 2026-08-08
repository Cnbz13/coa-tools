import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const version = process.env.RELEASE_VERSION || pkg.version;
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`Invalid release version: ${version}`);

const output = path.resolve('dist');
const stage = path.join(output, 'stage');
await rm(output, { recursive: true, force: true });
await mkdir(stage, { recursive: true });

const crcTable = Array.from({ length: 256 }, (_, index) => {
  let crc = index;
  for (let bit = 0; bit < 8; bit++) crc = (crc & 1) ? (0xedb88320 ^ (crc >>> 1)) : (crc >>> 1);
  return crc >>> 0;
});
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

async function filesIn(directory, prefix = '') {
  const files = [];
  for (const item of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    const absolute = path.join(directory, item.name);
    const relative = path.posix.join(prefix, item.name);
    if (item.isDirectory()) files.push(...await filesIn(absolute, relative));
    else if (item.isFile()) {
      let bytes = await readFile(absolute);
      if (/\.(?:cmd|ps1)$/i.test(item.name)) bytes = Buffer.from(bytes.toString('utf8').replace(/\r?\n/g, '\r\n'), 'utf8');
      files.push({ name: relative, bytes });
    }
  }
  return files;
}

async function writeZip(directory, zipFile) {
  const entries = await filesIn(directory);
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  const dosDate = ((2026 - 1980) << 9) | (1 << 5) | 1;
  for (const entry of entries) {
    const name = Buffer.from(entry.name, 'utf8');
    const checksum = crc32(entry.bytes);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(10, 4); local.writeUInt16LE(0x0800, 6);
    local.writeUInt16LE(0, 8); local.writeUInt16LE(0, 10); local.writeUInt16LE(dosDate, 12);
    local.writeUInt32LE(checksum, 14); local.writeUInt32LE(entry.bytes.length, 18); local.writeUInt32LE(entry.bytes.length, 22);
    local.writeUInt16LE(name.length, 26); local.writeUInt16LE(0, 28);
    localParts.push(local, name, entry.bytes);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0); central.writeUInt16LE(20, 4); central.writeUInt16LE(10, 6);
    central.writeUInt16LE(0x0800, 8); central.writeUInt16LE(0, 10); central.writeUInt16LE(0, 12); central.writeUInt16LE(dosDate, 14);
    central.writeUInt32LE(checksum, 16); central.writeUInt32LE(entry.bytes.length, 20); central.writeUInt32LE(entry.bytes.length, 24);
    central.writeUInt16LE(name.length, 28); central.writeUInt16LE(0, 30); central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34); central.writeUInt16LE(0, 36); central.writeUInt32LE(0, 38); central.writeUInt32LE(offset, 42);
    centralParts.push(central, name);
    offset += local.length + name.length + entry.bytes.length;
  }
  const centralDirectory = Buffer.concat(centralParts);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(0, 4); end.writeUInt16LE(0, 6);
  end.writeUInt16LE(entries.length, 8); end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralDirectory.length, 12); end.writeUInt32LE(offset, 16); end.writeUInt16LE(0, 20);
  await writeFile(zipFile, Buffer.concat([...localParts, centralDirectory, end]));
}

const managerRoot = path.join(stage, 'manager', 'CoAAddonManager');
await mkdir(managerRoot, { recursive: true });
for (const item of ['src', 'public', 'schemas']) await cp(item, path.join(managerRoot, item), { recursive: true });
for (const item of ['LICENSE', 'SECURITY.md']) await cp(item, path.join(managerRoot, item));
await cp('packaging/windows', managerRoot, { recursive: true });
await writeFile(path.join(managerRoot, 'package.json'), `${JSON.stringify({ ...pkg, version }, null, 2)}\n`);

const packages = [
  { name: 'CoA Addon Manager for Windows', component: 'addon-manager', platform: 'win32', arch: 'x64', targetFolder: 'CoAAddonManager', installPath: '.', file: `CoAAddonManager-v${version}-Windows.zip`, source: path.join(stage, 'manager') },
  { name: 'CoA Combat Assistant', component: 'combat-assistant', platform: 'any', arch: 'any', targetFolder: 'CoACombatAssistant', installPath: 'Interface/AddOns', file: `CoACombatAssistant-v${version}.zip`, source: path.resolve('addons', 'CoACombatAssistant', '..') , only: 'CoACombatAssistant' },
  { name: 'CoA UI Manager', component: 'ui-manager', platform: 'any', arch: 'any', targetFolder: 'CoAUIManager', installPath: 'Interface/AddOns', file: `CoAUIManager-v${version}.zip`, source: path.resolve('addons', 'CoAUIManager', '..'), only: 'CoAUIManager' }
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
  artifacts.push({ name: item.name, component: item.component, version, platform: item.platform, arch: item.arch, targetFolder: item.targetFolder, installPath: item.installPath, file: item.file, url: `https://github.com/Cnbz13/coa-tools/releases/download/v${version}/${item.file}`, sha256: digest, size: (await stat(zipFile)).size });
}

const manifest = {
  schemaVersion: 1, name: 'CoA Tools', version, channel: process.env.RELEASE_CHANNEL || 'stable',
  publishedAt: process.env.RELEASE_DATE || '2026-08-09T00:00:00.000Z', minimumNodeVersion: '24.14.0',
  releaseUrl: `https://github.com/Cnbz13/coa-tools/releases/tag/v${version}`, artifacts
};
await writeFile(path.join(output, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
await writeFile(path.join(output, 'SHA256SUMS.txt'), `${artifacts.map(item => `${item.sha256}  ${item.file}`).join('\n')}\n`);
console.log(`Release ${version}: ${artifacts.length} installable ZIP files`);
for (const item of artifacts) console.log(`${item.sha256}  ${item.file}`);
