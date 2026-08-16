import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export async function selectWindowsDirectory(initialDirectory = '') {
  if (process.platform !== 'win32') throw new Error('Le sélecteur de dossier est disponible uniquement sous Windows');
  const initial = String(initialDirectory || '').replaceAll("'", "''");
  const script = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Windows.Forms

$owner = New-Object System.Windows.Forms.Form
$owner.ShowInTaskbar = $false
$owner.TopMost = $true
$owner.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$owner.Size = New-Object System.Drawing.Size(1, 1)
$owner.Opacity = 0

$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = 'Sélectionnez le dossier Interface\\AddOns de Project Ascension'
$dialog.ShowNewFolderButton = $false
if (Test-Path -LiteralPath '${initial}' -PathType Container) {
  $dialog.SelectedPath = '${initial}'
}

try {
  $owner.Show()
  $owner.Activate()
  $result = $dialog.ShowDialog($owner)
}
finally {
  $owner.Close()
  $owner.Dispose()
}

if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
  $dialog.Dispose()
  exit 2
}
$selectedPath = $dialog.SelectedPath
$dialog.Dispose()
[Console]::Write($selectedPath)
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
