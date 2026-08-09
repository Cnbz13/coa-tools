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
let combat, updateArtifact, addonInventory;

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
    <article class="managed-addon ${item.installed ? 'installed' : ''}">
      <div class="managed-top"><span class="badge coa">COA GÉRÉ</span><span class="state-dot">${item.installed ? 'Installé' : 'Absent'}</span></div>
      <h3>${escapeHtml(item.name)}</h3><p>${escapeHtml(item.notes || 'Addon officiel CoA distribué depuis GitHub.')}</p>
      <div class="version-row"><span>Locale <b>${escapeHtml(item.localVersion || '—')}</b></span><span>Distante <b>${escapeHtml(item.remoteVersion)}</b></span></div>
      <div class="button-row"><button class="primary" data-install="${escapeAttribute(item.component)}">${actionLabels[item.action]}</button>${item.canRollback ? `<button data-rollback="${escapeAttribute(item.component)}">Restaurer</button>` : ''}</div>
    </article>`).join('') : '<article class="empty-card">Les composants CoA seront affichés dès que le manifest GitHub sera accessible.</article>';
  renderRegularAddons();
  document.querySelectorAll('[data-install]').forEach(button => button.onclick = () => runAddonOperation(button, `/api/addons/managed/${encodeURIComponent(button.dataset.install)}/install`, 'Installation'));
  document.querySelectorAll('[data-rollback]').forEach(button => button.onclick = () => runAddonOperation(button, `/api/addons/managed/${encodeURIComponent(button.dataset.rollback)}/rollback`, 'Restauration'));
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
async function runAddonOperation(button, url, label) {
  const original = button.textContent; button.disabled = true; button.textContent = `${label}…`;
  try { const value = await api(url, { method: 'POST', body: '{}' }); addonInventory = value.inventory; renderAddons(); toast(`${label} terminée avec vérification SHA-256`); }
  catch (error) { button.disabled = false; button.textContent = original; toast(error.message); }
}
$('#refreshAddons').onclick = loadAddons;
$('#addonSearch').oninput = () => addonInventory && renderRegularAddons();
$('#saveAddonPath').onclick = async () => { try { addonInventory = await api('/api/addons/path', { method: 'PUT', body: JSON.stringify({ path: $('#addonPath').value }) }); renderAddons(); toast('Dossier AddOns mémorisé'); } catch (error) { toast(error.message); } };
$('#browseAddonPath').onclick = async () => { try { const value = await api('/api/addons/select-path', { method: 'POST', body: '{}' }); if (!value.cancelled) { addonInventory = value; renderAddons(); toast('Dossier AddOns mémorisé'); } } catch (error) { toast(error.message); } };
$('#updateAllAddons').onclick = async event => runAddonOperation(event.currentTarget, '/api/addons/update-all', 'Mise à jour globale');

async function loadUi() { const value = await api('/api/ui'); $('#theme').value = value.theme; $('#density').value = value.density; document.body.dataset.theme = value.theme; document.body.dataset.density = value.density; }
$('#saveUi').onclick = async () => { const value = await api('/api/ui', { method: 'PUT', body: JSON.stringify({ theme: $('#theme').value, density: $('#density').value }) }); document.body.dataset.theme = value.theme; document.body.dataset.density = value.density; toast('Interface enregistrée'); };
async function checkUpdates(automatic = false) { try { const value = await api('/api/updates/check'); updateArtifact = value.artifact; $('#updateStatus').textContent = value.available ? `Version ${value.manifest.version} disponible${updateArtifact ? '.' : ', sans artefact compatible.'}` : `Version ${value.currentVersion} à jour.`; $('#downloadUpdate').hidden = !(value.available && updateArtifact); if (automatic && value.available && updateArtifact) await downloadUpdate(); } catch (error) { $('#updateStatus').textContent = automatic ? 'Vérification automatique temporairement indisponible.' : error.message; } }
async function downloadUpdate() { try { $('#updateStatus').textContent = 'Téléchargement et vérification…'; const value = await api('/api/updates/download', { method: 'POST', body: '{}' }); $('#updateStatus').textContent = `Mise à jour vérifiée et prête : ${value.sha256.slice(0, 16)}…`; $('#downloadUpdate').hidden = true; } catch (error) { $('#updateStatus').textContent = error.message; } }
$('#checkUpdate').onclick = () => checkUpdates(false);
$('#downloadUpdate').onclick = downloadUpdate;
const status = await api('/api/status'); $('#version').textContent = `Version ${status.version}`; await Promise.all([loadCombat(), loadAddons(), loadUi()]); checkUpdates(true); setInterval(() => checkUpdates(true), 6 * 60 * 60 * 1000);
