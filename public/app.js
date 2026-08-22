const $ = selector => document.querySelector(selector);
const api = async (url, options = {}) => {
  const response = await fetch(url, { headers: { 'content-type': 'application/json' }, ...options });
  const value = await response.json();
  if (!response.ok) throw new Error(value.error || 'Erreur');
  return value;
};
const toast = message => { $('#toast').textContent = message; $('#toast').classList.add('show'); setTimeout(() => $('#toast').classList.remove('show'), 3000); };
const escapeHtml = value => { const node = document.createElement('span'); node.textContent = value ?? ''; return node.innerHTML; };
const escapeAttribute = value => escapeHtml(value).replaceAll('`', '&#96;');
const UPDATE_CHECK_INTERVAL_MS = 60 * 60 * 1000;
let combat, updateArtifact, updateVersion, addonInventory, addonOperation, addonPollTimer, coaWatch, uiPreferences, lastUpdateCheckAt = 0;

document.querySelectorAll('nav button').forEach(button => button.onclick = () => {
  document.querySelectorAll('nav button,.view').forEach(item => item.classList.remove('active'));
  button.classList.add('active'); $(`#${button.dataset.view}`).classList.add('active'); $('#title').textContent = button.textContent;
});
setInterval(() => $('#clock').textContent = new Intl.DateTimeFormat('fr-FR', { timeStyle: 'medium' }).format(new Date()), 1000);

async function loadCombat() { combat = await api('/api/combat'); renderCombat(); }
function renderCombat() {
  const current = combat.encounter;
  $('#encounterName').textContent = current?.name || 'Aucun affrontement';
  $('#elapsed').textContent = combat.active ? 'Suivi en cours — gardez le rythme.' : 'Prêt à suivre votre prochaine rencontre.';
  const seconds = Math.floor(combat.elapsed || 0);
  $('#timer').textContent = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
  const events = current?.events || [];
  $('#timeline').classList.toggle('empty', !events.length);
  $('#timeline').innerHTML = events.length ? events.map(item => `<div class="event"><span>${escapeHtml(item.label)}</span><b>+${item.offset}s</b></div>`).join('') : 'Les événements apparaîtront ici.';
}
setInterval(() => { if (combat?.active) { combat.elapsed++; renderCombat(); } }, 1000);
$('#startCombat').onclick = async () => { combat = await api('/api/combat/start', { method: 'POST', body: JSON.stringify({ name: $('#combatName').value }) }); renderCombat(); toast('Affrontement démarré'); };
$('#stopCombat').onclick = async () => { try { combat = await api('/api/combat/stop', { method: 'POST' }); renderCombat(); } catch (error) { toast(error.message); } };
$('#addEvent').onclick = async () => { const label = prompt('Nom de l’événement'); if (!label) return; await api('/api/combat/events', { method: 'POST', body: JSON.stringify({ label, offset: Math.floor(combat?.elapsed || 0) }) }); await loadCombat(); };

