import { createHash, randomUUID } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { cp, readFile, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { ensureDir, readJson, writeJsonAtomic } from '../lib/files.js';
import { extractZip } from '../lib/zip.js';

export const ASCENSION_ADDONS = 'C:\\Ascension\\Launcher\\resources\\ascension-live\\Interface\\AddOns';
const MANAGED_COMPONENTS = new Set(['combat-assistant', 'ui-manager', 'loot-decider', 'message-center', 'event-alert', 'grid-compat']);
const EVENT_ALERT_COMPANION_FOLDER = 'EventAlertCoA';
const EVENT_ALERT_LEGACY_FOLDER = 'CoAEventAlert';
const EVENT_ALERT_UPSTREAM_PATH = '/files/456/081/EventAlert-4.3.6.zip';
const EVENT_ALERT_UPSTREAM_URL = `https://edge.forgecdn.net${EVENT_ALERT_UPSTREAM_PATH}`;
const EVENT_ALERT_UPSTREAM_SHA256 = '48c529fe42dedae8d7ed779f529e6cb55ba13a1d185b654804080a3bb9e4aa97';
const EVENT_ALERT_UPSTREAM_SIZE = 27480;

function defaultDownloadPolicy(url) {
  return url.protocol === 'https:' && (
    url.hostname === 'github.com'
    || (url.hostname === 'edge.forgecdn.net' && url.pathname === EVENT_ALERT_UPSTREAM_PATH)
  );
}

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
    coaCompatibilityVersion: cleanWowText(metadata['x-coa-compatibility-version']),
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
    this.strictOfficialSources = !downloadPolicy;
    this.downloadPolicy = downloadPolicy || defaultDownloadPolicy;
    this.operation = Promise.resolve();
  }

  async detectDirectory() {
    const settings = await readJson(this.settingsFile, {});
    const standard = [
      settings.addonsDir,
      this.environmentPath,
      this.canonicalPath,
      ...this.candidates,
      'C:\\Program Files\\Ascension Launcher\\resources\\ascension-live\\Interface\\AddOns',
      'C:\\Program Files (x86)\\Ascension Launcher\\resources\\ascension-live\\Interface\\AddOns'
    ].filter(Boolean).map(item => path.resolve(item));
    const unique = [...new Set(standard.map(item => item.toLowerCase()))];
    for (const lower of unique) {
      const directory = standard.find(item => item.toLowerCase() === lower);
      if (await isDirectory(directory)) {
        const source = directory === settings.addonsDir ? 'saved' : directory === this.environmentPath ? 'environment' : directory.toLowerCase() === this.canonicalPath.toLowerCase() ? 'project-ascension' : 'detected';
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
    if (managedArtifacts.some(item => item.component === 'event-alert')) {
      managedFolders.add(EVENT_ALERT_COMPANION_FOLDER.toLowerCase());
      managedFolders.add(EVENT_ALERT_LEGACY_FOLDER.toLowerCase());
    }
    const managed = [];
    for (const artifact of managedArtifacts) {
      const targetInstalled = local.find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase()) || null;
      const companionInstalled = artifact.component === 'event-alert'
        ? local.find(item => item.folder.toLowerCase() === EVENT_ALERT_COMPANION_FOLDER.toLowerCase()) || null
        : null;
      const installed = artifact.component === 'event-alert'
        ? targetInstalled && companionInstalled ? targetInstalled : null
        : targetInstalled;
      const localVersion = artifact.component === 'event-alert'
        ? installed ? companionInstalled.version : null
        : installed?.version || null;
      const comparison = installed ? compareAddonVersions(artifact.version, localVersion) : 1;
      const backups = await this.listBackups(artifact.component);
      managed.push({
        kind: 'managed', component: artifact.component, name: artifact.name, folder: artifact.targetFolder,
        title: installed?.title || artifact.name, notes: installed?.notes || '', localVersion,
        remoteVersion: artifact.version, installed: Boolean(installed), action: !installed ? 'install' : comparison > 0 ? 'update' : 'reinstall',
        artifact: { file: artifact.file, size: artifact.size, sha256: artifact.sha256, upstream: artifact.upstream || null }, canRollback: backups.length > 0,
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

  async download(artifact, destination, onProgress = null) {
    if (!artifact || !/^[a-f0-9]{64}$/.test(artifact.sha256 || '') || !Number.isInteger(artifact.size)) throw new Error('Métadonnées de téléchargement invalides');
    const url = new URL(artifact.url);
    if (!this.downloadPolicy(url)) throw new Error('URL de téléchargement non approuvée');
    let response;
    try {
      response = await fetch(url, { signal: AbortSignal.timeout(120000) });
    } catch (error) {
      if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
        throw new Error(`Délai réseau dépassé après 2 minutes pour ${artifact.file}`);
      }
      throw error;
    }
    if (!response.ok || !response.body) throw new Error(`Téléchargement impossible (HTTP ${response.status})`);
    let received = 0;
    const meter = new Transform({
      transform(chunk, encoding, callback) {
        received += chunk.length;
        if (onProgress) onProgress(received, artifact.size);
        callback(null, chunk);
      }
    });
    if (onProgress) onProgress(0, artifact.size);
    await pipeline(Readable.fromWeb(response.body), meter, createWriteStream(destination));
    const bytes = await readFile(destination);
    const digest = createHash('sha256').update(bytes).digest('hex');
    if (digest !== artifact.sha256) throw new Error('Échec de la vérification SHA-256');
    if (bytes.length !== artifact.size) throw new Error('La taille téléchargée ne correspond pas au manifeste');
  }

  async createBackup(component, targetFolder, source, version, reason = 'replace') {
    return this.createBackupSet(component, [{ targetFolder, source, version }], version, reason);
  }

  async createBackupSet(component, candidates, version, reason = 'replace') {
    const folders = [];
    for (const candidate of candidates) {
      if (await isDirectory(candidate.source)) folders.push(candidate);
    }
    if (!folders.length) return null;
    const id = `${Date.now()}-${randomUUID().slice(0, 8)}`;
    const root = path.join(this.backupsRoot, component, id);
    await ensureDir(root);
    for (const folder of folders) await cp(folder.source, path.join(root, folder.targetFolder), { recursive: true, force: true });
    const metadata = {
      component, targetFolder: folders[0].targetFolder, version: version || folders[0].version || 'inconnue', reason,
      folders: folders.map(folder => ({ targetFolder: folder.targetFolder, version: folder.version || 'inconnue' })),
      createdAt: new Date().toISOString()
    };
    await writeJsonAtomic(path.join(root, 'backup.json'), metadata);
    return { id, root, folder: path.join(root, folders[0].targetFolder), ...metadata };
  }

  backupFolders(backup) {
    return Array.isArray(backup.folders) && backup.folders.length
      ? backup.folders
      : [{ targetFolder: backup.targetFolder, version: backup.version }];
  }

  async restoreBackupSet(addonsDir, backup, removeFolders = []) {
    for (const targetFolder of removeFolders) await rm(path.join(addonsDir, targetFolder), { recursive: true, force: true });
    for (const folder of this.backupFolders(backup)) {
      const source = path.join(this.backupsRoot, backup.component, backup.id, folder.targetFolder);
      await this.assertToc(source, folder.targetFolder);
      await this.replaceFolder(addonsDir, folder.targetFolder, source);
    }
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

  async enableAddonForProfiles(addonsDir, addonFolder) {
    const accountRoot = path.resolve(addonsDir, '..', '..', 'WTF', 'Account');
    if (!(await isDirectory(accountRoot))) return 0;
    const addonLine = `${addonFolder}: enabled`;
    const entryPattern = new RegExp(`^${addonFolder}:\\s*(?:enabled|disabled)\\s*$`, 'mi');
    let updated = 0;
    const visit = async directory => {
      for (const entry of await readdir(directory, { withFileTypes: true })) {
        const item = path.join(directory, entry.name);
        if (entry.isDirectory()) await visit(item);
        else if (entry.isFile() && entry.name.toLowerCase() === 'addons.txt') {
          try {
            const current = await readFile(item, 'utf8');
            const next = entryPattern.test(current)
              ? current.replace(entryPattern, addonLine)
              : `${current}${current && !/\r?\n$/.test(current) ? '\r\n' : ''}${addonLine}\r\n`;
            if (next !== current) { await writeFile(item, next); updated++; }
          } catch { /* A locked character profile must not invalidate the addon installation. */ }
        }
      }
    };
    await visit(accountRoot);
    return updated;
  }

  runExclusive(task) {
    const result = this.operation.then(task, task);
    this.operation = result.catch(() => {});
    return result;
  }

  install(component, onProgress) { return this.runExclusive(() => this.installNow(component, onProgress)); }
  async installNow(component, onProgress = null, includeInventory = true) {
    const report = update => { if (onProgress) onProgress({ component, ...update }); };
    report({ step: 'detect', message: 'Détection du dossier Project Ascension…', phasePercent: 2 });
    if (!MANAGED_COMPONENTS.has(component)) throw new Error('Composant CoA inconnu');
    const detection = await this.detectDirectory();
    if (!detection.exists) throw new Error('Aucun dossier Project Ascension AddOns détecté');
    report({ step: 'manifest', message: 'Lecture du manifeste GitHub…', phasePercent: 5 });
    const { manifest } = await this.getManifest();
    const artifact = manifest?.artifacts?.find(item => item.component === component);
    if (!artifact) throw new Error('Artefact distant introuvable dans le manifeste');
    if (component === 'event-alert') return this.installEventAlert(detection, artifact, onProgress, includeInventory);
    if (!/^[A-Za-z0-9._-]+$/.test(artifact.targetFolder || '')) throw new Error('Nom de dossier cible invalide');
    if (component === 'grid-compat' && !(await isDirectory(path.join(detection.directory, 'Grid')))) {
      throw new Error('Grid doit être installé avant sa compatibilité CoA');
    }
    const local = (await this.scan(detection.directory)).find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase());
    const transaction = path.join(this.transactionsRoot, randomUUID());
    const archive = path.join(transaction, path.basename(artifact.file));
    const extracted = path.join(transaction, 'extracted');
    await ensureDir(transaction);
    let backup = null;
    try {
      report({ step: 'download', message: `Téléchargement de ${artifact.file}…`, phasePercent: 10, bytesDone: 0, bytesTotal: artifact.size });
      await this.download(artifact, archive, (bytesDone, bytesTotal) => report({
        step: 'download', message: `Téléchargement de ${artifact.file}…`,
        phasePercent: 10 + (bytesTotal ? bytesDone / bytesTotal * 42 : 0), bytesDone, bytesTotal
      }));
      report({ step: 'checksum', message: 'Archive téléchargée et SHA-256 vérifié', phasePercent: 54 });
      report({ step: 'extract', message: 'Extraction sécurisée de l’archive…', phasePercent: 58 });
      await extractZip(archive, extracted);
      const extractedFolder = path.join(extracted, artifact.targetFolder);
      report({ step: 'validate', message: `Validation du dossier ${artifact.targetFolder} et de son fichier .toc…`, phasePercent: 66 });
      await this.assertToc(extractedFolder, artifact.targetFolder);
      const destination = path.join(detection.directory, artifact.targetFolder);
      report({ step: 'backup', message: local ? `Backup de ${artifact.targetFolder}…` : 'Aucune version précédente à sauvegarder', phasePercent: 74 });
      backup = await this.createBackup(component, artifact.targetFolder, destination, local?.version);
      report({ step: 'install', message: `Installation de ${artifact.targetFolder}…`, phasePercent: 82 });
      try { await this.replaceFolder(detection.directory, artifact.targetFolder, extractedFolder); }
      catch (error) {
        report({ step: 'restore', message: 'Échec détecté, restauration automatique du backup…', phasePercent: 84 });
        if (backup) await this.replaceFolder(detection.directory, artifact.targetFolder, backup.folder);
        throw error;
      }
      report({ step: 'enable', message: 'Activation dans les profils Ascension…', phasePercent: 91 });
      let enabledProfiles = await this.enableAddonForProfiles(detection.directory, artifact.targetFolder);
      if (component === 'grid-compat') enabledProfiles += await this.enableAddonForProfiles(detection.directory, 'Grid');
      report({ step: 'rescan', message: 'Contrôle final de l’installation…', phasePercent: 96 });
      const inventory = includeInventory ? await this.inventory() : null;
      report({ step: 'complete', message: `${artifact.name} v${artifact.version} est prêt`, phasePercent: 100 });
      return { operation: local ? 'replaced' : 'installed', component, version: artifact.version, enabledProfiles, backup: backup?.id || null, inventory };
    } finally { await rm(transaction, { recursive: true, force: true }); }
  }

  async installEventAlert(detection, artifact, onProgress = null, includeInventory = true) {
    const report = update => { if (onProgress) onProgress({ component: 'event-alert', ...update }); };
    const upstream = artifact.upstream;
    if (!upstream || upstream.targetFolder !== 'EventAlert' || upstream.version !== '4.3.6') throw new Error('Métadonnées EventAlert officielles invalides');
    if (this.strictOfficialSources && (
      upstream.url !== EVENT_ALERT_UPSTREAM_URL || upstream.sha256 !== EVENT_ALERT_UPSTREAM_SHA256 || upstream.size !== EVENT_ALERT_UPSTREAM_SIZE
    )) throw new Error('Source officielle EventAlert modifiée ou non approuvée');
    if (!/^[A-Za-z0-9._-]+$/.test(artifact.targetFolder || '') || artifact.targetFolder !== 'EventAlert') throw new Error('Nom de dossier EventAlert invalide');
    const local = await this.scan(detection.directory);
    const eventAlert = local.find(item => item.folder.toLowerCase() === 'eventalert');
    const companion = local.find(item => item.folder.toLowerCase() === EVENT_ALERT_COMPANION_FOLDER.toLowerCase());
    const legacy = local.find(item => item.folder.toLowerCase() === EVENT_ALERT_LEGACY_FOLDER.toLowerCase());
    const transaction = path.join(this.transactionsRoot, randomUUID());
    const upstreamArchive = path.join(transaction, path.basename(upstream.file));
    const patchArchive = path.join(transaction, path.basename(artifact.file));
    const upstreamExtracted = path.join(transaction, 'upstream');
    const patchExtracted = path.join(transaction, 'patch');
    await ensureDir(transaction);
    let backup = null;
    try {
      const totalBytes = upstream.size + artifact.size;
      report({ step: 'download', message: 'Téléchargement de la source officielle EventAlert…', phasePercent: 10, bytesDone: 0, bytesTotal: totalBytes });
      await this.download(upstream, upstreamArchive, bytesDone => report({
        step: 'download', message: 'Téléchargement de la source officielle EventAlert…',
        phasePercent: 10 + bytesDone / totalBytes * 42, bytesDone, bytesTotal: totalBytes
      }));
      report({ step: 'download', message: 'Téléchargement de la compatibilité EventAlert CoA…', phasePercent: 10 + upstream.size / totalBytes * 42, bytesDone: upstream.size, bytesTotal: totalBytes });
      await this.download(artifact, patchArchive, bytesDone => report({
        step: 'download', message: 'Téléchargement de la compatibilité EventAlert CoA…',
        phasePercent: 10 + (upstream.size + bytesDone) / totalBytes * 42,
        bytesDone: upstream.size + bytesDone, bytesTotal: totalBytes
      }));
      report({ step: 'checksum', message: 'Archives EventAlert vérifiées par SHA-256', phasePercent: 54 });
      report({ step: 'extract', message: 'Extraction de la source officielle EventAlert…', phasePercent: 58 });
      await extractZip(upstreamArchive, upstreamExtracted);
      report({ step: 'extract', message: 'Extraction de la compatibilité CoA…', phasePercent: 62 });
      await extractZip(patchArchive, patchExtracted);
      const prepared = path.join(upstreamExtracted, upstream.targetFolder);
      report({ step: 'validate', message: 'Validation des fichiers EventAlert et de leur compatibilité…', phasePercent: 68 });
      await this.assertToc(prepared, upstream.targetFolder);
      const compatibilityFolder = path.join(patchExtracted, EVENT_ALERT_COMPANION_FOLDER);
      const compatibilityFile = path.join(compatibilityFolder, 'EventAlertCoA.lua');
      const compatibilityToc = path.join(compatibilityFolder, 'EventAlertCoA.toc');
      if ((await stat(compatibilityFile)).size < 1) throw new Error('Patch EventAlert CoA vide');
      await this.assertToc(compatibilityFolder, EVENT_ALERT_COMPANION_FOLDER);
      const toc = await readFile(compatibilityToc, 'utf8');
      if (!/^## (?:RequiredDeps|Dependencies): EventAlert$/m.test(toc)) throw new Error('Dépendance EventAlert manquante dans le correctif CoA');
      if (!new RegExp(`^## Version: ${artifact.version.replaceAll('.', '\\.')}$`, 'm').test(toc)) throw new Error('Version du correctif EventAlert CoA incohérente');
      report({ step: 'backup', message: 'Backup d’EventAlert et de sa compatibilité…', phasePercent: 76 });
      backup = await this.createBackupSet('event-alert', [
        { targetFolder: 'EventAlert', source: path.join(detection.directory, 'EventAlert'), version: eventAlert?.version },
        { targetFolder: EVENT_ALERT_COMPANION_FOLDER, source: path.join(detection.directory, EVENT_ALERT_COMPANION_FOLDER), version: companion?.version },
        { targetFolder: EVENT_ALERT_LEGACY_FOLDER, source: path.join(detection.directory, EVENT_ALERT_LEGACY_FOLDER), version: legacy?.version }
      ], companion?.version || eventAlert?.version);
      let enabledProfiles = 0;
      try {
        report({ step: 'install', message: 'Installation de la source officielle EventAlert…', phasePercent: 83 });
        await this.replaceFolder(detection.directory, 'EventAlert', prepared);
        report({ step: 'install', message: 'Installation de la compatibilité EventAlert CoA…', phasePercent: 88 });
        await this.replaceFolder(detection.directory, EVENT_ALERT_COMPANION_FOLDER, compatibilityFolder);
        await rm(path.join(detection.directory, EVENT_ALERT_LEGACY_FOLDER), { recursive: true, force: true });
        report({ step: 'enable', message: 'Activation d’EventAlert dans les profils Ascension…', phasePercent: 93 });
        enabledProfiles = await this.enableAddonForProfiles(detection.directory, EVENT_ALERT_COMPANION_FOLDER);
      } catch (error) {
        report({ step: 'restore', message: 'Échec détecté, restauration automatique d’EventAlert…', phasePercent: 94 });
        if (backup) await this.restoreBackupSet(detection.directory, backup, ['EventAlert', EVENT_ALERT_COMPANION_FOLDER, EVENT_ALERT_LEGACY_FOLDER]);
        throw error;
      }
      report({ step: 'rescan', message: 'Contrôle final d’EventAlert…', phasePercent: 97 });
      const inventory = includeInventory ? await this.inventory() : null;
      report({ step: 'complete', message: `EventAlert ${upstream.version} + CoA ${artifact.version} est prêt`, phasePercent: 100 });
      return {
        operation: eventAlert || companion ? 'replaced' : 'installed', component: 'event-alert', version: artifact.version,
        upstreamVersion: upstream.version, enabledProfiles, backup: backup?.id || null, inventory
      };
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
    if (component === 'event-alert') {
      const local = await this.scan(detection.directory);
      const eventAlert = local.find(item => item.folder.toLowerCase() === 'eventalert');
      const companion = local.find(item => item.folder.toLowerCase() === EVENT_ALERT_COMPANION_FOLDER.toLowerCase());
      const legacy = local.find(item => item.folder.toLowerCase() === EVENT_ALERT_LEGACY_FOLDER.toLowerCase());
      await this.createBackupSet(component, [
        { targetFolder: 'EventAlert', source: path.join(detection.directory, 'EventAlert'), version: eventAlert?.version },
        { targetFolder: EVENT_ALERT_COMPANION_FOLDER, source: path.join(detection.directory, EVENT_ALERT_COMPANION_FOLDER), version: companion?.version },
        { targetFolder: EVENT_ALERT_LEGACY_FOLDER, source: path.join(detection.directory, EVENT_ALERT_LEGACY_FOLDER), version: legacy?.version }
      ], companion?.version || eventAlert?.version, 'pre-rollback');
      await this.restoreBackupSet(detection.directory, selected, ['EventAlert', EVENT_ALERT_COMPANION_FOLDER, EVENT_ALERT_LEGACY_FOLDER]);
      return { operation: 'restored', component, backup: selected.id, inventory: await this.inventory() };
    }
    const source = path.join(this.backupsRoot, component, selected.id, selected.targetFolder);
    await this.assertToc(source, selected.targetFolder);
    const current = path.join(detection.directory, selected.targetFolder);
    const local = (await this.scan(detection.directory)).find(item => item.folder.toLowerCase() === selected.targetFolder.toLowerCase());
    await this.createBackup(component, selected.targetFolder, current, local?.version, 'pre-rollback');
    await this.replaceFolder(detection.directory, selected.targetFolder, source);
    return { operation: 'restored', component, backup: selected.id, inventory: await this.inventory() };
  }

  updateAll(onProgress) { return this.runExclusive(async () => {
    const report = update => { if (onProgress) onProgress(update); };
    report({ step: 'scan', message: 'Recherche des addons à installer ou mettre à jour…', phasePercent: 0, index: 0, total: 0 });
    const current = await this.inventory();
    const components = current.managed.filter(item => ['install', 'update'].includes(item.action)).map(item => item.component);
    if (!components.length) {
      report({ step: 'complete', message: 'Tous les addons sont déjà à jour', phasePercent: 100, index: 0, total: 0 });
      return { operation: 'update-all', updated: [], results: [], inventory: current };
    }
    const results = [];
    for (let index = 0; index < components.length; index++) {
      const component = components[index];
      const relay = update => report({ ...update, component, index: index + 1, total: components.length });
      relay({ step: 'starting-addon', message: `Préparation de ${component} (${index + 1}/${components.length})…`, phasePercent: 0 });
      results.push(await this.installNow(component, relay, false));
    }
    report({ step: 'rescan', message: 'Contrôle global des versions installées…', phasePercent: 99, index: components.length, total: components.length });
    const inventory = await this.inventory();
    report({ step: 'complete', message: `${components.length} addon(s) mis à jour`, phasePercent: 100, index: components.length, total: components.length });
    return { operation: 'update-all', updated: components, results, inventory };
  }); }
}
