import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { AddonManager } from '../src/core/addons.js';

test('addon lifecycle copies, toggles and removes an addon', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'coa-addons-'));
  const source = path.join(directory, 'source');
  const data = path.join(directory, 'data');
  const destination = path.join(directory, 'installed');
  try {
    await import('node:fs/promises').then(({ mkdir }) => mkdir(source));
    await writeFile(path.join(source, 'addon.txt'), 'ready');
    const manager = new AddonManager(data, destination);
    await manager.install({ name: 'TestAddon', sourcePath: source, version: '2.0.0' });
    assert.equal(await readFile(path.join(destination, 'TestAddon', 'addon.txt'), 'utf8'), 'ready');
    assert.equal((await manager.toggle('TestAddon', false)).enabled, false);
    assert.deepEqual(await manager.remove('TestAddon'), []);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('addon names cannot escape the install directory', async () => {
  const manager = new AddonManager(tmpdir(), path.join(tmpdir(), 'coa-safe'));
  await assert.rejects(manager.remove('../escape'), /Invalid name/);
});
