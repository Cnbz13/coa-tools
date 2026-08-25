import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import process from 'node:process';
import luaparse from 'luaparse';

function usage() {
  console.error('Usage: npm run analyze:dungeons -- <CoADungeonNavigator.lua> [--json]');
  process.exitCode = 2;
}

export function decodeLuaString(raw) {
  if (!raw || raw.length < 2) return '';
  const quote = raw[0];
  if ((quote !== '"' && quote !== "'") || raw[raw.length - 1] !== quote) return raw;
  const body = raw.slice(1, -1);
  let result = '';
  const escapes = { a: '\x07', b: '\b', f: '\f', n: '\n', r: '\r', t: '\t', v: '\x0b', '\\': '\\', '"': '"', "'": "'" };
  for (let index = 0; index < body.length; index += 1) {
    if (body[index] !== '\\') {
      result += body[index];
      continue;
    }
    const next = body[index + 1];
    if (/[0-9]/.test(next || '')) {
      const digits = body.slice(index + 1).match(/^[0-9]{1,3}/)?.[0] || '0';
      result += String.fromCharCode(Number(digits));
      index += digits.length;
    } else {
      result += escapes[next] ?? next ?? '';
      index += 1;
    }
  }
  return result;
}

export function scalar(node) {
  if (!node) return undefined;
  if (node.type === 'StringLiteral') return node.value ?? decodeLuaString(node.raw);
  if (node.type === 'NumericLiteral' || node.type === 'BooleanLiteral') return node.value;
  if (node.type === 'NilLiteral') return null;
  if (node.type === 'UnaryExpression' && node.operator === '-' && node.argument?.type === 'NumericLiteral') {
    return -node.argument.value;
  }
  return undefined;
}

function fieldKey(field, sequence) {
  if (field.type === 'TableValue') return sequence;
  if (field.type === 'TableKeyString') return field.key.name;
  if (field.type === 'TableKey') return scalar(field.key);
  return undefined;
}

export function tableEntries(node) {
  if (!node || node.type !== 'TableConstructorExpression') return [];
  let sequence = 1;
  return node.fields.map((field) => {
    const key = fieldKey(field, sequence);
    if (field.type === 'TableValue') sequence += 1;
    return [key, field.value];
  });
}

export function getField(node, key) {
  for (const [candidate, value] of tableEntries(node)) {
    if (candidate === key) return value;
  }
  return undefined;
}

export function getScalar(node, key, fallback = undefined) {
  return scalar(getField(node, key)) ?? fallback;
}

export function arrayValues(node) {
  return tableEntries(node)
    .filter(([key]) => Number.isInteger(key) && key >= 1)
    .sort((a, b) => a[0] - b[0])
    .map(([, value]) => value);
}

function countTable(node) {
  return tableEntries(node).length;
}

function unique(values) {
  return [...new Set(values.filter((value) => value !== undefined && value !== null && value !== ''))];
}

function round(value, digits = 1) {
  const scale = 10 ** digits;
  return Math.round((Number(value) || 0) * scale) / scale;
}

export function summarizeSession(node, index) {
  const instance = getField(node, 'instance');
  const character = getField(node, 'character');
  const points = arrayValues(getField(node, 'points'));
  const pulls = arrayValues(getField(node, 'pulls'));
  const enemiesNode = getField(node, 'enemies');
  const enemies = tableEntries(enemiesNode).map(([, value]) => value);
  const markers = arrayValues(getField(node, 'markers'));
  const loot = arrayValues(getField(node, 'loot'));
  const floors = unique(points.map((point) => getScalar(point, 'floor', 0))).sort((a, b) => a - b);
  const mapIds = unique(points.map((point) => getScalar(point, 'mapId', 0))).sort((a, b) => a - b);
  const bosses = unique(enemies
    .filter((enemy) => getScalar(enemy, 'bossCandidate', false))
    .map((enemy) => getScalar(enemy, 'name', 'Créature inconnue')));
  const kills = enemies.reduce((sum, enemy) => sum + Number(getScalar(enemy, 'kills', 0)), 0);
  const pullKills = pulls.reduce((sum, pull) => sum + Number(getScalar(pull, 'kills', 0)), 0);
  const quality = Math.min(100, Math.round(
    Math.min(points.length / 150, 1) * 35
    + Math.min(pulls.length / 12, 1) * 25
    + Math.min(enemies.length / 15, 1) * 20
    + Math.min(bosses.length / 3, 1) * 15
    + (getScalar(node, 'coordinatesAvailable', false) ? 5 : 0)
  ));

  return {
    index,
    id: getScalar(node, 'id', ''),
    name: getScalar(instance, 'name', 'Instance inconnue'),
    instanceKey: getScalar(node, 'instanceKey', ''),
    difficultyIndex: getScalar(instance, 'difficultyIndex', 0),
    difficultyName: getScalar(instance, 'difficultyName', ''),
    mapId: getScalar(instance, 'mapId', 0),
    characterClass: getScalar(character, 'classToken', 'UNKNOWN'),
    characterLevel: getScalar(character, 'level', 0),
    startedAt: getScalar(node, 'startedAt', 0),
    duration: round(getScalar(node, 'duration', 0)),
    endReason: getScalar(node, 'endReason', ''),
    status: getScalar(node, 'status', ''),
    points: points.length,
    pulls: pulls.length,
    enemies: enemies.length,
    kills,
    pullKills,
    markers: markers.length,
    loot: loot.length,
    deaths: getScalar(node, 'deaths', 0),
    floors,
    mapIds,
    bosses,
    coordinatesAvailable: getScalar(node, 'coordinatesAvailable', false),
    truncated: getScalar(node, 'truncated', false),
    quality
  };
}

