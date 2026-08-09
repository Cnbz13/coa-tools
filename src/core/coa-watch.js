import { createHash } from 'node:crypto';
import path from 'node:path';
import { readJson, writeJsonAtomic } from '../lib/files.js';

export const COA_WATCH_SOURCES = Object.freeze({
  changelog: {
    id: 'ascension-coa-changelog',
    name: 'Changelog officiel Conquest of Azeroth',
    api: 'https://api.ascension.gg/api/v3/article/changelog?realm_type=4&page=',
    page: 'https://ascension.gg/en/changelog/4',
    primary: true
  },
  news: {
    id: 'ascension-news',
    name: 'Actualités officielles Ascension',
    api: 'https://api.ascension.gg/api/v3/article?page=',
    page: 'https://ascension.gg/en/news/board',
    primary: true
  }
});

const COA_NEWS_MARKERS = [
  'conquest of azeroth', 'rexxar', 'necromancer', 'pyromancer', 'cultist',
  'starcaller', 'sun cleric', 'tinker', 'runemaster', 'primalist', 'reaper',
  'venomancer', 'chronomancer', 'bloodmage', 'stormbringer', 'felsworn',
  'witch doctor', 'witch hunter', 'knight of xoroth'
];

const IMPACT_RULES = [
  {
    component: 'combat-assistant', name: 'CoA Combat Assistant',
    keywords: [
      'necromancer', 'animation', 'crypt swarm', 'command:', 'runic',
      'chromatic damage', 'creature vulnerabilities', 'combat log'
    ],
    suggestion: 'Réexaminer les priorités, ressources, portées et conditions de la recommandation.'
  },
  {
    component: 'event-alert', name: 'EventAlertCoA',
    keywords: ['buff', 'debuff', 'aura', 'proc', 'trigger', 'stack', 'charges', 'duration'],
    suggestion: 'Vérifier la détection des procs, effets, charges et durées concernées.'
  },
  {
    component: 'grid-compat', name: 'GridCoA',
    keywords: ['dispel', 'curse', 'magic effect', 'poison', 'disease', 'control', 'sleep', 'fear', 'stun', 'silence', 'root', 'crowd control'],
    suggestion: 'Vérifier le type de debuff et sa compatibilité avec les dispels réellement appris.'
  },
  {
    component: 'ui-manager', name: 'CoA UI Manager',
    keywords: ['interface', 'frame', 'action bar', 'secure', 'combat lockdown', 'addon'],
    suggestion: 'Auditer les frames ou API 3.3.5 affectées avant toute modification.'
  }
];

