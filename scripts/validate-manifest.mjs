import { readFile } from 'node:fs/promises';

const file = process.argv[2] || 'manifest.json';
const manifest = JSON.parse(await readFile(file, 'utf8'));
const errors = [];
if (manifest.schemaVersion !== 1) errors.push('schemaVersion must be 1');
if (manifest.name !== 'CoA Tools') errors.push('name must be CoA Tools');
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(manifest.version || '')) errors.push('invalid semantic version');
if (!['stable', 'beta', 'nightly'].includes(manifest.channel)) errors.push('invalid channel');
if (Number.isNaN(Date.parse(manifest.publishedAt))) errors.push('invalid publishedAt');
if (!Array.isArray(manifest.artifacts)) errors.push('artifacts must be an array');
for (const [index, artifact] of (manifest.artifacts || []).entries()) {
  if (!artifact.name || !artifact.component) errors.push(`artifact ${index}: missing identity`);
  if (artifact.version !== manifest.version) errors.push(`artifact ${index}: version mismatch`);
  if (!/^[A-Za-z0-9._-]+$/.test(artifact.targetFolder || '')) errors.push(`artifact ${index}: invalid target folder`);
  if (!/^[a-f0-9]{64}$/.test(artifact.sha256 || '')) errors.push(`artifact ${index}: invalid SHA-256`);
  if (!Number.isInteger(artifact.size) || artifact.size < 1) errors.push(`artifact ${index}: invalid size`);
  try { new URL(artifact.url); } catch { errors.push(`artifact ${index}: invalid URL`); }
}
if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
console.log(`${file}: valid (${manifest.version}, ${manifest.artifacts.length} artifacts)`);
