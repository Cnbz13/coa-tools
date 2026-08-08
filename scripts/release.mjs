import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

const pkg = JSON.parse(await readFile('package.json', 'utf8'));
const version = process.env.RELEASE_VERSION || pkg.version;
const output = path.resolve('dist');
const stage = path.join(output, `coa-tools-${version}`);
await rm(output, { recursive: true, force: true });
await mkdir(stage, { recursive: true });
for (const item of ['package.json', 'manifest.json', 'README.md', 'LICENSE', 'SECURITY.md', 'src', 'public', 'schemas']) await cp(item, path.join(stage, item), { recursive: true });
await writeFile(path.join(stage, 'package.json'), `${JSON.stringify({ ...pkg, version }, null, 2)}\n`);

// A dependency-free tar archive is portable across GitHub runners and Node platforms.
const { spawnSync } = await import('node:child_process');
const archive = path.join(output, `coa-tools-${version}.tgz`);
const result = spawnSync('tar', ['-czf', archive, '-C', output, path.basename(stage)], { stdio: 'inherit' });
if (result.status !== 0) throw new Error('tar failed');
const bytes = await readFile(archive);
const digest = createHash('sha256').update(bytes).digest('hex');
await writeFile(`${archive}.sha256`, `${digest}  ${path.basename(archive)}\n`);
const manifest = {
  schemaVersion: 1, name: 'CoA Tools', version, channel: process.env.RELEASE_CHANNEL || 'stable',
  publishedAt: new Date().toISOString(), minimumNodeVersion: '20.0.0',
  releaseUrl: `https://github.com/Cnbz13/coa-tools/releases/tag/v${version}`,
  artifacts: [{ platform: 'any', arch: 'any', file: path.basename(archive), url: `https://github.com/Cnbz13/coa-tools/releases/download/v${version}/${path.basename(archive)}`, sha256: digest, size: (await stat(archive)).size }]
};
await writeFile(path.join(output, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Release ${version}: ${digest}`);