const actionLabels = { install: 'Installer', update: 'Mettre à jour', reinstall: 'Réinstaller' };
function renderAddons() {
  const inventory = addonInventory;
  $('#addonPathLabel').textContent = inventory.addonsDir;
  $('#addonPath').value = inventory.addonsDir;
  $('#addonDetection').textContent = inventory.exists ? (inventory.detectionSource === 'project-ascension' ? 'DÉTECTÉ AUTOMATIQUEMENT' : 'DOSSIER MÉMORISÉ') : 'DOSSIER INTROUVABLE';
  $('#addonDetection').classList.toggle('warning', !inventory.exists);
  $('#addonScanSummary').textContent = inventory.exists ? `${inventory.localCount} addons avec fichier .toc détectés.` : 'Sélectionnez votre dossier Interface\\AddOns dans la section avancée.';
  $('#manifestStatus').textContent = inventory.remoteError ? (inventory.remoteCached ? `Manifest v${inventory.remoteVersion} en cache` : `Manifest indisponible : ${inventory.remoteError}`) : `Manifest GitHub v${inventory.remoteVersion}`;
  $('#managedAddonList').innerHTML = inventory.managed.length ? inventory.managed.map(item => `
    <article class="managed-addon ${item.installed ? 'installed' : ''} ${item.excludedFromGlobalUpdates ? 'excluded' : ''}">
      <div class="managed-top"><span class="badge coa">${item.excludedFromGlobalUpdates ? 'EXCLU DES MAJ' : 'COA GÉRÉ'}</span><span class="state-dot">${item.installed ? 'Installé' : 'Absent'}</span></div>
      <h3>${escapeHtml(item.name)}</h3><p>${escapeHtml(item.notes || 'Addon officiel CoA distribué depuis GitHub.')}</p>
      <div class="version-row"><span>Locale <b>${escapeHtml(item.localVersion || '—')}</b></span><span>Distante <b>${escapeHtml(item.remoteVersion)}</b></span></div>
      <div class="button-row">
        <button class="primary" data-install="${escapeAttribute(item.component)}">${actionLabels[item.action]}</button>
        ${item.userManageable ? `<button data-exclusion="${escapeAttribute(item.component)}" data-excluded="${item.excludedFromGlobalUpdates}">${item.excludedFromGlobalUpdates ? 'Réinclure aux MAJ' : 'Exclure des MAJ'}</button>` : ''}
        ${item.userManageable && item.installed ? `<button class="danger" data-uninstall="${escapeAttribute(item.component)}">Désinstaller</button>` : ''}
        ${item.canRollback ? `<button data-rollback="${escapeAttribute(item.component)}">Restaurer</button>` : ''}
      </div>
    </article>`).join('') : '<article class="empty-card">Les composants CoA seront affichés dès que le manifest GitHub sera accessible.</article>';
  renderRegularAddons();
  document.querySelectorAll('[data-install]').forEach(button => button.onclick = () => startAddonOperation(button, { action: 'install', component: button.dataset.install }));
  document.querySelectorAll('[data-rollback]').forEach(button => button.onclick = () => runImmediateAddonOperation(button, `/api/addons/managed/${encodeURIComponent(button.dataset.rollback)}/rollback`, 'Restauration'));
  document.querySelectorAll('[data-exclusion]').forEach(button => button.onclick = () => toggleGlobalUpdateExclusion(button));
  document.querySelectorAll('[data-uninstall]').forEach(button => button.onclick = () => confirmAddonUninstall(button));
  renderAddonProgress();
}
async function toggleGlobalUpdateExclusion(button) {
  const excluded = button.dataset.excluded !== 'true';
  button.disabled = true;
  try {
    addonInventory = await api(`/api/addons/managed/${encodeURIComponent(button.dataset.exclusion)}/global-update-exclusion`, {
      method: 'PUT', body: JSON.stringify({ excluded })
    });
    renderAddons();
    toast(excluded ? 'Addon exclu des mises à jour globales' : 'Addon réintégré aux mises à jour globales');
  } catch (error) { renderAddons(); toast(error.message); }
}
function confirmAddonUninstall(button) {
  const item = addonInventory.managed.find(addon => addon.component === button.dataset.uninstall);
  if (!item) return;
  if (!confirm(`Désinstaller ${item.name} ?\n\nUne sauvegarde sera créée et l’addon sera exclu des mises à jour globales pour éviter sa réinstallation.`)) return;
  startAddonOperation(button, { action: 'uninstall', component: item.component });
}
function renderRegularAddons() {
  const query = $('#addonSearch').value.trim().toLocaleLowerCase('fr');
  const items = addonInventory.regular.filter(item => `${item.title} ${item.folder} ${item.notes}`.toLocaleLowerCase('fr').includes(query));
  $('#ascensionAddonList').innerHTML = items.length ? items.map(item => `<article class="addon"><div><div><span class="badge ascension">ASCENSION</span> <b>${escapeHtml(item.title)}</b></div><small>${escapeHtml(item.folder)} · ${escapeHtml(item.version)}</small>${item.notes ? `<p>${escapeHtml(item.notes)}</p>` : ''}</div></article>`).join('') : `<article class="empty-card">${addonInventory.exists ? 'Aucun addon ne correspond au filtre.' : 'Aucun dossier AddOns disponible.'}</article>`;
}
async function loadAddons() {
  try { addonInventory = await api('/api/addons'); renderAddons(); }
  catch (error) { toast(error.message); }
}
async function runImmediateAddonOperation(button, url, label) {
  const original = button.textContent; button.disabled = true; button.textContent = `${label}…`;
  try { const value = await api(url, { method: 'POST', body: '{}' }); addonInventory = value.inventory; renderAddons(); toast(`${label} terminée avec vérification SHA-256`); }
  catch (error) { button.disabled = false; button.textContent = original; toast(error.message); }
}

