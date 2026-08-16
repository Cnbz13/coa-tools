import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { UiManager } from '../src/core/ui-manager.js';

test('UI preferences persist and reject unknown values', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'coa-ui-'));
  try {
    const manager = new UiManager(directory);
    await manager.update({ theme: 'frost', density: 'compact', autoUpdateAddons: false, managerUpdateAlerts: false });
    assert.deepEqual(await manager.get(), { theme: 'frost', density: 'compact', autoUpdateAddons: false, managerUpdateAlerts: false, panels: { combat: true, addons: true, updates: true } });
    assert.equal((await manager.update({ theme: 'invalid' })).theme, 'frost');
    assert.equal((await manager.update({ autoUpdateAddons: 'yes' })).autoUpdateAddons, false);
    assert.equal((await manager.update({ managerUpdateAlerts: 'yes' })).managerUpdateAlerts, false);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
