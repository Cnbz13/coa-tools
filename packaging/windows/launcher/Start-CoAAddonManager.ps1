$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$appRoot = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $appRoot 'runtime'
$nodePath = Join-Path $runtimeDir 'node.exe'
$nodeVersion = '24.14.0'
$archiveName = "node-v$nodeVersion-win-x64.zip"
$nodeBaseUrl = "https://nodejs.org/dist/v$nodeVersion"

if (-not (Test-Path -LiteralPath $nodePath)) {
    Write-Host 'Premier lancement : installation du moteur sécurisé CoA Tools...'
    $temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("coa-runtime-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary | Out-Null
    try {
        $archive = Join-Path $temporary $archiveName
        Invoke-WebRequest "$nodeBaseUrl/$archiveName" -OutFile $archive -UseBasicParsing
        $checksums = (Invoke-WebRequest "$nodeBaseUrl/SHASUMS256.txt" -UseBasicParsing).Content
        $line = ($checksums -split "`n" | Where-Object { $_ -match "\s$([regex]::Escape($archiveName))\s*$" } | Select-Object -First 1)
        if (-not $line) { throw 'Empreinte officielle Node.js introuvable.' }
        $expected = ($line.Trim() -split '\s+')[0].ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw 'Échec de la vérification SHA-256 du moteur Node.js.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $temporary -Force
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temporary "node-v$nodeVersion-win-x64\node.exe") -Destination $nodePath -Force
    }
    finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$url = 'http://127.0.0.1:4173/'
try {
    Invoke-RestMethod "$url/api/status" -TimeoutSec 2 | Out-Null
}
catch {
    $env:COA_DATA_DIR = Join-Path $env:LOCALAPPDATA 'CoAAddonManager\data'
    $env:COA_ADDONS_DIR = Join-Path $env:LOCALAPPDATA 'CoAAddonManager\addons'
    $env:COA_UPDATE_MANIFEST = 'https://github.com/Cnbz13/coa-tools/releases/latest/download/manifest.json'
    Start-Process -FilePath $nodePath -ArgumentList 'src/server.js' -WorkingDirectory $appRoot -WindowStyle Hidden | Out-Null
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 200
        try {
            Invoke-RestMethod "$url/api/status" -TimeoutSec 2 | Out-Null
            $ready = $true
            break
        }
        catch { }
    }
    if (-not $ready) { throw 'CoA Addon Manager ne démarre pas. Vérifiez le port 4173.' }
}

Start-Process $url
