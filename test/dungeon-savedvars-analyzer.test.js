import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

test('dungeon SavedVariables analyzer inventories UTF-8 routes without executing Lua', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'coa-dungeon-analysis-'));
  const savedVariables = join(directory, 'CoADungeonNavigator.lua');
  const fixture = `CoADungeonNavigatorDB = {
    ["version"] = "1.16.1",
    ["sessions"] = {
      [1] = {
        ["id"] = "route-1",
        ["status"] = "complete",
        ["endReason"] = "changement d'instance",
        ["duration"] = 615.5,
        ["coordinatesAvailable"] = true,
        ["instanceKey"] = "Le Donjon égaré:party:1",
        ["instance"] = { ["name"] = "Le Donjon égaré", ["difficultyIndex"] = 1 },
        ["character"] = { ["classToken"] = "WARRIOR", ["level"] = 30 },
        ["points"] = {
          [1] = { ["x"] = 0.1, ["y"] = 0.2, ["floor"] = 1, ["mapId"] = 999 },
          [2] = { ["x"] = 0.2, ["y"] = 0.3, ["floor"] = 1, ["mapId"] = 999 }
        },
        ["pulls"] = { [1] = { ["kills"] = 1 } },
        ["enemies"] = {
          ["Creature-1"] = { ["name"] = "Gardien égaré", ["kills"] = 1, ["bossCandidate"] = true }
        },
        ["markers"] = {}, ["loot"] = {}, ["deaths"] = 0
      }
    }
  }`;
  try {
    await writeFile(savedVariables, fixture, 'utf8');
    const { stdout } = await execFileAsync(process.execPath, [
      'scripts/analyze-dungeon-savedvars.mjs', savedVariables, '--json'
    ], { cwd: process.cwd(), maxBuffer: 4 * 1024 * 1024 });
    const report = JSON.parse(stdout);
    assert.equal(report.databaseVersion, '1.16.1');
    assert.equal(report.sessionCount, 1);
    assert.equal(report.dungeons[0].name, 'Le Donjon égaré');
    assert.deepEqual(report.dungeons[0].bestRun.bosses, ['Gardien égaré']);
    assert.deepEqual(report.dungeons[0].bestRun.mapIds, [999]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