const decodeHtml = value => String(value || '')
  .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
  .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
  .replace(/<[^>]+>/g, ' ')
  .replace(/&nbsp;/gi, ' ')
  .replace(/&amp;/gi, '&')
  .replace(/&quot;/gi, '"')
  .replace(/&#39;|&apos;/gi, "'")
  .replace(/&lt;/gi, '<')
  .replace(/&gt;/gi, '>')
  .replace(/\s+/g, ' ')
  .trim();

const fingerprint = item => createHash('sha256')
  .update(`${item.sourceId}\n${item.id}\n${item.updatedAt || item.publishedAt}\n${item.summary}`)
  .digest('hex');

const asTime = value => {
  const result = Date.parse(value || '');
  return Number.isFinite(result) ? result : 0;
};

export function flattenChangelog(payload, page = 1) {
  const entries = [];
  for (const [date, categories] of Object.entries(payload?.data || {})) {
    for (const values of Object.values(categories || {})) {
      if (!Array.isArray(values)) continue;
      for (const value of values) {
        const summary = decodeHtml(value.description);
        if (!summary) continue;
        entries.push({
          id: String(value.id), sourceId: COA_WATCH_SOURCES.changelog.id,
          sourceName: COA_WATCH_SOURCES.changelog.name, sourceType: 'official',
          title: `Changement CoA du ${date}`, summary,
          publishedAt: value.created_at || date.replaceAll('/', '-'),
          updatedAt: value.updated_at || value.created_at,
          url: page === 1 ? COA_WATCH_SOURCES.changelog.page : `${COA_WATCH_SOURCES.changelog.page}?page=${page}`
        });
      }
    }
  }
  return entries.sort((a, b) => asTime(b.updatedAt) - asTime(a.updatedAt));
}

export function normalizeNews(payload) {
  return (Array.isArray(payload?.data) ? payload.data : []).map(value => {
    const title = decodeHtml(value.title);
    const summary = decodeHtml(value.description || value.content).slice(0, 800);
    const searchable = `${title} ${summary} ${decodeHtml(value.content)}`.toLocaleLowerCase('en');
    return {
      id: String(value.id), sourceId: COA_WATCH_SOURCES.news.id,
      sourceName: COA_WATCH_SOURCES.news.name, sourceType: 'official',
      title, summary, relevant: COA_NEWS_MARKERS.some(marker => searchable.includes(marker)),
      publishedAt: value.published_at || value.created_at,
      updatedAt: value.updated_at || value.published_at || value.created_at,
      url: `https://ascension.gg/en/news/${encodeURIComponent(value.slug)}/${value.id}`
    };
  }).filter(item => item.title && item.summary);
}

export function classifyImpact(item) {
  const searchable = `${item.title} ${item.summary}`.toLocaleLowerCase('en');
  const impacts = IMPACT_RULES.filter(rule => rule.keywords.some(keyword => searchable.includes(keyword)))
    .map(({ keywords, ...impact }) => impact);
  const numericChange = /\b(?:increased|decreased|reduced|from|to|cooldown|duration|cost|damage|healing)\b/i.test(searchable);
  const breakingChange = /\b(?:removed|reworked|replaced|no longer|new spell|new talent|fixed an issue|fixed a bug)\b/i.test(searchable);
  const significant = impacts.length > 0 && (numericChange || breakingChange || /necromancer|dispel|proc|interface|combat log/i.test(searchable));
  return {
    ...item,
    impacts,
    significant,
    confidence: item.sourceType === 'official' ? (significant ? 'élevée' : 'moyenne') : 'faible',
    reason: impacts.length
      ? impacts.map(impact => `${impact.name} : ${impact.suggestion}`).join(' ')
      : 'Information conservée pour suivi, sans impact technique direct détecté.'
  };
}

const recommendationGroupKey = item => {
  if (item.sourceId !== COA_WATCH_SOURCES.changelog.id) return `${item.sourceId}:${item.id}`;
  const normalized = item.summary.toLocaleLowerCase('en')
    .replace(/\[(?:pending restart|live now|new|change)\]/g, ' ')
    .replace(/\bpending restart\b/g, ' ')
    .replace(/\brank\s+\d+\b/g, 'rank')
    .replace(/\b\d+(?:[.,]\d+)?(?:\s*[-–]\s*\d+(?:[.,]\d+)?)?%?\b/g, '#')
    .replace(/\s+/g, ' ')
    .trim();
  return `${item.sourceId}:${String(item.publishedAt).slice(0, 10)}:${normalized}`;
};

export function groupRecommendations(items) {
  const groups = new Map();
  for (const item of items) {
    const key = recommendationGroupKey(item);
    const existing = groups.get(key);
    if (!existing) {
      groups.set(key, { ...item, rawIds: [item.id] });
      continue;
    }
    existing.rawIds.push(item.id);
    if (asTime(item.updatedAt) > asTime(existing.updatedAt)) {
      existing.updatedAt = item.updatedAt;
      existing.publishedAt = item.publishedAt;
      existing.url = item.url;
    }
    const impacts = new Map(existing.impacts.map(impact => [impact.component, impact]));
    for (const impact of item.impacts) impacts.set(impact.component, impact);
    existing.impacts = [...impacts.values()];
    existing.significant = existing.significant || item.significant;
  }
  return [...groups.values()].map(item => {
    if (item.rawIds.length === 1) return item;
    const digest = createHash('sha256').update(recommendationGroupKey(item)).digest('hex').slice(0, 16);
    return {
      ...item,
      id: `group-${digest}`,
      title: `${item.rawIds.length} changements CoA regroupés`,
      summary: `${item.rawIds.length} rangs ou variantes du même changement ont été regroupés. Exemple : ${item.summary}`
    };
  });
}

async function fetchJson(fetchImpl, url) {
  const response = await fetchImpl(url, {
    headers: { accept: 'application/json', 'user-agent': 'CoA-Tools-Watch/1.0' },
    signal: AbortSignal.timeout(30_000)
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} pour ${url}`);
  return response.json();
}

async function fetchChangelog(fetchImpl, since) {
  const items = [];
  let totalPages = 1;
  for (let page = 1; page <= Math.min(totalPages, 12); page++) {
    const payload = await fetchJson(fetchImpl, `${COA_WATCH_SOURCES.changelog.api}${page}`);
    totalPages = Number(payload.last_page) || 1;
    const pageItems = flattenChangelog(payload, page);
    items.push(...pageItems);
    const oldest = Math.min(...pageItems.map(item => asTime(item.updatedAt)).filter(Boolean));
    if (page > 1 && Number.isFinite(oldest) && oldest < since) break;
  }
  return items;
}

async function fetchNews(fetchImpl, since) {
  const items = [];
  let totalPages = 1;
  for (let page = 1; page <= Math.min(totalPages, 5); page++) {
    const payload = await fetchJson(fetchImpl, `${COA_WATCH_SOURCES.news.api}${page}`);
    totalPages = Number(payload.last_page) || 1;
    const pageItems = normalizeNews(payload);
    items.push(...pageItems);
    const oldest = Math.min(...pageItems.map(item => asTime(item.updatedAt)).filter(Boolean));
    if (page > 1 && Number.isFinite(oldest) && oldest < since) break;
  }
  return items;
}

export async function runCoaWatch({
  statePath, reportPath, fetchImpl = fetch, now = () => new Date(), initialLookbackDays = 7
}) {
  const checkedAt = now();
  const state = await readJson(statePath, { schemaVersion: 1, lastCheckedAt: null, seen: {} });
  const previousReport = await readJson(reportPath, { items: [] });
  const previousCheck = asTime(state.lastCheckedAt);
  const since = previousCheck || checkedAt.getTime() - initialLookbackDays * 86_400_000;
  const sourceResults = [];
  const fetched = [];

  for (const [source, loader] of [
    [COA_WATCH_SOURCES.changelog, fetchChangelog],
    [COA_WATCH_SOURCES.news, fetchNews]
  ]) {
    try {
      const items = await loader(fetchImpl, since - 86_400_000);
      fetched.push(...items);
      sourceResults.push({ id: source.id, name: source.name, url: source.page, status: 'ok', checked: items.length, primary: source.primary });
    } catch (error) {
      sourceResults.push({ id: source.id, name: source.name, url: source.page, status: 'error', error: error.message, checked: 0, primary: source.primary });
    }
  }

  if (!sourceResults.some(source => source.status === 'ok')) {
    throw new Error(`Veille CoA indisponible : ${sourceResults.map(source => source.error).filter(Boolean).join(' ; ')}`);
  }

  const nextSeen = { ...(state.seen || {}) };
  const rawNewItems = [];
  for (const item of fetched) {
    const key = `${item.sourceId}:${item.id}`;
    const currentFingerprint = fingerprint(item);
    const changed = nextSeen[key] !== currentFingerprint;
    nextSeen[key] = currentFingerprint;
    if (!changed || asTime(item.updatedAt) < since) continue;
    if (item.sourceId === COA_WATCH_SOURCES.news.id && !item.relevant) continue;
    const classified = classifyImpact(item);
    if (classified.impacts.length) rawNewItems.push({ ...classified, new: true });
  }

  const newItems = groupRecommendations(rawNewItems);

  const unique = new Map();
  for (const item of [...newItems, ...(previousReport.items || []).map(item => ({ ...item, new: false }))]) {
    unique.set(`${item.sourceId}:${item.id}:${item.updatedAt}`, item);
  }
  const items = [...unique.values()]
    .sort((a, b) => asTime(b.updatedAt) - asTime(a.updatedAt))
    .slice(0, 100);
  const report = {
    schemaVersion: 1,
    generatedAt: checkedAt.toISOString(),
    previousCheckAt: state.lastCheckedAt,
    newCount: newItems.length,
    rawNewCount: rawNewItems.length,
    significantCount: newItems.filter(item => item.significant).length,
    sources: sourceResults,
    items
  };
  const seenEntries = Object.entries(nextSeen).slice(-10_000);
  await writeJsonAtomic(statePath, { schemaVersion: 1, lastCheckedAt: checkedAt.toISOString(), seen: Object.fromEntries(seenEntries) });
  await writeJsonAtomic(reportPath, report);
  return report;
}

export class CoaWatchService {
  constructor({ dataDir, reportUrl = 'https://raw.githubusercontent.com/Cnbz13/coa-tools/main/watch/report.json', fetchImpl = fetch }) {
    this.fetchImpl = fetchImpl;
    this.reportUrl = reportUrl;
    this.statePath = path.join(dataDir, 'coa-watch-state.json');
    this.reportPath = path.join(dataDir, 'coa-watch-report.json');
  }

  async report() {
    try {
      const remote = await fetchJson(this.fetchImpl, this.reportUrl);
      await writeJsonAtomic(this.reportPath, remote);
      return { ...remote, remote: true, cached: false };
    } catch (error) {
      const cached = await readJson(this.reportPath, null);
      if (cached) return { ...cached, remote: false, cached: true, remoteError: error.message };
      return { schemaVersion: 1, generatedAt: null, newCount: 0, significantCount: 0, sources: [], items: [], remote: false, cached: false, remoteError: error.message };
    }
  }

  async check() {
    return { ...(await runCoaWatch({ statePath: this.statePath, reportPath: this.reportPath, fetchImpl: this.fetchImpl })), remote: false, cached: false };
  }
}
