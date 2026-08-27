import test from 'node:test';
import assert from 'node:assert/strict';
import { AddonOperationRegistry } from '../src/core/addon-operations.js';

const eventually = async predicate => {
  for (let attempt = 0; attempt < 100; attempt++) {
    const value = predicate();
    if (value) return value;
    await new Promise(resolve => setTimeout(resolve, 2));
  }
  throw new Error('Operation did not reach the expected state');
};

test('global addon updates start immediately and expose component, byte and overall progress', async () => {
  let resume;
  const gate = new Promise(resolve => { resume = resolve; });
  const addons = {
    async updateAll(report) {
      report({ component: 'combat-assistant', step: 'download', message: 'Téléchargement du Combat Assistant…', phasePercent: 25, index: 1, total: 2, bytesDone: 25, bytesTotal: 100 });
      await gate;
      report({ component: 'ui-manager', step: 'install', message: 'Installation du UI Manager…', phasePercent: 80, index: 2, total: 2 });
      return { inventory: { managed: [] }, updated: ['combat-assistant', 'ui-manager'] };
    }
  };
  const registry = new AddonOperationRegistry(addons);
  const started = registry.start('update-all');
  assert.equal(started.state, 'queued');
  assert.equal(started.percent, 0);

  const downloading = await eventually(() => registry.current()?.step === 'download' && registry.current());
  assert.equal(downloading.state, 'running');
  assert.equal(downloading.current, 1);
  assert.equal(downloading.total, 2);
  assert.equal(downloading.percent, 13);
  assert.equal(downloading.bytesDone, 25);
  assert.equal(downloading.bytesTotal, 100);
  assert.throws(() => registry.start('install', 'grid-compat'), error => error.status === 409);

  resume();
  const completed = await eventually(() => registry.current()?.state === 'succeeded' && registry.current());
  assert.equal(completed.percent, 100);
  assert.deepEqual(completed.result.updated, ['combat-assistant', 'ui-manager']);
  assert.ok(completed.finishedAt);
});

test('individual addon failures remain visible with their exact step and error', async () => {
  const addons = {
    async install(component, report) {
      report({ component, step: 'download', message: 'Téléchargement…', phasePercent: 40 });
      throw new Error('Délai réseau dépassé après 2 minutes pour addon.zip');
    }
  };
  const registry = new AddonOperationRegistry(addons);
  const started = registry.start('install', 'grid-compat');
  const failed = await eventually(() => registry.get(started.id)?.state === 'failed' && registry.get(started.id));
  assert.equal(failed.component, 'grid-compat');
  assert.equal(failed.step, 'failed');
  assert.match(failed.error, /Délai réseau dépassé/);
  assert.match(failed.message, /^Échec :/);
});

test('addon uninstallation is reported as a recoverable operation', async () => {
  const addons = {
    async uninstall(component, report) {
      report({ component, step: 'backup', message: 'Sauvegarde avant désinstallation…', phasePercent: 35 });
      report({ component, step: 'remove', message: 'Suppression contrôlée…', phasePercent: 65 });
      return { operation: 'uninstalled', component, backup: 'backup-1', inventory: { managed: [] } };
    }
  };
  const registry = new AddonOperationRegistry(addons);
  const started = registry.start('uninstall', 'message-center');
  const completed = await eventually(() => registry.get(started.id)?.state === 'succeeded' && registry.get(started.id));
  assert.equal(completed.action, 'uninstall');
  assert.equal(completed.component, 'message-center');
  assert.equal(completed.percent, 100);
  assert.match(completed.message, /désinstallé avec sauvegarde/);
  assert.equal(completed.result.backup, 'backup-1');
});
