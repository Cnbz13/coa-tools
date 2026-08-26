import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import luaparse from 'luaparse';
import { AddonManager } from '../src/core/addons.js';
import {
  classifyImpact, createRotationUpdateFeed, flattenChangelog, groupRecommendations,
  normalizeNews, runCoaWatch, serializeRotationUpdateFeed
} from '../src/core/coa-watch.js';

const changelogPayload = {
  current_page: 1, last_page: 1,
  data: {
    '2026/08/08': {
      0: [{
        id: 70375,
        description: '[Pending Restart] Necromancer minions now trigger a new proc and Command: Undead costs 30 Runic Power.',
        created_at: '2026-08-08T12:13:39',
        updated_at: '2026-08-08T12:13:55'
      }]
    }
  }
};

const newsPayload = {
  current_page: 1, last_page: 1,
  data: [{
    id: 600, slug: 'conquest-update', title: 'Conquest of Azeroth update',
    description: 'A new Necromancer spell pass is live.', content: '<p>Animation abilities changed.</p>',
    published_at: '2026-08-08T10:00:00', updated_at: '2026-08-08T10:00:00'
  }, {
    id: 601, slug: 'unrelated', title: 'Unrelated event', description: 'A store sale.',
    published_at: '2026-08-08T09:00:00', updated_at: '2026-08-08T09:00:00'
  }]
};

const talentCommitPayload = [{
  sha: 'abc123', html_url: 'https://github.com/srhinos/coa-datamine/commit/abc123',
  commit: {
    message: 'Update CoA talent data',
    committer: { date: '2026-08-08T11:00:00Z' }
  }
}];

test('official changelog and news payloads are normalized without HTML noise', () => {
  const changelog = flattenChangelog(changelogPayload);
  assert.equal(changelog.length, 1);
  assert.equal(changelog[0].id, '70375');
  assert.match(changelog[0].summary, /Command: Undead/);

  const news = normalizeNews(newsPayload);
  assert.equal(news.length, 2);
  assert.equal(news[0].relevant, true);
  assert.equal(news[1].relevant, false);
});

test('impact rules map spell, proc, dispel and interface changes to the affected addons', () => {
  const result = classifyImpact({
    id: '1', sourceId: 'test', sourceType: 'official', title: 'CoA update',
    summary: 'A Necromancer spell proc changed; a Magic dispel and secure interface frame were reworked.'
  });
  assert.equal(result.significant, true);
  assert.deepEqual(result.impacts.map(item => item.component), [
    'combat-assistant', 'rotation-guide', 'event-alert', 'grid-compat', 'ui-manager'
  ]);
  assert.equal(result.confidence, 'élevée');
});

test('Stormbringer patch notes are routed to the dedicated helper', () => {
  const result = classifyImpact({
    id: 'storm-1', sourceId: 'test', sourceType: 'official', title: 'Stormbringer change',
    summary: 'Arm of Thorim damage increased and Conductive duration changed.'
  });
  assert.equal(result.significant, true);
  assert.ok(result.impacts.some(item => item.component === 'stormbringer-helper'));
});

test('Primalist patch notes are routed to the dedicated helper', () => {
  const result = classifyImpact({
    id: 'primal-1', sourceId: 'test', sourceType: 'official', title: 'Primalist change',
    summary: 'Earthshaping stacks and Wildclaw damage changed for Primalist.'
  });
  assert.equal(result.significant, true);
  assert.ok(result.impacts.some(item => item.component === 'primalist-helper'));
});

