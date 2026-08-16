import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { MANAGER_UPDATE_INTERVAL_MS, UpdateMonitor } from '../src/core/update-monitor.js';

test('manager monitor stages updates hourly and raises one native Windows alert per version', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'coa-monitor-'));
  let staged = false;
  let downloads = 0;
  const spawns = [];
  const updater = {
    async check() {
      return { available: true, currentVersion: '1.5.1', manifest: { version: '1.5.2' }, artifact: { component: 'addon-manager', version: '1.5.2' } };
    },
    async ready(version) { return staged ? { version, file: 'manager.zip' } : null; },
    async download() { downloads++; staged = true; return { version: '1.5.2', file: 'manager.zip' }; }
  };
  const spawnImpl = (file, args, options) => { spawns.push({ file, args, options }); return { unref() {} }; };
  try {
    const monitor = new UpdateMonitor({ updater, ui: { async get() { return { managerUpdateAlerts: true }; } }, dataDir: directory, spawnImpl, platform: 'win32', systemRoot: 'C:\\Windows' });
    assert.equal(MANAGER_UPDATE_INTERVAL_MS, 60 * 60 * 1000);
    assert.equal((await monitor.check()).available, true);
    assert.equal((await monitor.check()).notification.reason, 'already-notified');
    assert.equal(downloads, 1);
    assert.equal(spawns.length, 1);
    assert.match(spawns[0].file, /powershell\.exe$/i);
    assert.equal(spawns[0].args.includes('-EncodedCommand'), true);
    assert.equal(spawns[0].options.windowsHide, true);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('manager monitor respects the local Windows alert preference', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'coa-monitor-disabled-'));
  let spawned = false;
  try {
    const monitor = new UpdateMonitor({
      updater: {
        async check() { return { available: true, currentVersion: '1.5.1', manifest: { version: '1.5.2' }, artifact: { component: 'addon-manager' } }; },
        async ready() { return { version: '1.5.2', file: 'manager.zip' }; }
      },
      ui: { async get() { return { managerUpdateAlerts: false }; } },
      dataDir: directory,
      spawnImpl() { spawned = true; return { unref() {} }; },
      platform: 'win32'
    });
    assert.equal((await monitor.check()).notification.reason, 'disabled');
    assert.equal(spawned, false);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
