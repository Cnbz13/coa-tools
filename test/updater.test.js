import test from 'node:test';
import assert from 'node:assert/strict';
import { compareVersions } from '../src/core/updater.js';

test('semantic versions are ordered numerically', () => {
  assert.equal(compareVersions('1.2.0', '1.1.9') > 0, true);
  assert.equal(compareVersions('1.0.0', '1.0.0'), 0);
  assert.equal(compareVersions('1.9.0', '1.10.0') < 0, true);
});
