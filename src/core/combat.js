import { randomUUID } from 'node:crypto';

export class CombatAssistant {
  #encounter = null;

  start({ name = 'Encounter', phases = [] } = {}) {
    this.#encounter = {
      id: randomUUID(), name: String(name).slice(0, 80), startedAt: Date.now(), endedAt: null,
      phases: phases.map((phase, index) => ({ name: String(phase.name || `Phase ${index + 1}`).slice(0, 80), at: Number(phase.at) || 0 })),
      events: []
    };
    return this.status();
  }

  event({ label, offset = 0, severity = 'info' }) {
    if (!this.#encounter || this.#encounter.endedAt) throw new Error('No active encounter');
    const item = { id: randomUUID(), label: String(label).slice(0, 120), offset: Math.max(0, Number(offset) || 0), severity, createdAt: Date.now() };
    this.#encounter.events.push(item);
    return item;
  }

  stop() {
    if (!this.#encounter) throw new Error('No encounter');
    this.#encounter.endedAt ??= Date.now();
    return this.status();
  }

  status() {
    if (!this.#encounter) return { active: false, encounter: null };
    return { active: !this.#encounter.endedAt, elapsed: ((this.#encounter.endedAt || Date.now()) - this.#encounter.startedAt) / 1000, encounter: structuredClone(this.#encounter) };
  }
}
