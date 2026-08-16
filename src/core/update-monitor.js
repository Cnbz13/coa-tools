import { spawn } from 'node:child_process';
import path from 'node:path';
import { readJson, writeJsonAtomic } from '../lib/files.js';

export const MANAGER_UPDATE_INTERVAL_MS = 60 * 60 * 1000;

const validVersion = value => /^\d+\.\d+\.\d+$/.test(String(value || ''));

export class UpdateMonitor {
  constructor({ updater, ui, dataDir, intervalMs = MANAGER_UPDATE_INTERVAL_MS, spawnImpl = spawn, platform = process.platform, systemRoot = process.env.SystemRoot } = {}) {
    if (!updater || !ui || !dataDir) throw new Error('UpdateMonitor requires updater, ui and dataDir');
    Object.assign(this, { updater, ui, intervalMs, spawnImpl, platform });
    this.stateFile = path.join(path.resolve(dataDir), 'manager-update-alert.json');
    this.powershell = path.join(systemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
    this.operation = null;
    this.timers = [];
  }

  async notify(version) {
    if (this.platform !== 'win32' || !validVersion(version)) return { shown: false, reason: 'unsupported' };
    const state = await readJson(this.stateFile, {});
    if (state.version === version) return { shown: false, reason: 'already-notified' };
    const title = `CoA Tools ${version}`;
    const message = `Une mise a jour du manager est disponible et verifiee. Elle sera appliquee automatiquement au prochain lancement.`;
    const script = `Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('${message}', '${title}', 'OK', 'Information') | Out-Null`;
    const encoded = Buffer.from(script, 'utf16le').toString('base64');
    const child = this.spawnImpl(this.powershell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-EncodedCommand', encoded], {
      detached: true, stdio: 'ignore', windowsHide: true
    });
    child?.unref?.();
    await writeJsonAtomic(this.stateFile, { version, notifiedAt: new Date().toISOString() });
    return { shown: true, version };
  }

  async check() {
    if (this.operation) return this.operation;
    this.operation = (async () => {
      const update = await this.updater.check();
      if (!update.available || !update.artifact) return { available: false, currentVersion: update.currentVersion };
      const version = update.manifest.version;
      const staged = await this.updater.ready(version) || await this.updater.download(update.artifact);
      const preferences = await this.ui.get();
      const notification = preferences.managerUpdateAlerts === false ? { shown: false, reason: 'disabled' } : await this.notify(version);
      return { available: true, version, staged, notification };
    })();
    try { return await this.operation; }
    finally { this.operation = null; }
  }

  start() {
    const run = () => this.check().catch(error => console.warn(`Manager update check failed: ${error.message}`));
    const initial = setTimeout(run, 5000);
    const interval = setInterval(run, this.intervalMs);
    initial.unref?.();
    interval.unref?.();
    this.timers.push(initial, interval);
  }

  stop() {
    for (const timer of this.timers) { clearTimeout(timer); clearInterval(timer); }
    this.timers = [];
  }
}
