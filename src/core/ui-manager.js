import path from 'node:path';
import { readJson, writeJsonAtomic } from '../lib/files.js';

const DEFAULTS = { theme: 'obsidian', density: 'comfortable', autoUpdateAddons: true, managerUpdateAlerts: true, panels: { combat: true, addons: true, updates: true } };

export class UiManager {
  constructor(dataDir) { this.file = path.join(dataDir, 'ui.json'); }
  async get() { return { ...DEFAULTS, ...(await readJson(this.file, {})) }; }
  async update(input) {
    const current = await this.get();
    const next = {
      theme: ['obsidian', 'ember', 'frost'].includes(input.theme) ? input.theme : current.theme,
      density: ['compact', 'comfortable'].includes(input.density) ? input.density : current.density,
      autoUpdateAddons: typeof input.autoUpdateAddons === 'boolean' ? input.autoUpdateAddons : current.autoUpdateAddons,
      managerUpdateAlerts: typeof input.managerUpdateAlerts === 'boolean' ? input.managerUpdateAlerts : current.managerUpdateAlerts,
      panels: { ...current.panels, ...(input.panels || {}) }
    };
    await writeJsonAtomic(this.file, next);
    return next;
  }
}
