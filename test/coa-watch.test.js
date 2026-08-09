import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { classifyImpact, flattenChangelog, groupRecommendations, normalizeNews, runCoaWatch } from '../src/core/coa-watch.js';

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
    'combat-assistant', 'event-alert', 'grid-compat', 'ui-manager'
  ]);
  assert.equal(result.confidence, 'élevée');
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
    return new Response('missing', { status: 404 });
  };

  const first = await runCoaWatch({
    statePath, reportPath, fetchImpl,
    now: () => new Date('2026-08-09T20:00:00Z')
  });
  assert.equal(first.newCount, 2);
  assert.equal(first.significantCount, 2);
  assert.equal(first.items.every(item => item.impacts.length > 0), true);

  const second = await runCoaWatch({
    statePath, reportPath, fetchImpl,
    now: () => new Date('2026-08-16T20:00:00Z')
  });
  assert.equal(second.newCount, 0);
  assert.equal(second.items.length, 2);
  assert.equal(second.items.every(item => item.new === false), true);

  const state = JSON.parse(await readFile(statePath, 'utf8'));
  assert.equal(Object.keys(state.seen).length, 3);
  assert.equal(state.lastCheckedAt, '2026-08-16T20:00:00.000Z');
});

test('weekly GitHub workflow runs the watch, tests it, and commits only watch state', async () => {
  const workflow = await readFile('.github/workflows/coa-watch.yml', 'utf8');
  assert.match(workflow, /schedule:/);
  assert.match(workflow, /npm run watch:coa/);
  assert.match(workflow, /npm test/);
  assert.match(workflow, /git add watch\/state\.json watch\/report\.json/);
});
