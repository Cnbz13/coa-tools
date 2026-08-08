import path from 'node:path';
import { cp, rm, stat } from 'node:fs/promises';
import { ensureDir, readJson, safeName, writeJsonAtomic } from '../lib/files.js';

export class AddonManager {
  constructor(dataDir, addonsDir) {
    this.addonsDir = path.resolve(addonsDir);
    this.registry = path.join(dataDir, 'addons.json');
  }

  async list() { return readJson(this.registry, []); }

  async install({ name, sourcePath, version = 'local' }) {
    name = safeName(name);
    const source = path.resolve(sourcePath);
    if (!(await stat(source)).isDirectory()) throw new Error('Addon source must be a directory');
    await ensureDir(this.addonsDir);
    const destination = path.join(this.addonsDir, name);
    await rm(destination, { recursive: true, force: true });
    await cp(source, destination, { recursive: true, force: true });
    const addons = (await this.list()).filter(item => item.name !== name);
    addons.push({ name, version: String(version), enabled: true, installedAt: new Date().toISOString() });
    await writeJsonAtomic(this.registry, addons);
    return addons;
  }

  async toggle(name, enabled) {
    name = safeName(name);
    const addons = await this.list();
    const addon = addons.find(item => item.name === name);
    if (!addon) throw new Error('Addon not found');
    addon.enabled = Boolean(enabled);
    await writeJsonAtomic(this.registry, addons);
    return addon;
  }

  async remove(name) {
    name = safeName(name);
    await rm(path.join(this.addonsDir, name), { recursive: true, force: true });
    const addons = (await this.list()).filter(item => item.name !== name);
    await writeJsonAtomic(this.registry, addons);
    return addons;
  }
}
