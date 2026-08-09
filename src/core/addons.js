import { createHash, randomUUID } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { cp, readFile, readdir, rename, rm, stat } from 'node:fs/promises';
import path from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { ensureDir, readJson, writeJsonAtomic } from '../lib/files.js';
import { extractZip } from '../lib/zip.js';

export const ASCENSION_ADDONS = 'C:\\Ascension\\Launcher\\resources\\ascension-live\\Interface\\AddOns';
const MANAGED_COMPONENTS = new Set(['combat-assistant', 'ui-manager', 'event-alert']);

async function isDirectory(directory) {
  try { return (await stat(directory)).isDirectory(); } catch { return false; }
}

function cleanWowText(value = '') {
  return value.trim().replace(/\|c[0-9a-f]{8}/gi, '').replace(/\|r/gi, '');
}

export function parseToc(contents, folder, tocFile = '') {
  const metadata = {};
  for (const match of contents.replace(/^\uFEFF/, '').matchAll(/^##\s*([^:]+):\s*(.*)$/gm)) {
    const key = match[1].trim().toLowerCase();
    if (!(key in metadata)) metadata[key] = match[2].trim();
  }
  return {
    folder,
    title: cleanWowText(metadata.title) || folder,
    version: cleanWowText(metadata.version) || 'inconnue',
    notes: cleanWowText(metadata.notes),
    tocFile: tocFile || `${folder}.toc`
  };
}

function versionParts(value) {
  const match = String(value || '').match(/\d+(?:\.\d+){0,3}/);
  return match ? match[0].split('.').map(Number) : [0];
}

export function compareAddonVersions(left, right) {
  const a = versionParts(left), b = versionParts(right);
  const length = Math.max(a.length, b.length, 3);
  for (let index = 0; index < length; index++) if ((a[index] || 0) !== (b[index] || 0)) return (a[index] || 0) - (b[index] || 0);
  return 0;
}

export class AddonManager {
  constructor({ dataDir, manifestUrl, canonicalPath = ASCENSION_ADDONS, candidates = [], environmentPath = process.env.COA_ADDONS_DIR, downloadPolicy } = {}) {
    if (!dataDir) throw new Error('dataDir is required');
    this.dataDir = path.resolve(dataDir);
    this.manifestUrl = manifestUrl;
    this.canonicalPath = path.resolve(canonicalPath);
    this.environmentPath = environmentPath ? path.resolve(environmentPath) : null;
    this.candidates = candidates.map(item => path.resolve(item));
    this.settingsFile = path.join(this.dataDir, 'addon-settings.json');
    this.cachedManifestFile = path.join(this.dataDir, 'remote-manifest.json');
    this.backupsRoot = path.join(this.dataDir, 'backups');
    this.transactionsRoot = path.join(this.dataDir, 'transactions');
    this.downloadPolicy = downloadPolicy || (url => url.protocol === 'https:' && url.hostname === 'github.com');
    this.operation = Promise.resolve();
  }

  async detectDirectory() {
    const settings = await readJson(this.settingsFile, {});
    const standard = [
      this.canonicalPath,
      settings.addonsDir,
      this.environmentPath,
      ...this.candidates,
      'C:\\Program Files\\Ascension Launcher\\resources\\ascension-live\\Interface\\AddOns',
      'C:\\Program Files (x86)\\Ascension Launcher\\resources\\ascension-live\\Interface\\AddOns'
    ].filter(Boolean).map(item => path.resolve(item));
    const unique = [...new Set(standard.map(item => item.toLowerCase()))];
    for (const lower of unique) {
      const directory = standard.find(item => item.toLowerCase() === lower);
      if (await isDirectory(directory)) {
        const source = directory.toLowerCase() === this.canonicalPath.toLowerCase() ? 'project-ascension' : directory === settings.addonsDir ? 'saved' : directory === this.environmentPath ? 'environment' : 'detected';
        return { directory, exists: true, source };
      }
    }
    return { directory: settings.addonsDir || this.canonicalPath, exists: false, source: 'missing' };
  }

  async setDirectory(directory) {
    const selected = String(directory || '').trim();
    if (!selected) throw new Error('Sélectionnez un dossier Interface\\AddOns');
    const resolved = path.resolve(selected);
    if (!(await isDirectory(resolved))) throw new Error('Le dossier AddOns sélectionné est introuvable');
    await writeJsonAtomic(this.settingsFile, { addonsDir: resolved, savedAt: new Date().toISOString() });
    return this.inventory();
  }

  async scan(directory) {
    if (!(await isDirectory(directory))) return [];
    const addons = [];
    for (const entry of (await readdir(directory, { withFileTypes: true })).filter(item => item.isDirectory()).sort((a, b) => a.name.localeCompare(b.name))) {
      try {
        const folder = path.join(directory, entry.name);
        const tocFiles = (await readdir(folder, { withFileTypes: true })).filter(item => item.isFile() && item.name.toLowerCase().endsWith('.toc'));
        if (!tocFiles.length) continue;
        const toc = tocFiles.find(item => item.name.toLowerCase() === `${entry.name}.toc`.toLowerCase()) || tocFiles[0];
        const bytes = await readFile(path.join(folder, toc.name));
        let contents = bytes.toString('utf8');
        if (contents.includes('\uFFFD')) contents = new TextDecoder('windows-1252').decode(bytes);
        const parsed = parseToc(contents, entry.name, toc.name);
        addons.push({ ...parsed, path: folder });
      } catch { /* Ignore one unreadable addon without hiding the rest. */ }
    }
    return addons;
  }

  async getManifest() {
    try {
      const response = await fetch(this.manifestUrl, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(15000) });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const manifest = await response.json();
      if (!Array.isArray(manifest.artifacts)) throw new Error('Manifest invalide');
      await writeJsonAtomic(this.cachedManifestFile, manifest);
      return { manifest, cached: false, error: null };
    } catch (error) {
      const cached = await readJson(this.cachedManifestFile, null);
      if (cached) return { manifest: cached, cached: true, error: error.message };
      return { manifest: null, cached: false, error: error.message };
    }
  }

  async listBackups(component) {
    const directory = path.join(this.backupsRoot, component);
    if (!(await isDirectory(directory))) return [];
    const backups = [];
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const metadata = await readJson(path.join(directory, entry.name, 'backup.json'), null);
      if (metadata) backups.push({ ...metadata, id: entry.name });
    }
    return backups.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  async inventory() {
    const detection = await this.detectDirectory();
    const local = detection.exists ? await this.scan(detection.directory) : [];
    const { manifest, cached, error } = await this.getManifest();
    const managedArtifacts = (manifest?.artifacts || []).filter(item => MANAGED_COMPONENTS.has(item.component));
    const managedFolders = new Set(managedArtifacts.map(item => item.targetFolder.toLowerCase()));
    const managed = [];
    for (const artifact of managedArtifacts) {
      const installed = local.find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase()) || null;
      const comparison = installed ? compareAddonVersions(artifact.version, installed.version) : 1;
      const backups = await this.listBackups(artifact.component);
      managed.push({
        kind: 'managed', component: artifact.component, name: artifact.name, folder: artifact.targetFolder,
        title: installed?.title || artifact.name, notes: installed?.notes || '', localVersion: installed?.version || null,
        remoteVersion: artifact.version, installed: Boolean(installed), action: !installed ? 'install' : comparison > 0 ? 'update' : 'reinstall',
        artifact: { file: artifact.file, size: artifact.size, sha256: artifact.sha256 }, canRollback: backups.length > 0,
        latestBackup: backups[0] || null
      });
    }
    const regular = local.filter(item => !managedFolders.has(item.folder.toLowerCase())).map(item => ({ ...item, kind: 'ascension' }));
    return {
      addonsDir: detection.directory, exists: detection.exists, detectionSource: detection.source,
      scannedAt: new Date().toISOString(), localCount: local.length, regular, managed,
      remoteVersion: manifest?.version || null, remoteCached: cached, remoteError: error
    };
  }

  async download(artifact, destination) {
    if (!artifact || !/^[a-f0-9]{64}$/.test(artifact.sha256 || '') || !Number.isInteger(artifact.size)) throw new Error('Métadonnées de téléchargement invalides');
    const url = new URL(artifact.url);
    if (!this.downloadPolicy(url)) throw new Error('URL de téléchargement non approuvée');
    const response = await fetch(url, { signal: AbortSignal.timeout(120000) });
    if (!response.ok || !response.body) throw new Error(`Téléchargement impossible (HTTP ${response.status})`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(destination));
    const bytes = await readFile(destination);
    const digest = createHash('sha256').update(bytes).digest('hex');
    if (digest !== artifact.sha256) throw new Error('Échec de la vérification SHA-256');
    if (bytes.length !== artifact.size) throw new Error('La taille téléchargée ne correspond pas au manifeste');
  }

  async createBackup(component, targetFolder, source, version, reason = 'replace') {
    if (!(await isDirectory(source))) return null;
    const id = `${Date.now()}-${randomUUID().slice(0, 8)}`;
    const root = path.join(this.backupsRoot, component, id);
    const backupFolder = path.join(root, targetFolder);
    await ensureDir(root);
    await cp(source, backupFolder, { recursive: true, force: true });
    const metadata = { component, targetFolder, version: version || 'inconnue', reason, createdAt: new Date().toISOString() };
    await writeJsonAtomic(path.join(root, 'backup.json'), metadata);
    return { id, root, folder: backupFolder, ...metadata };
  }

  async replaceFolder(addonsDir, targetFolder, sourceFolder) {
    if (!/^[A-Za-z0-9._-]+$/.test(targetFolder)) throw new Error('Nom de dossier cible invalide');
    const destination = path.join(addonsDir, targetFolder);
    const temporary = path.join(addonsDir, `.coa-install-${targetFolder}-${randomUUID().slice(0, 8)}`);
    await rm(temporary, { recursive: true, force: true });
    await cp(sourceFolder, temporary, { recursive: true, force: true });
    await this.assertToc(temporary, targetFolder);
    await rm(destination, { recursive: true, force: true });
    await rename(temporary, destination);
    await this.assertToc(destination, targetFolder);
    return destination;
  }

  async assertToc(directory, targetFolder) {
    if (!(await isDirectory(directory))) throw new Error(`Dossier cible absent : ${targetFolder}`);
    const toc = (await readdir(directory, { withFileTypes: true })).find(item => item.isFile() && item.name.toLowerCase().endsWith('.toc'));
    if (!toc) throw new Error(`Installation invalide : aucun .toc dans ${targetFolder}`);
    return toc.name;
  }

  runExclusive(task) {
    const result = this.operation.then(task, task);
    this.operation = result.catch(() => {});
    return result;
  }

  install(component) { return this.runExclusive(() => this.installNow(component)); }
  async installNow(component) {
    if (!MANAGED_COMPONENTS.has(component)) throw new Error('Composant CoA inconnu');
    const detection = await this.detectDirectory();
    if (!detection.exists) throw new Error('Aucun dossier Project Ascension AddOns détecté');
    const { manifest } = await this.getManifest();
    const artifact = manifest?.artifacts?.find(item => item.component === component);
    if (!artifact) throw new Error('Artefact distant introuvable dans le manifeste');
    if (!/^[A-Za-z0-9._-]+$/.test(artifact.targetFolder || '')) throw new Error('Nom de dossier cible invalide');
    const local = (await this.scan(detection.directory)).find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase());
    const transaction = path.join(this.transactionsRoot, randomUUID());
    const archive = path.join(transaction, path.basename(artifact.file));
    const extracted = path.join(transaction, 'extracted');
    await ensureDir(transaction);
    let backup = null;
    try {
      await this.download(artifact, archive);
      await extractZip(archive, extracted);
      const extractedFolder = path.join(extracted, artifact.targetFolder);
      await this.assertToc(extractedFolder, artifact.targetFolder);
      const destination = path.join(detection.directory, artifact.targetFolder);
      backup = await this.createBackup(component, artifact.targetFolder, destination, local?.version);
      try { await this.replaceFolder(detection.directory, artifact.targetFolder, extractedFolder); }
      catch (error) {
        if (backup) await this.replaceFolder(detection.directory, artifact.targetFolder, backup.folder);
        throw error;
      }
      return { operation: local ? 'replaced' : 'installed', component, version: artifact.version, backup: backup?.id || null, inventory: await this.inventory() };
    } finally { await rm(transaction, { recursive: true, force: true }); }
  }

  rollback(component, backupId) { return this.runExclusive(() => this.rollbackNow(component, backupId)); }
  async rollbackNow(component, backupId) {
    if (!MANAGED_COMPONENTS.has(component)) throw new Error('Composant CoA inconnu');
    const detection = await this.detectDirectory();
    if (!detection.exists) throw new Error('Aucun dossier Project Ascension AddOns détecté');
    const backups = await this.listBackups(component);
    const selected = backupId ? backups.find(item => item.id === backupId) : backups[0];
    if (!selected) throw new Error('Aucun backup disponible');
    const source = path.join(this.backupsRoot, component, selected.id, selected.targetFolder);
    await this.assertToc(source, selected.targetFolder);
    const current = path.join(detection.directory, selected.targetFolder);
    const local = (await this.scan(detection.directory)).find(item => item.folder.toLowerCase() === selected.targetFolder.toLowerCase());
    await this.createBackup(component, selected.targetFolder, current, local?.version, 'pre-rollback');
    await this.replaceFolder(detection.directory, selected.targetFolder, source);
    return { operation: 'restored', component, backup: selected.id, inventory: await this.inventory() };
  }

  updateAll() { return this.runExclusive(async () => {
    const current = await this.inventory();
    const components = current.managed.filter(item => ['install', 'update'].includes(item.action)).map(item => item.component);
    const results = [];
    for (const component of components) results.push(await this.installNow(component));
    return { operation: 'update-all', updated: components, results, inventory: await this.inventory() };
  }); }
}
