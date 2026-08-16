import { createHash } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { readFile, rename, rm, stat } from 'node:fs/promises';
import path from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { ensureDir, readJson, writeJsonAtomic } from '../lib/files.js';

export function compareVersions(a, b) {
  const parse = value => value.split('-')[0].split('.').map(Number);
  const left = parse(a), right = parse(b);
  for (let index = 0; index < 3; index++) if ((left[index] || 0) !== (right[index] || 0)) return (left[index] || 0) - (right[index] || 0);
  return 0;
}

export async function sha256(file) {
  return createHash('sha256').update(await readFile(file)).digest('hex');
}

export class Updater {
  constructor({ currentVersion, manifestUrl, stagingDir }) {
    Object.assign(this, { currentVersion, manifestUrl, stagingDir });
    this.downloadOperation = Promise.resolve();
  }
  async check() {
    const response = await fetch(this.manifestUrl, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new Error(`Manifest request failed (${response.status})`);
    const manifest = await response.json();
    const available = compareVersions(manifest.version, this.currentVersion) > 0;
    const artifact = manifest.artifacts.find(item => item.component === 'addon-manager' && (item.platform === process.platform || item.platform === 'any') && (item.arch === process.arch || item.arch === 'any'));
    return { available, currentVersion: this.currentVersion, manifest, artifact: artifact || null };
  }
  async downloadLatest() {
    const update = await this.check();
    if (!update.available) throw new Error('No update available');
    if (!update.artifact) throw new Error('No compatible artifact');
    return this.download(update.artifact);
  }
  async ready(version = null) {
    const metadata = await readJson(path.join(this.stagingDir, 'ready.json'), null);
    if (!metadata || (version && metadata.version !== version)) return null;
    try {
      const file = path.resolve(metadata.file);
      const prefix = `${path.resolve(this.stagingDir)}${path.sep}`;
      if (!file.startsWith(prefix) || (await stat(file)).size !== metadata.size || await sha256(file) !== metadata.sha256) return null;
      return { ...metadata, file };
    } catch { return null; }
  }
  download(artifact) {
    const result = this.downloadOperation.then(() => this.downloadNow(artifact));
    this.downloadOperation = result.catch(() => {});
    return result;
  }
  async downloadNow(artifact) {
    if (!artifact?.url || !/^[a-f0-9]{64}$/.test(artifact.sha256)) throw new Error('Invalid artifact metadata');
    await ensureDir(this.stagingDir);
    const finalFile = path.join(this.stagingDir, path.basename(artifact.file));
    const temporary = `${finalFile}.part`;
    await rm(temporary, { force: true });
    const response = await fetch(artifact.url, { signal: AbortSignal.timeout(120000) });
    if (!response.ok || !response.body) throw new Error(`Artifact request failed (${response.status})`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(temporary));
    const actual = await sha256(temporary);
    if (actual !== artifact.sha256) { await rm(temporary, { force: true }); throw new Error('SHA-256 verification failed'); }
    if ((await stat(temporary)).size !== artifact.size) { await rm(temporary, { force: true }); throw new Error('Artifact size mismatch'); }
    await rename(temporary, finalFile);
    await writeJsonAtomic(path.join(this.stagingDir, 'ready.json'), {
      component: artifact.component || 'addon-manager', version: artifact.version || null,
      file: finalFile, sha256: actual, size: artifact.size, verifiedAt: new Date().toISOString()
    });
    return { ready: true, version: artifact.version || null, file: finalFile, sha256: actual };
  }
}
