import test from 'node:test';
import assert from 'node:assert/strict';
import { CombatAssistant } from '../src/core/combat.js';

test('combat lifecycle tracks events and completion', () => {
  const combat = new CombatAssistant();
  assert.equal(combat.status().active, false);
  const started = combat.start({ name: 'Test encounter' });
  assert.equal(started.active, true);
  combat.event({ label: 'Move', offset: 12 });
  const stopped = combat.stop();
  assert.equal(stopped.active, false);
  assert.equal(stopped.encounter.events[0].label, 'Move');
});