export function findDatabase(ast) {
  for (const statement of ast.body || []) {
    if (statement.type !== 'AssignmentStatement') continue;
    for (let index = 0; index < statement.variables.length; index += 1) {
      const variable = statement.variables[index];
      if (variable.type === 'Identifier' && variable.name === 'CoADungeonNavigatorDB') {
        return statement.init[index];
      }
    }
  }
  return undefined;
}

export function aggregate(sessions) {
  const byDungeon = new Map();
  for (const session of sessions) {
    const key = session.instanceKey || `${session.name}:${session.difficultyIndex}`;
    const entry = byDungeon.get(key) || {
      key,
      name: session.name,
      difficultyIndex: session.difficultyIndex,
      difficultyName: session.difficultyName,
      runs: [],
      bestRun: null
    };
    entry.runs.push(session);
    if (!entry.bestRun || session.quality > entry.bestRun.quality
      || (session.quality === entry.bestRun.quality && session.points > entry.bestRun.points)) {
      entry.bestRun = session;
    }
    byDungeon.set(key, entry);
  }
  return [...byDungeon.values()].sort((a, b) => a.name.localeCompare(b.name, 'fr'));
}

function formatDuration(seconds) {
  const minutes = Math.floor((Number(seconds) || 0) / 60);
  const rest = Math.round((Number(seconds) || 0) % 60);
  return `${minutes}m${String(rest).padStart(2, '0')}s`;
}

function printHuman(report) {
  console.log(`CoA Dungeon Navigator : ${report.sessionCount} session(s), ${report.dungeons.length} donjon(s) distinct(s)`);
  console.log(`Base v${report.databaseVersion}; session active : ${report.hasActiveSession ? 'oui' : 'non'}`);
  console.log('');
  for (const dungeon of report.dungeons) {
    const best = dungeon.bestRun;
    console.log(`${dungeon.name} — ${dungeon.runs.length} run(s), meilleur #${best.index} (qualité ${best.quality}/100)`);
    console.log(`  ${formatDuration(best.duration)} · ${best.points} points · ${best.pulls} combats · ${best.enemies} créatures · ${best.loot} butins · ${best.deaths} morts`);
    console.log(`  étages ${best.floors.join(', ') || 'inconnus'} · cartes ${best.mapIds.join(', ') || 'inconnues'} · fin « ${best.endReason || 'inconnue'} »`);
    console.log(`  boss/candidats : ${best.bosses.length ? best.bosses.join(', ') : 'aucun identifié'}`);
  }
}

export async function loadSavedVariablesDatabase(filePath) {
  const source = await readFile(filePath, 'utf8');
  const ast = luaparse.parse(source, { luaVersion: '5.1', comments: false, scope: false });
  const database = findDatabase(ast);
  if (!database || database.type !== 'TableConstructorExpression') {
    throw new Error('CoADungeonNavigatorDB introuvable dans le fichier fourni.');
  }
  return database;
}

export async function analyzeSavedVariables(filePath) {
  const database = await loadSavedVariablesDatabase(filePath);
  const sessions = arrayValues(getField(database, 'sessions')).map((session, index) => summarizeSession(session, index + 1));
  return {
    databaseVersion: getScalar(database, 'version', 'inconnue'),
    sessionCount: sessions.length,
    hasActiveSession: Boolean(getField(database, 'activeSession') && scalar(getField(database, 'activeSession')) !== null),
    dungeons: aggregate(sessions),
    sessions
  };
}

async function main() {
  const args = process.argv.slice(2);
  const json = args.includes('--json');
  const filePath = args.find((arg) => arg !== '--json');
  if (!filePath) return usage();
  const report = await analyzeSavedVariables(filePath);
  if (json) console.log(JSON.stringify(report, null, 2));
  else printHuman(report);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
