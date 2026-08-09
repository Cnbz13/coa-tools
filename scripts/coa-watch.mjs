import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runCoaWatch } from '../src/core/coa-watch.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const report = await runCoaWatch({
  statePath: path.join(root, 'watch', 'state.json'),
  reportPath: path.join(root, 'watch', 'report.json')
});

console.log(`Veille CoA terminée : ${report.newCount} nouvelle(s), ${report.significantCount} significative(s).`);
for (const source of report.sources) {
  console.log(`- ${source.name}: ${source.status}${source.status === 'ok' ? ` (${source.checked} éléments lus)` : ` — ${source.error}`}`);
}
