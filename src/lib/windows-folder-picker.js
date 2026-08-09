import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export async function selectWindowsDirectory(initialDirectory = '') {
  if (process.platform !== 'win32') throw new Error('Le sélecteur de dossier est disponible uniquement sous Windows');
  const initial = String(initialDirectory || '').replaceAll("'", "''");
  const script = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$shell = New-Object -ComObject Shell.Application
$folder = $shell.BrowseForFolder(0, 'Sélectionnez le dossier Interface\\AddOns de Project Ascension', 0, '${initial}')
if ($null -eq $folder) { exit 2 }
[Console]::Write($folder.Self.Path)
`;
  const encoded = Buffer.from(script, 'utf16le').toString('base64');
  try {
    const { stdout } = await execFileAsync('powershell.exe', ['-NoProfile', '-STA', '-EncodedCommand', encoded], {
      encoding: 'utf8', windowsHide: true, timeout: 5 * 60 * 1000
    });
    return stdout.replace(/^\uFEFF/, '').trim() || null;
  } catch (error) {
    if (error.code === 2) return null;
    throw new Error(`Impossible d’ouvrir le sélecteur de dossier : ${error.stderr?.trim() || error.message}`);
  }
}
