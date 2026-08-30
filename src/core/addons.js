import { createHash, randomUUID } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { cp, readFile, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { ensureDir, readJson, writeJsonAtomic } from '../lib/files.js';
import { extractZip } from '../lib/zip.js';

export const WARMANE_ADDONS = 'C:\\Warmane\\Interface\\AddOns';
const MANAGED_COMPONENTS = new Set(['combat-assistant', 'ui-manager', 'loot-decider', 'message-center', 'rotation-guide', 'dungeon-navigator', 'essential-assistant', 'heretic-helper', 'stormbringer-helper', 'primalist-helper', 'grid-compat', 'warmane-ui-manager', 'warmane-loot-decider']);
const USER_MANAGEABLE_COMPONENTS = new Set(MANAGED_COMPONENTS);
const DURABLE_EXCLUSIONS_FILE = '.coa-disabled-addons.json';

function defaultDownloadPolicy(url) {
  return url.protocol === 'https:' && url.hostname === 'github.com';
}

async function isDirectory(directory) {
  try { return (await stat(directory)).isDirectory(); } catch { return false; }
}

function cleanWowText(value = '') {
  return value.trim().replace(/\|c[0-9a-f]{8}/gi, '').replace(/\|r/gi, '');
}

function gameLabel() { return 'Warmane Icecrown'; }

function artifactSupportsGame(artifact, gameFlavor) {
  const flavors = Array.isArray(artifact?.gameFlavors) && artifact.gameFlavors.length
    ? artifact.gameFlavors
    : ['warmane'];
  return flavors.includes(gameFlavor);
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
  constructor({
    dataDir, manifestUrl, canonicalPath = WARMANE_ADDONS, candidates = [],
    environmentPath = process.env.WARMANE_ADDONS_DIR, warmanePath = null,
    warmaneCandidates = [], warmaneEnvironmentPath = null,
    downloadPolicy
  } = {}) {
    if (!dataDir) throw new Error('dataDir is required');
    this.dataDir = path.resolve(dataDir);
    this.manifestUrl = manifestUrl;
    this.canonicalPath = path.resolve(warmanePath || canonicalPath);
    this.environmentPath = (warmaneEnvironmentPath || environmentPath)
      ? path.resolve(warmaneEnvironmentPath || environmentPath)
      : null;
    this.candidates = [...candidates, ...warmaneCandidates].map(item => path.resolve(item));
    this.settingsFile = path.join(this.dataDir, 'addon-settings.json');
    this.cachedManifestFile = path.join(this.dataDir, 'remote-manifest.json');
    this.backupsRoot = path.join(this.dataDir, 'backups');
    this.transactionsRoot = path.join(this.dataDir, 'transactions');
    this.downloadPolicy = downloadPolicy || defaultDownloadPolicy;
    this.operation = Promise.resolve();
  }

  async detectDirectory() {
    const settings = await this.getSettings();
    const savedPath = settings.addonsDir;
    const standard = [
      savedPath,
      this.environmentPath,
      this.canonicalPath,
      ...this.candidates,
      'C:\\Games\\Warmane\\Interface\\AddOns',
      'C:\\Warmane WoW 3.3.5a\\Interface\\AddOns',
      'C:\\Program Files\\Warmane\\Interface\\AddOns',
      'C:\\Program Files (x86)\\Warmane\\Interface\\AddOns'
    ].filter(Boolean).map(item => path.resolve(item));
    const unique = [...new Set(standard.map(item => item.toLowerCase()))];
    for (const lower of unique) {
      const directory = standard.find(item => item.toLowerCase() === lower);
      if (await isDirectory(directory)) {
        const source = directory === savedPath ? 'saved'
          : directory === this.environmentPath ? 'environment'
            : directory.toLowerCase() === this.canonicalPath.toLowerCase() ? 'warmane'
              : 'detected';
        return { directory, exists: true, source, gameFlavor: 'warmane' };
      }
    }
    return { directory: savedPath || this.canonicalPath, exists: false, source: 'missing', gameFlavor: 'warmane' };
  }

  async setDirectory(directory) {
    const selected = String(directory || '').trim();
    if (!selected) throw new Error('Sélectionnez un dossier Interface\\AddOns');
    const resolved = path.resolve(selected);
    if (!(await isDirectory(resolved))) throw new Error('Le dossier AddOns sélectionné est introuvable');
    const settings = await this.getSettings();
    await writeJsonAtomic(this.settingsFile, { ...settings, addonsDir: resolved, savedAt: new Date().toISOString() });
    return this.inventory();
  }

  async writeRotationUpdateFeed(luaContents, feed = {}) {
    const text = String(luaContents || '');
    if (!text.startsWith('-- Généré par CoA Addon Manager') || !text.includes('CoARotationUpdateFeed = {')) {
      throw new Error('Flux de mises à jour CoA invalide');
    }
    return { written: false, reason: 'warmane-only', count: 0 };
  }

  async getSettings() {
    const settings = await readJson(this.settingsFile, {});
    const legacyWarmanePath = settings.installations?.warmane || null;
    const { installations: _legacyInstallations, gameFlavor: _legacyGameFlavor, ...singleGameSettings } = settings;
    return {
      ...singleGameSettings,
      addonsDir: settings.addonsDir || legacyWarmanePath,
      excludedComponents: Array.isArray(settings.excludedComponents)
        ? [...new Set(settings.excludedComponents.filter(component => USER_MANAGEABLE_COMPONENTS.has(component)))]
        : []
    };
  }

  async readDurableExclusions(addonsDir) {
    if (!addonsDir || !(await isDirectory(addonsDir))) return new Set();
    const saved = await readJson(path.join(addonsDir, DURABLE_EXCLUSIONS_FILE), {});
    return new Set(Array.isArray(saved.excludedComponents)
      ? saved.excludedComponents.filter(component => USER_MANAGEABLE_COMPONENTS.has(component))
      : []);
  }

  async getExcludedComponents(addonsDir = null) {
    const settings = await this.getSettings();
    const local = new Set(settings.excludedComponents);
    const durable = await this.readDurableExclusions(addonsDir);
    const merged = new Set([...local, ...durable]);
    const sorted = [...merged].sort();
    const localSorted = [...local].sort();
    const durableSorted = [...durable].sort();
    if (JSON.stringify(localSorted) !== JSON.stringify(sorted)) {
      await writeJsonAtomic(this.settingsFile, {
        ...settings, excludedComponents: sorted, exclusionsSavedAt: new Date().toISOString()
      });
    }
    if (addonsDir && JSON.stringify(durableSorted) !== JSON.stringify(sorted)) {
      await writeJsonAtomic(path.join(addonsDir, DURABLE_EXCLUSIONS_FILE), {
        schema: 1, excludedComponents: sorted, savedAt: new Date().toISOString()
      });
    }
    return merged;
  }

  async writeExclusion(component, excluded) {
    if (!USER_MANAGEABLE_COMPONENTS.has(component)) throw new Error('Cet addon reste inchangé et ne peut pas être exclu ici');
    const settings = await this.getSettings();
    const components = new Set(settings.excludedComponents);
    if (excluded) components.add(component); else components.delete(component);
    await writeJsonAtomic(this.settingsFile, {
      ...settings,
      excludedComponents: [...components].sort(),
      exclusionsSavedAt: new Date().toISOString()
    });
    const detection = await this.detectDirectory();
    if (detection.exists) {
      const durable = await this.readDurableExclusions(detection.directory);
      if (excluded) durable.add(component); else durable.delete(component);
      await writeJsonAtomic(path.join(detection.directory, DURABLE_EXCLUSIONS_FILE), {
        schema: 1,
        excludedComponents: [...durable].sort(),
        savedAt: new Date().toISOString()
      });
    }
  }

  async setGlobalUpdateExclusion(component, excluded) {
    if (typeof excluded !== 'boolean') throw new Error('État d’exclusion invalide');
    await this.writeExclusion(component, excluded);
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
    const managedArtifacts = (manifest?.artifacts || []).filter(item => MANAGED_COMPONENTS.has(item.component) && artifactSupportsGame(item, detection.gameFlavor));
    const excludedComponents = await this.getExcludedComponents(detection.exists ? detection.directory : null);
    const managedFolders = new Set(managedArtifacts.map(item => item.targetFolder.toLowerCase()));
    const managed = [];
    for (const artifact of managedArtifacts) {
      const installed = local.find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase()) || null;
      const localVersion = installed?.version || null;
      const remoteVersion = artifact.contentVersion || artifact.version;
      const comparison = installed ? compareAddonVersions(remoteVersion, localVersion) : 1;
      const backups = await this.listBackups(artifact.component);
      managed.push({
        kind: 'managed', component: artifact.component, name: artifact.name, folder: artifact.targetFolder,
        title: installed?.title || artifact.name, notes: installed?.notes || '', localVersion,
        remoteVersion, installed: Boolean(installed), action: !installed ? 'install' : comparison > 0 ? 'update' : 'reinstall',
        excludedFromGlobalUpdates: USER_MANAGEABLE_COMPONENTS.has(artifact.component) && excludedComponents.has(artifact.component),
        installationBlocked: USER_MANAGEABLE_COMPONENTS.has(artifact.component) && excludedComponents.has(artifact.component),
        userManageable: USER_MANAGEABLE_COMPONENTS.has(artifact.component),
        artifact: { file: artifact.file, size: artifact.size, sha256: artifact.sha256, upstream: artifact.upstream || null }, canRollback: backups.length > 0,
        latestBackup: backups[0] || null
      });
    }
    const regular = local.filter(item => !managedFolders.has(item.folder.toLowerCase())).map(item => ({ ...item, kind: detection.gameFlavor }));
    return {
      addonsDir: detection.directory, exists: detection.exists, detectionSource: detection.source,
      gameFlavor: detection.gameFlavor, gameLabel: gameLabel(detection.gameFlavor),
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

  async setAddonForProfiles(addonsDir, addonFolder, state) {
    if (!['enabled', 'disabled'].includes(state)) throw new Error('État de profil addon invalide');
    const accountRoot = path.resolve(addonsDir, '..', '..', 'WTF', 'Account');
    if (!(await isDirectory(accountRoot))) return 0;
    const addonLine = `${addonFolder}: ${state}`;
    const escapedFolder = addonFolder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const entryPattern = new RegExp(`^${escapedFolder}:\\s*(?:enabled|disabled)\\s*$`, 'mi');
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

  enableAddonForProfiles(addonsDir, addonFolder) {
    return this.setAddonForProfiles(addonsDir, addonFolder, 'enabled');
  }

  disableAddonForProfiles(addonsDir, addonFolder) {
    return this.setAddonForProfiles(addonsDir, addonFolder, 'disabled');
  }

  runExclusive(task) {
    const result = this.operation.then(task, task);
    this.operation = result.catch(() => {});
    return result;
  }

  install(component, onProgress) { return this.runExclusive(() => this.installNow(component, onProgress)); }
  async installNow(component, onProgress = null, includeInventory = true) {
    const report = update => { if (onProgress) onProgress({ component, ...update }); };
    if (!MANAGED_COMPONENTS.has(component)) throw new Error('Composant CoA inconnu');
    const detection = await this.detectDirectory();
    report({ step: 'detect', message: `Détection du dossier ${gameLabel(detection.gameFlavor)}…`, phasePercent: 2 });
    if (!detection.exists) throw new Error(`Aucun dossier ${gameLabel(detection.gameFlavor)} AddOns détecté`);
    const excludedComponents = await this.getExcludedComponents(detection.directory);
    if (excludedComponents.has(component)) {
      throw new Error('Cet addon est désinstallé durablement. Utilisez « Réactiver l’installation » avant de l’installer.');
    }
    report({ step: 'manifest', message: 'Lecture du manifeste GitHub…', phasePercent: 5 });
    const { manifest } = await this.getManifest();
    const artifact = manifest?.artifacts?.find(item => item.component === component && artifactSupportsGame(item, detection.gameFlavor));
    if (!artifact) throw new Error('Artefact distant introuvable dans le manifeste');
    if (!/^[A-Za-z0-9._-]+$/.test(artifact.targetFolder || '')) throw new Error('Nom de dossier cible invalide');
    if (component === 'grid-compat' && !(await isDirectory(path.join(detection.directory, 'Grid')))) {
      throw new Error('Grid doit être installé avant sa compatibilité CoA');
    }
    const local = (await this.scan(detection.directory)).find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase());
    let preservedRotationFeed = null;
    if (component === 'rotation-guide' && local) {
      try {
        const candidate = await readFile(path.join(local.path, 'CoARotationUpdates.lua'), 'utf8');
        if (candidate.includes('CoARotationUpdateFeed = {')) preservedRotationFeed = candidate;
      } catch { /* Une ancienne version du guide peut ne pas encore avoir de flux. */ }
    }
    let preservedStormbringerFeed = null;
    if (component === 'stormbringer-helper' && local) {
      try {
        const candidate = await readFile(path.join(local.path, 'CoAStormbringerUpdates.lua'), 'utf8');
        if (candidate.includes('CoARotationUpdateFeed = {')) preservedStormbringerFeed = candidate;
      } catch { /* Une ancienne version peut ne pas encore avoir de flux. */ }
    }
    let preservedPrimalistFeed = null;
    if (component === 'primalist-helper' && local) {
      try {
        const candidate = await readFile(path.join(local.path, 'CoAPrimalistUpdates.lua'), 'utf8');
        if (candidate.includes('CoARotationUpdateFeed = {')) preservedPrimalistFeed = candidate;
      } catch { /* Une ancienne version peut ne pas encore avoir de flux. */ }
    }
    let preservedEssentialFeed = null;
    if (component === 'essential-assistant' && local) {
      try {
        const candidate = await readFile(path.join(local.path, 'CoAEssentialUpdates.lua'), 'utf8');
        if (candidate.includes('CoARotationUpdateFeed = {')) preservedEssentialFeed = candidate;
      } catch { /* Une ancienne version peut ne pas encore avoir de flux. */ }
    }
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
      if (component === 'rotation-guide' && preservedRotationFeed) {
        await writeFile(path.join(destination, 'CoARotationUpdates.lua'), preservedRotationFeed, 'utf8');
      }
      if (component === 'stormbringer-helper' && preservedStormbringerFeed) {
        await writeFile(path.join(destination, 'CoAStormbringerUpdates.lua'), preservedStormbringerFeed, 'utf8');
      }
      if (component === 'primalist-helper' && preservedPrimalistFeed) {
        await writeFile(path.join(destination, 'CoAPrimalistUpdates.lua'), preservedPrimalistFeed, 'utf8');
      }
      if (component === 'essential-assistant' && preservedEssentialFeed) {
        await writeFile(path.join(destination, 'CoAEssentialUpdates.lua'), preservedEssentialFeed, 'utf8');
      }
      report({ step: 'enable', message: `Activation dans les profils ${gameLabel(detection.gameFlavor)}…`, phasePercent: 91 });
      let enabledProfiles = await this.enableAddonForProfiles(detection.directory, artifact.targetFolder);
      if (component === 'grid-compat') enabledProfiles += await this.enableAddonForProfiles(detection.directory, 'Grid');
      report({ step: 'rescan', message: 'Contrôle final de l’installation…', phasePercent: 96 });
      const inventory = includeInventory ? await this.inventory() : null;
      report({ step: 'complete', message: `${artifact.name} v${artifact.version} est prêt`, phasePercent: 100 });
      return { operation: local ? 'replaced' : 'installed', component, version: artifact.version, enabledProfiles, backup: backup?.id || null, inventory };
    } finally { await rm(transaction, { recursive: true, force: true }); }
  }

  rollback(component, backupId) { return this.runExclusive(() => this.rollbackNow(component, backupId)); }
  async rollbackNow(component, backupId) {
    if (!MANAGED_COMPONENTS.has(component)) throw new Error('Composant CoA inconnu');
    const detection = await this.detectDirectory();
    if (!detection.exists) throw new Error(`Aucun dossier ${gameLabel(detection.gameFlavor)} AddOns détecté`);
    const excludedComponents = await this.getExcludedComponents(detection.directory);
    if (excludedComponents.has(component)) {
      throw new Error('Cet addon est désinstallé durablement. Réactivez son installation avant de restaurer un backup.');
    }
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

  uninstall(component, onProgress) { return this.runExclusive(() => this.uninstallNow(component, onProgress)); }
  async uninstallNow(component, onProgress = null) {
    const report = update => { if (onProgress) onProgress({ component, ...update }); };
    if (!USER_MANAGEABLE_COMPONENTS.has(component)) throw new Error('Cet addon reste inchangé et ne peut pas être désinstallé ici');
    const detection = await this.detectDirectory();
    report({ step: 'detect', message: `Détection du dossier ${gameLabel(detection.gameFlavor)}…`, phasePercent: 5 });
    if (!detection.exists) throw new Error(`Aucun dossier ${gameLabel(detection.gameFlavor)} AddOns détecté`);
    report({ step: 'manifest', message: 'Identification exacte de l’addon géré…', phasePercent: 12 });
    const { manifest } = await this.getManifest();
    const artifact = manifest?.artifacts?.find(item => item.component === component && artifactSupportsGame(item, detection.gameFlavor));
    if (!artifact || !/^[A-Za-z0-9._-]+$/.test(artifact.targetFolder || '')) throw new Error('Addon géré introuvable dans le manifeste');
    const addonsRoot = path.resolve(detection.directory);
    const destination = path.resolve(addonsRoot, artifact.targetFolder);
    if (!destination.startsWith(`${addonsRoot}${path.sep}`)) throw new Error('Chemin de désinstallation hors du dossier AddOns');
    const local = (await this.scan(addonsRoot)).find(item => item.folder.toLowerCase() === artifact.targetFolder.toLowerCase());
    if (!local || !(await isDirectory(destination))) throw new Error(`${artifact.name} n’est pas installé`);

    report({ step: 'backup', message: `Sauvegarde de ${artifact.targetFolder} avant désinstallation…`, phasePercent: 35 });
    const backup = await this.createBackup(component, artifact.targetFolder, destination, local.version, 'uninstall');
    if (!backup) throw new Error('La sauvegarde de sécurité n’a pas pu être créée');
    report({ step: 'disable', message: `Désactivation de ${artifact.targetFolder} pour tous les personnages…`, phasePercent: 55 });
    let exclusionWritten = false;
    let disabledProfiles = 0;
    try {
      await this.writeExclusion(component, true);
      exclusionWritten = true;
      disabledProfiles = await this.disableAddonForProfiles(addonsRoot, artifact.targetFolder);
      report({ step: 'remove', message: `Suppression contrôlée de ${artifact.targetFolder}…`, phasePercent: 72 });
      await rm(destination, { recursive: true, force: true });
      if (await isDirectory(destination)) throw new Error('Le dossier est toujours présent après la suppression');
    } catch (error) {
      report({ step: 'restore', message: 'Échec détecté, restauration automatique de la sauvegarde…', phasePercent: 78 });
      if (!(await isDirectory(destination))) await this.replaceFolder(addonsRoot, artifact.targetFolder, backup.folder);
      if (exclusionWritten) {
        try {
          await this.writeExclusion(component, false);
          await this.enableAddonForProfiles(addonsRoot, artifact.targetFolder);
        } catch { /* L’erreur initiale reste prioritaire. */ }
      }
      throw error;
    }
    report({ step: 'rescan', message: 'Contrôle du blocage persistant et de la suppression…', phasePercent: 92 });
    const inventory = await this.inventory();
    report({ step: 'complete', message: `${artifact.name} est désinstallé et bloqué durablement`, phasePercent: 100 });
    return { operation: 'uninstalled', component, disabledProfiles, backup: backup.id, inventory };
  }

  updateAll(onProgress) { return this.runExclusive(async () => {
    const report = update => { if (onProgress) onProgress(update); };
    report({ step: 'scan', message: 'Recherche des addons à installer ou mettre à jour…', phasePercent: 0, index: 0, total: 0 });
    const current = await this.inventory();
    const components = current.managed
      .filter(item => !item.excludedFromGlobalUpdates && ['install', 'update'].includes(item.action))
      .map(item => item.component);
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
