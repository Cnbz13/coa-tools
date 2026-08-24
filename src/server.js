import http from 'node:http';
import path from 'node:path';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { CombatAssistant } from './core/combat.js';
import { AddonManager } from './core/addons.js';
import { AddonOperationRegistry } from './core/addon-operations.js';
import { CoaWatchService } from './core/coa-watch.js';
import { UiManager } from './core/ui-manager.js';
import { Updater } from './core/updater.js';
import { UpdateMonitor } from './core/update-monitor.js';
import { ensureDir, readJson } from './lib/files.js';
import { selectWindowsDirectory } from './lib/windows-folder-picker.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const publicDir = path.join(root, 'public');
const dataDir = path.resolve(process.env.COA_DATA_DIR || path.join(root, 'data'));
const pkg = await readJson(path.join(root, 'package.json'));
const manifestUrl = process.env.COA_UPDATE_MANIFEST || 'https://github.com/Cnbz13/coa-tools/releases/latest/download/manifest.json';
await ensureDir(dataDir);

const combat = new CombatAssistant();
const addons = new AddonManager({ dataDir, manifestUrl, environmentPath: process.env.COA_ADDONS_DIR });
const addonOperations = new AddonOperationRegistry(addons);
const coaWatch = new CoaWatchService({
  dataDir,
  reportUrl: process.env.COA_WATCH_REPORT,
  gameFeedWriter: (luaContents, feed) => addons.writeRotationUpdateFeed(luaContents, feed)
});
const ui = new UiManager(dataDir);
const updater = new Updater({ currentVersion: pkg.version, manifestUrl, stagingDir: path.join(root, '.updates') });
const updateMonitor = new UpdateMonitor({ updater, ui, dataDir });

const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml' };
const json = (response, status, body) => { response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' }); response.end(JSON.stringify(body)); };
async function body(request) {
  let value = '';
  for await (const chunk of request) { value += chunk; if (value.length > 1_000_000) throw new Error('Request too large'); }
  return value ? JSON.parse(value) : {};
}

async function api(request, response, pathname) {
  if (request.method === 'GET' && pathname === '/api/status') return json(response, 200, { name: 'CoA Tools', version: pkg.version, platform: process.platform });
  if (request.method === 'GET' && pathname === '/api/combat') return json(response, 200, combat.status());
  if (request.method === 'POST' && pathname === '/api/combat/start') return json(response, 201, combat.start(await body(request)));
  if (request.method === 'POST' && pathname === '/api/combat/events') return json(response, 201, combat.event(await body(request)));
  if (request.method === 'POST' && pathname === '/api/combat/stop') return json(response, 200, combat.stop());
  if (request.method === 'GET' && pathname === '/api/ui') return json(response, 200, await ui.get());
  if (request.method === 'PUT' && pathname === '/api/ui') return json(response, 200, await ui.update(await body(request)));
  if (request.method === 'GET' && pathname === '/api/addons') return json(response, 200, await addons.inventory());
  if (request.method === 'PUT' && pathname === '/api/addons/path') return json(response, 200, await addons.setDirectory((await body(request)).path));
  if (request.method === 'POST' && pathname === '/api/addons/select-path') {
    const current = await addons.detectDirectory();
    const selected = await selectWindowsDirectory(current.directory);
    return json(response, 200, selected ? await addons.setDirectory(selected) : { cancelled: true });
  }
  if (request.method === 'POST' && pathname === '/api/addons/update-all') return json(response, 200, await addons.updateAll());
  if (request.method === 'GET' && pathname === '/api/addons/operations/current') return json(response, 200, { operation: addonOperations.current() });
  const operationMatch = pathname.match(/^\/api\/addons\/operations\/([0-9a-f-]+)$/i);
  if (operationMatch && request.method === 'GET') {
    const operation = addonOperations.get(operationMatch[1]);
    return operation ? json(response, 200, { operation }) : json(response, 404, { error: 'Opération addon introuvable' });
  }
  if (request.method === 'POST' && pathname === '/api/addons/operations') {
    const input = await body(request);
    return json(response, 202, { operation: addonOperations.start(input.action, input.component) });
  }
  const managedMatch = pathname.match(/^\/api\/addons\/managed\/([^/]+)\/(install|rollback)$/);
  if (managedMatch && request.method === 'POST') {
    const component = decodeURIComponent(managedMatch[1]);
    return json(response, 200, managedMatch[2] === 'install' ? await addons.install(component) : await addons.rollback(component, (await body(request)).backupId));
  }
  const exclusionMatch = pathname.match(/^\/api\/addons\/managed\/([^/]+)\/global-update-exclusion$/);
  if (exclusionMatch && request.method === 'PUT') {
    const component = decodeURIComponent(exclusionMatch[1]);
    return json(response, 200, await addons.setGlobalUpdateExclusion(component, (await body(request)).excluded));
  }
  if (request.method === 'GET' && pathname === '/api/updates/check') return json(response, 200, await updater.check());
  if (request.method === 'POST' && pathname === '/api/updates/download') return json(response, 200, await updater.downloadLatest());
  if (request.method === 'GET' && pathname === '/api/watch') return json(response, 200, await coaWatch.report());
  if (request.method === 'POST' && pathname === '/api/watch/check') return json(response, 200, await coaWatch.check());
  return json(response, 404, { error: 'Not found' });
}

export const server = http.createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url, 'http://localhost').pathname;
    if (pathname.startsWith('/api/')) return await api(request, response, pathname);
    const relative = pathname === '/' ? 'index.html' : decodeURIComponent(pathname.slice(1));
    const file = path.resolve(publicDir, relative);
    if (!file.startsWith(`${publicDir}${path.sep}`) || !(await stat(file)).isFile()) throw Object.assign(new Error('Not found'), { status: 404 });
    response.writeHead(200, { 'content-type': mime[path.extname(file)] || 'application/octet-stream', 'x-content-type-options': 'nosniff' });
    response.end(await readFile(file));
  } catch (error) { json(response, error.status || 400, { error: error.message }); }
});

if (process.env.NODE_ENV !== 'test') {
  const port = process.env.PORT === undefined ? 4173 : Number(process.env.PORT);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    console.error(`Invalid PORT: ${process.env.PORT}`);
    process.exit(1);
  }
  server.on('error', error => {
    console.error(`CoA Tools server failed: ${error.code || 'ERROR'} — ${error.message}`);
    process.exit(1);
  });
  server.listen(port, '127.0.0.1', () => {
    const actualPort = server.address().port;
    console.log(`CoA Tools ${pkg.version} — http://127.0.0.1:${actualPort}`);
    updateMonitor.start();
  });
}