test('rotation watch creates a natural Lua 5.1 feed and writes it into the installed guide', async () => {
  const item = classifyImpact({
    id: '900', sourceId: 'ascension-coa-changelog', sourceType: 'official',
    title: 'Changement CoA du 2026/08/24',
    summary: '[Chronomancer] Chaos Infusion has been reworked and now changes Melt Reality.',
    publishedAt: '2026-08-24T01:00:00Z', updatedAt: '2026-08-24T01:00:00Z',
    url: 'https://ascension.gg/en/changelog/4'
  });
  const report = { generatedAt: '2026-08-24T02:00:00Z', items: [item] };
  const feed = createRotationUpdateFeed(report);
  assert.equal(feed.items.length, 1);
  assert.deepEqual(feed.items[0].tags, ['Chronomancer']);
  assert.match(feed.items[0].friendly, /développeurs ont revu Chronomancer/);

  const lua = serializeRotationUpdateFeed(report);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1' }));
  assert.match(lua, /CoARotationUpdateFeed = \{/);

  const root = await mkdtemp(path.join(os.tmpdir(), 'coa-game-feed-'));
  const addonsDir = path.join(root, 'Interface', 'AddOns');
  const guideDir = path.join(addonsDir, 'CoARotationGuide');
  const stormDir = path.join(addonsDir, 'CoAStormbringerHelper');
  const primalDir = path.join(addonsDir, 'CoAPrimalistHelper');
  await Promise.all([guideDir, stormDir, primalDir].map(directory => mkdir(directory, { recursive: true })));
  const manager = new AddonManager({ dataDir: path.join(root, 'data'), canonicalPath: addonsDir, environmentPath: null });
  const result = await manager.writeRotationUpdateFeed(lua, feed);
  assert.equal(result.written, true);
  assert.equal(result.count, 1);
  assert.equal(result.paths.length, 3);
  assert.equal(await readFile(path.join(guideDir, 'CoARotationUpdates.lua'), 'utf8'), lua);
  assert.equal(await readFile(path.join(stormDir, 'CoAStormbringerUpdates.lua'), 'utf8'), lua);
  assert.equal(await readFile(path.join(primalDir, 'CoAPrimalistUpdates.lua'), 'utf8'), lua);
});

test('rank-by-rank changelog entries are grouped into one readable recommendation', () => {
  const entries = [1, 2, 3].map(rank => classifyImpact({
    id: String(rank), sourceId: 'ascension-coa-changelog', sourceType: 'official',
    title: 'Changement CoA du 2026/08/08',
    summary: `[Pyromancer] Firefall Rank ${rank} damage increased to ${100 + rank} from ${80 + rank}.`,
    publishedAt: `2026-08-08T10:0${rank}:00`, updatedAt: `2026-08-08T10:0${rank}:00`,
    url: 'https://ascension.gg/en/changelog/4'
  }));
  const grouped = groupRecommendations(entries);
  assert.equal(grouped.length, 1);
  assert.equal(grouped[0].rawIds.length, 3);
  assert.match(grouped[0].summary, /3 rangs ou variantes/);
});

test('weekly watch persists fingerprints and never proposes the same publication twice', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'coa-watch-'));
  const statePath = path.join(root, 'state.json');
  const reportPath = path.join(root, 'report.json');
  const fetchImpl = async url => {
    if (String(url).includes('/changelog?')) return Response.json(changelogPayload);
    if (String(url).includes('/article?page=')) return Response.json(newsPayload);
    if (String(url).includes('/srhinos/coa-datamine/commits?')) return Response.json(talentCommitPayload);
    return new Response('missing', { status: 404 });
  };

  const first = await runCoaWatch({
    statePath, reportPath, fetchImpl,
    now: () => new Date('2026-08-09T20:00:00Z')
  });
  assert.equal(first.newCount, 3);
  assert.equal(first.significantCount, 3);
  assert.equal(first.items.every(item => item.impacts.length > 0), true);

  const second = await runCoaWatch({
    statePath, reportPath, fetchImpl,
    now: () => new Date('2026-08-16T20:00:00Z')
  });
  assert.equal(second.newCount, 0);
  assert.equal(second.items.length, 3);
  assert.equal(second.items.every(item => item.new === false), true);

  const state = JSON.parse(await readFile(statePath, 'utf8'));
  assert.equal(Object.keys(state.seen).length, 4);
  assert.equal(state.lastCheckedAt, '2026-08-16T20:00:00.000Z');
});

test('weekly GitHub workflow runs the watch, tests it, and commits only watch state', async () => {
  const workflow = await readFile('.github/workflows/coa-watch.yml', 'utf8');
  assert.match(workflow, /schedule:/);
  assert.match(workflow, /npm run watch:coa/);
  assert.match(workflow, /npm test/);
  assert.match(workflow, /git add watch\/state\.json watch\/report\.json/);
});