const activeAddonOperation = () => ['queued', 'running'].includes(addonOperation?.state);
const formatBytes = value => {
  if (!Number.isFinite(value)) return '';
  if (value < 1024) return `${value} o`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} Kio`;
  return `${(value / 1024 / 1024).toFixed(1)} Mio`;
};
const formatElapsed = startedAt => {
  const seconds = Math.max(0, Math.floor((Date.now() - Date.parse(startedAt)) / 1000));
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
};
function addonOperationName() {
  if (addonOperation?.action === 'update-all') return 'Mise à jour globale';
  return addonInventory?.managed.find(item => item.component === addonOperation?.component)?.name || addonOperation?.component || 'Addon CoA';
}
function renderAddonProgress() {
  const panel = $('#addonProgress');
  if (!panel) return;
  const globalButton = $('#updateAllAddons');
  const active = activeAddonOperation();
  globalButton.textContent = active && addonOperation?.action === 'update-all'
    ? `Mise à jour${addonOperation.total ? ` ${addonOperation.current}/${addonOperation.total}` : ''}…`
    : 'Tout mettre à jour';
  panel.hidden = !addonOperation;
  if (!addonOperation) return;
  panel.classList.toggle('running', active);
  panel.classList.toggle('success', addonOperation.state === 'succeeded');
  panel.classList.toggle('failed', addonOperation.state === 'failed');
  $('#addonProgressTitle').textContent = addonOperationName();
  $('#addonProgressMessage').textContent = addonOperation.message;
  $('#addonProgressBar').value = addonOperation.percent;
  $('#addonProgressPercent').textContent = `${addonOperation.percent}%`;
  $('#addonProgressElapsed').textContent = formatElapsed(addonOperation.startedAt);
  $('#addonProgressStep').textContent = addonOperation.total > 1 && addonOperation.current
    ? `Addon ${addonOperation.current}/${addonOperation.total} · ${addonOperation.step}`
    : addonOperation.step;
  $('#addonProgressBytes').textContent = Number.isFinite(addonOperation.bytesDone) && Number.isFinite(addonOperation.bytesTotal)
    ? `${formatBytes(addonOperation.bytesDone)} / ${formatBytes(addonOperation.bytesTotal)}` : '';
  document.querySelectorAll('[data-install], [data-rollback], [data-exclusion], [data-uninstall], #updateAllAddons').forEach(button => { button.disabled = active; });
}
async function pollAddonOperation() {
  clearTimeout(addonPollTimer);
  if (!addonOperation?.id || !activeAddonOperation()) return;
  try {
    const value = await api(`/api/addons/operations/${encodeURIComponent(addonOperation.id)}`);
    addonOperation = value.operation;
    if (!activeAddonOperation()) {
      if (addonOperation.state === 'succeeded') {
        addonInventory = addonOperation.result?.inventory || await api('/api/addons');
        renderAddons();
        toast(addonOperation.action === 'uninstall' ? 'Addon désinstallé avec sauvegarde' : 'Mise à jour terminée avec vérification SHA-256');
      } else {
        renderAddons();
        toast(addonOperation.error || 'La mise à jour a échoué');
      }
      return;
    }
    renderAddonProgress();
    addonPollTimer = setTimeout(pollAddonOperation, 500);
  } catch (error) {
    $('#addonProgressMessage').textContent = `Connexion au manager interrompue : ${error.message}. Nouvelle tentative…`;
    addonPollTimer = setTimeout(pollAddonOperation, 1500);
  }
}
async function startAddonOperation(button, input) {
  button.disabled = true;
  button.textContent = 'Démarrage…';
  try {
    const value = await api('/api/addons/operations', { method: 'POST', body: JSON.stringify(input) });
    addonOperation = value.operation;
    renderAddonProgress();
    pollAddonOperation();
  } catch (error) {
    renderAddons();
    toast(error.message);
  }
}
async function resumeAddonOperation() {
  try {
    const value = await api('/api/addons/operations/current');
    addonOperation = value.operation;
    renderAddonProgress();
    if (activeAddonOperation()) pollAddonOperation();
  } catch { /* L’inventaire reste utilisable si aucun historique n’est disponible. */ }
}
$('#refreshAddons').onclick = loadAddons;
$('#addonSearch').oninput = () => addonInventory && renderRegularAddons();
$('#saveAddonPath').onclick = async () => { try { addonInventory = await api('/api/addons/path', { method: 'PUT', body: JSON.stringify({ path: $('#addonPath').value }) }); renderAddons(); toast('Dossier AddOns mémorisé'); } catch (error) { toast(error.message); } };
$('#browseAddonPath').onclick = async event => {
  const button = event.currentTarget;
  const original = button.textContent;
  button.disabled = true;
  button.textContent = 'Ouverture…';
  toast('Ouverture du sélecteur Windows…');
  try {
    const value = await api('/api/addons/select-path', { method: 'POST', body: '{}' });
    if (!value.cancelled) {
      addonInventory = value;
      renderAddons();
      toast('Dossier AddOns mémorisé');
    }
  } catch (error) {
    toast(error.message);
  } finally {
    button.disabled = false;
    button.textContent = original;
  }
};
$('#updateAllAddons').onclick = event => startAddonOperation(event.currentTarget, { action: 'update-all' });

async function loadUi() {
  uiPreferences = await api('/api/ui');
  $('#theme').value = uiPreferences.theme;
  $('#density').value = uiPreferences.density;
  $('#autoUpdateAddons').checked = uiPreferences.autoUpdateAddons !== false;
  $('#managerUpdateAlerts').checked = uiPreferences.managerUpdateAlerts !== false;
  document.body.dataset.theme = uiPreferences.theme;
  document.body.dataset.density = uiPreferences.density;
}
$('#saveUi').onclick = async () => {
  uiPreferences = await api('/api/ui', { method: 'PUT', body: JSON.stringify({
    theme: $('#theme').value,
    density: $('#density').value,
    autoUpdateAddons: $('#autoUpdateAddons').checked,
    managerUpdateAlerts: $('#managerUpdateAlerts').checked
  }) });
  document.body.dataset.theme = uiPreferences.theme;
  document.body.dataset.density = uiPreferences.density;
  renderNotificationStatus();
  toast('Interface enregistrée');
};
async function startAutomaticAddonUpdates() {
  if (!uiPreferences?.autoUpdateAddons || !addonInventory?.exists || activeAddonOperation()) return;
  if (!addonInventory.managed.some(item => !item.excludedFromGlobalUpdates && ['install', 'update'].includes(item.action))) return;
  await startAddonOperation($('#updateAllAddons'), { action: 'update-all' });
}
function renderNotificationStatus() {
  const status = $('#notificationStatus');
  status.textContent = uiPreferences?.managerUpdateAlerts === false
    ? 'Alertes Windows désactivées. La vérification horaire reste active.'
    : 'Alertes Windows actives. Le manager vérifie GitHub toutes les heures, même si cet onglet est fermé.';
}
async function checkUpdates(automatic = false) {
  lastUpdateCheckAt = Date.now();
  try {
    const value = await api('/api/updates/check');
    updateArtifact = value.artifact;
    updateVersion = value.manifest.version;
    $('#updateStatus').textContent = value.available ? `Version ${updateVersion} disponible${updateArtifact ? '.' : ', sans artefact compatible.'}` : `Version ${value.currentVersion} à jour.`;
    $('#downloadUpdate').hidden = !(value.available && updateArtifact);
  } catch (error) { $('#updateStatus').textContent = automatic ? 'Vérification automatique temporairement indisponible.' : error.message; }
}
async function downloadUpdate(version = updateVersion) {
  try {
    $('#updateStatus').textContent = 'Téléchargement et vérification…';
    const value = await api('/api/updates/download', { method: 'POST', body: '{}' });
    $('#updateStatus').textContent = `Version ${version || ''} vérifiée et prête. Elle sera appliquée automatiquement au prochain lancement.`;
    $('#downloadUpdate').hidden = true;
    return value;
  } catch (error) { $('#updateStatus').textContent = error.message; return null; }
}
$('#checkUpdate').onclick = () => checkUpdates(false);
$('#downloadUpdate').onclick = () => downloadUpdate();

const watchComponentLabels = {
  'combat-assistant': 'Combat Assistant',
  'event-alert': 'EventAlertCoA',
  'grid-compat': 'GridCoA',
  'ui-manager': 'UI Manager'
};
const safeExternalUrl = value => {
  try { const url = new URL(value); return ['http:', 'https:'].includes(url.protocol) ? url.href : '#'; }
  catch { return '#'; }
};
function renderCoaWatch() {
  const items = coaWatch?.items || [];
  const generated = coaWatch?.generatedAt ? new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(coaWatch.generatedAt)) : 'jamais';
  const failed = Boolean(coaWatch?.remoteError && !coaWatch?.cached);
  $('#watchState').textContent = failed ? 'INDISPONIBLE' : coaWatch?.cached ? 'CACHE LOCAL' : 'À JOUR';
  $('#watchState').classList.toggle('warning', failed || coaWatch?.cached);
  $('#watchHeadline').textContent = failed
    ? 'Le rapport de veille n’est pas encore accessible.'
    : `${coaWatch?.newCount || 0} nouveauté(s), ${coaWatch?.significantCount || 0} changement(s) significatif(s)`;
  $('#watchDescription').textContent = failed
    ? coaWatch.remoteError
    : `Dernière vérification : ${generated}. Les recommandations restent soumises à validation avant modification des addons.`;
  $('#watchSources').innerHTML = (coaWatch?.sources || []).map(source => `
    <a href="${escapeAttribute(safeExternalUrl(source.url))}" target="_blank" rel="noreferrer" class="watch-source ${source.status}">
      <span>${source.status === 'ok' ? '✓' : '!'}</span><b>${escapeHtml(source.name)}</b><small>${source.status === 'ok' ? `${source.checked} élément(s) lus` : escapeHtml(source.error)}</small>
    </a>`).join('');
  $('#watchRecommendations').innerHTML = items.length ? items.slice(0, 30).map(item => `
    <article class="watch-item ${item.significant ? 'significant' : ''}">
      <div class="watch-item-top"><span class="badge">${item.new ? 'NOUVEAU' : escapeHtml(item.confidence || 'SUIVI').toUpperCase()}</span><time>${escapeHtml(new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium' }).format(new Date(item.publishedAt)))}</time></div>
      <h3>${escapeHtml(item.title)}</h3><p>${escapeHtml(item.summary)}</p>
      <div class="impact-list">${(item.impacts || []).map(impact => `<span>${escapeHtml(watchComponentLabels[impact.component] || impact.name)}</span>`).join('')}</div>
      <p class="watch-reason">${escapeHtml(item.reason)}</p>
      <a href="${escapeAttribute(safeExternalUrl(item.url))}" target="_blank" rel="noreferrer">Lire la source officielle ↗</a>
    </article>`).join('') : '<article class="empty-card">Aucun changement ayant un impact sur les addons n’a été détecté dans la période analysée.</article>';
}
async function loadCoaWatch() {
  try { coaWatch = await api('/api/watch'); renderCoaWatch(); }
  catch (error) { coaWatch = { items: [], sources: [], remoteError: error.message }; renderCoaWatch(); }
}
$('#checkCoaWatch').onclick = async event => {
  const button = event.currentTarget;
  button.disabled = true; button.textContent = 'Analyse en cours…';
  $('#watchHeadline').textContent = 'Lecture du changelog et des actualités officielles…';
  try { coaWatch = await api('/api/watch/check', { method: 'POST', body: '{}' }); renderCoaWatch(); toast('Veille CoA terminée'); }
  catch (error) { toast(error.message); await loadCoaWatch(); }
  finally { button.disabled = false; button.textContent = 'Vérifier maintenant'; }
};

const status = await api('/api/status');
$('#version').textContent = `Version ${status.version}`;
await Promise.all([loadCombat(), loadAddons(), loadUi()]);
await resumeAddonOperation();
await startAutomaticAddonUpdates();
renderNotificationStatus();
loadCoaWatch();
checkUpdates(true);
setInterval(() => checkUpdates(true), UPDATE_CHECK_INTERVAL_MS);
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && Date.now() - lastUpdateCheckAt > UPDATE_CHECK_INTERVAL_MS) checkUpdates(true);
});
setInterval(() => { if (activeAddonOperation()) renderAddonProgress(); }, 1000);
