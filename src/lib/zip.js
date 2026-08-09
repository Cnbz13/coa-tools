import { readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { inflateRawSync } from 'node:zlib';
import { ensureDir } from './files.js';

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
      if (/\.(?:cmd|ps1|txt|json|js|mjs|css|html|md|lua|toc)$/i.test(item.name)) {
        const text = bytes.toString('utf8').replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');
        bytes = Buffer.from(/\.(?:cmd|ps1)$/i.test(item.name) ? text.replace(/\n/g, '\r\n') : text, 'utf8');
        if (/\.ps1$/i.test(item.name)) bytes = Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), bytes]);
      }
      files.push({ name: relative, bytes });
    }
  }
  return files;
}

export async function writeZip(directory, zipFile) {
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

function safeTarget(destination, archiveName) {
  const normalized = archiveName.replaceAll('\\', '/');
  const parts = normalized.split('/').filter(Boolean);
  if (!parts.length || normalized.startsWith('/') || parts.some(part => part === '..' || part.includes(':'))) throw new Error(`Unsafe ZIP entry: ${archiveName}`);
  const root = path.resolve(destination);
  const target = path.resolve(root, ...parts);
  if (target !== root && !target.startsWith(`${root}${path.sep}`)) throw new Error(`Unsafe ZIP entry: ${archiveName}`);
  return target;
}

export async function extractZip(zipFile, destination) {
  const archive = await readFile(zipFile);
  await ensureDir(destination);
  let offset = 0;
  let extracted = 0;
  while (offset + 4 <= archive.length) {
    const signature = archive.readUInt32LE(offset);
    if (signature === 0x02014b50 || signature === 0x06054b50) break;
    if (signature !== 0x04034b50 || offset + 30 > archive.length) throw new Error('Invalid ZIP structure');
    const flags = archive.readUInt16LE(offset + 6);
    const method = archive.readUInt16LE(offset + 8);
    const checksum = archive.readUInt32LE(offset + 14);
    const compressedSize = archive.readUInt32LE(offset + 18);
    const size = archive.readUInt32LE(offset + 22);
    const nameLength = archive.readUInt16LE(offset + 26);
    const extraLength = archive.readUInt16LE(offset + 28);
    if (flags & 0x08) throw new Error('ZIP data descriptors are not supported');
    if (![0, 8].includes(method)) throw new Error(`Unsupported ZIP compression method: ${method}`);
    const nameStart = offset + 30;
    const dataStart = nameStart + nameLength + extraLength;
    const dataEnd = dataStart + compressedSize;
    if (dataEnd > archive.length) throw new Error('Truncated ZIP entry');
    const name = archive.subarray(nameStart, nameStart + nameLength).toString('utf8');
    const target = safeTarget(destination, name);
    const compressed = archive.subarray(dataStart, dataEnd);
    const bytes = method === 0 ? Buffer.from(compressed) : inflateRawSync(compressed);
    if (bytes.length !== size || crc32(bytes) !== checksum) throw new Error(`Corrupt ZIP entry: ${name}`);
    if (name.endsWith('/') || name.endsWith('\\')) await ensureDir(target);
    else { await ensureDir(path.dirname(target)); await writeFile(target, bytes); extracted++; }
    offset = dataEnd;
  }
  if (!extracted) throw new Error('ZIP archive contains no files');
  return extracted;
}
