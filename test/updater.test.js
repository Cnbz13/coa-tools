import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { compareVersions, Updater } from '../src/core/updater.js';

test('semantic versions are ordered numerically', () => {
  assert.equal(compareVersions('1.2.0', '1.1.9') > 0, true);
  assert.equal(compareVersions('1.0.0', '1.0.0'), 0);
  assert.equal(compareVersions('1.9.0', '1.10.0') < 0, true);
});

test('updater stages only an artifact matching its SHA-256 and size', async () => {
  const payload = Buffer.from('verified CoA update');
  const digest = createHash('sha256').update(payload).digest('hex');
  const server = createServer((request, response) => { response.writeHead(200); response.end(payload); });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const directory = await mkdtemp(path.join(tmpdir(), 'coa-update-'));
  const url = `http://127.0.0.1:${server.address().port}/release.tgz`;
  try {
    const updater = new Updater({ currentVersion: '1.0.0', manifestUrl: url, stagingDir: directory });
    const result = await updater.download({ file: 'release.tgz', url, sha256: digest, size: payload.length });
    assert.equal(result.sha256, digest);
    assert.deepEqual(await readFile(result.file), payload);
    await assert.rejects(updater.download({ file: 'invalid.tgz', url, sha256: '0'.repeat(64), size: payload.length }), /SHA-256/);
  } finally {
    server.close();
    await rm(directory, { recursive: true, force: true });
  }
});

test('updater selects only the Windows manager from a mixed release manifest', async () => {
  const manifest = {
    version: '2.0.0',
    artifacts: [
      { component: 'combat-assistant', platform: 'any', arch: 'any', file: 'combat.zip' },
      { component: 'addon-manager', platform: process.platform, arch: process.arch, file: 'manager.zip' }
    ]
  };
  const server = createServer((request, response) => {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify(manifest));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const updater = new Updater({ currentVersion: '1.5.1', manifestUrl: `http://127.0.0.1:${server.address().port}/manifest.json`, stagingDir: tmpdir() });
    const result = await updater.check();
    assert.equal(result.available, true);
    assert.equal(result.artifact.component, 'addon-manager');
    assert.equal(result.artifact.file, 'manager.zip');
  } finally { server.close(); }
});
