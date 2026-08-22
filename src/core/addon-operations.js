import { randomUUID } from 'node:crypto';

const ACTIVE_STATES = new Set(['queued', 'running']);

function clampPercent(value) {
  return Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
}

export class AddonOperationRegistry {
  constructor(addons, { now = () => new Date(), schedule = queueMicrotask } = {}) {
    this.addons = addons;
    this.now = now;
    this.schedule = schedule;
    this.operations = new Map();
    this.currentId = null;
  }

  snapshot(operation) {
    if (!operation) return null;
    return {
      id: operation.id,
      action: operation.action,
      component: operation.component,
      state: operation.state,
      step: operation.step,
      message: operation.message,
      percent: operation.percent,
      current: operation.current,
      total: operation.total,
      bytesDone: operation.bytesDone,
      bytesTotal: operation.bytesTotal,
      startedAt: operation.startedAt,
      updatedAt: operation.updatedAt,
      finishedAt: operation.finishedAt,
      error: operation.error,
      result: operation.result
    };
  }

  current() {
    return this.snapshot(this.operations.get(this.currentId));
  }

  get(id) {
    return this.snapshot(this.operations.get(id));
  }

  start(action, component = null) {
    const active = this.operations.get(this.currentId);
    if (active && ACTIVE_STATES.has(active.state)) {
      const error = new Error('Une mise à jour d’addon est déjà en cours');
      error.status = 409;
      throw error;
    }
    if (!['install', 'uninstall', 'update-all'].includes(action)) {
      const error = new Error('Type d’opération addon inconnu');
      error.status = 400;
      throw error;
    }
    if (['install', 'uninstall'].includes(action) && !component) {
      const error = new Error('Composant addon manquant');
      error.status = 400;
      throw error;
    }

    const timestamp = this.now().toISOString();
    const operation = {
      id: randomUUID(), action, component, state: 'queued', step: 'queued',
      message: 'Mise en file d’attente…', percent: 0, current: action === 'update-all' ? 0 : 1,
      total: action === 'update-all' ? 0 : 1, bytesDone: null, bytesTotal: null,
      startedAt: timestamp, updatedAt: timestamp, finishedAt: null, error: null, result: null
    };
    this.operations.set(operation.id, operation);
    this.currentId = operation.id;
    this.trimHistory();
    this.schedule(() => this.run(operation));
    return this.snapshot(operation);
  }

  report(operation, update = {}) {
    if (!ACTIVE_STATES.has(operation.state)) return;
    const phasePercent = clampPercent(update.phasePercent ?? update.percent);
    const total = Number.isInteger(update.total) ? update.total : operation.total;
    const current = Number.isInteger(update.index) ? update.index : operation.current;
    let percent = phasePercent;
    if (total > 1 && current > 0) percent = clampPercent(((current - 1) + phasePercent / 100) / total * 100);
    operation.state = 'running';
    operation.step = update.step || operation.step;
    operation.message = update.message || operation.message;
    operation.component = update.component || operation.component;
    operation.percent = percent;
    operation.current = current;
    operation.total = total;
    operation.bytesDone = Number.isFinite(update.bytesDone) ? update.bytesDone : null;
    operation.bytesTotal = Number.isFinite(update.bytesTotal) ? update.bytesTotal : null;
    operation.updatedAt = this.now().toISOString();
  }

  async run(operation) {
    operation.state = 'running';
    operation.step = 'starting';
    operation.message = 'Démarrage de l’opération…';
    operation.updatedAt = this.now().toISOString();
    const report = update => this.report(operation, update);
    try {
      operation.result = operation.action === 'update-all'
        ? await this.addons.updateAll(report)
        : operation.action === 'uninstall'
          ? await this.addons.uninstall(operation.component, report)
          : await this.addons.install(operation.component, report);
      operation.state = 'succeeded';
      operation.step = 'complete';
      operation.message = operation.action === 'update-all'
        ? 'Mise à jour globale terminée'
        : operation.action === 'uninstall' ? 'Addon désinstallé avec sauvegarde' : 'Addon installé et vérifié';
      operation.percent = 100;
    } catch (error) {
      operation.state = 'failed';
      operation.step = 'failed';
      operation.error = error?.message || String(error);
      operation.message = `Échec : ${operation.error}`;
    } finally {
      const timestamp = this.now().toISOString();
      operation.updatedAt = timestamp;
      operation.finishedAt = timestamp;
      operation.bytesDone = null;
      operation.bytesTotal = null;
    }
  }

  trimHistory() {
    if (this.operations.size <= 20) return;
    for (const [id, operation] of this.operations) {
      if (id !== this.currentId && !ACTIVE_STATES.has(operation.state)) this.operations.delete(id);
      if (this.operations.size <= 20) break;
    }
  }
}
