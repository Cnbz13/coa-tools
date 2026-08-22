$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-CoAStatus([int]$Port) {
    $response = $null
    $reader = $null
    try {
        $request = [Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/api/status")
        $request.Proxy = $null
        $request.Timeout = 1000
        $request.ReadWriteTimeout = 1000
        $response = $request.GetResponse()
        $reader = New-Object IO.StreamReader($response.GetResponseStream(), [Text.Encoding]::UTF8)
        $status = ($reader.ReadToEnd() | ConvertFrom-Json)
        if ($status.name -eq 'CoA Tools') { return $status }
    }
    catch { return $null }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($response) { $response.Dispose() }
    }
    return $null
}

function Test-PortAvailable([int]$Port) {
    $listener = $null
    try {
        $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        return $true
    }
    catch { return $false }
    finally { if ($listener) { $listener.Stop() } }
}

function Get-FreePort {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally { $listener.Stop() }
}

function Read-Log([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8).Trim() }
    return ''
}

function Compare-CoAVersion([string]$Left, [string]$Right) {
    try { return ([Version]$Left).CompareTo([Version]$Right) }
    catch { return 0 }
}

function Get-Sha256Hex([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Stop-CoAManagerProcesses {
    try {
        $runtimePrefix = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
        $processes = Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue
        foreach ($process in $processes) {
            $executable = if ($process.ExecutablePath) { [IO.Path]::GetFullPath($process.ExecutablePath) } else { '' }
            $isManagedRuntime = $executable.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)
            $isManagerServer = $process.CommandLine -match '(?i)src[\\/]server\.js'
            if ($isManagedRuntime -and $isManagerServer) {
                Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
                Write-Host "Ancien CoA Addon Manager arrete (PID $($process.ProcessId))."
            }
        }
    }
    catch { Write-Warning "Impossible d'arreter un ancien manager : $($_.Exception.Message)" }
}

function Test-ManagerArchiveEntries([string]$Archive) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            $segments = $name.Split('/')
            if ($name.StartsWith('/') -or -not $name.StartsWith('CoAAddonManager/') -or $segments -contains '..') {
                throw "Chemin ZIP non autorise : $name"
            }
        }
    }
    finally { $zip.Dispose() }
}

function Apply-PendingManagerUpdate([string]$CurrentVersion) {
    $readyFile = Join-Path $updatesRoot 'ready.json'
    if (-not (Test-Path -LiteralPath $readyFile -PathType Leaf)) { return $false }
    $ready = Get-Content -LiteralPath $readyFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $archive = [IO.Path]::GetFullPath([string]$ready.file)
    $updatesPrefix = [IO.Path]::GetFullPath($updatesRoot).TrimEnd('\') + '\'
    if (-not $archive.StartsWith($updatesPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive de mise a jour hors du dossier autorise.' }
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) { throw 'Archive de mise a jour introuvable.' }
    if ([string]$ready.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'SHA-256 de mise a jour invalide.' }
    $actualHash = Get-Sha256Hex $archive
    if ($actualHash -ne ([string]$ready.sha256).ToLowerInvariant()) { throw 'Echec de verification SHA-256 de la mise a jour.' }
    if ($ready.size -and (Get-Item -LiteralPath $archive).Length -ne [int64]$ready.size) { throw 'Taille de mise a jour invalide.' }
    Test-ManagerArchiveEntries $archive

    $temporary = Join-Path ([IO.Path]::GetTempPath()) ("coa-manager-update-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $archive -DestinationPath $temporary -Force
        $newRoot = Join-Path $temporary 'CoAAddonManager'
        $newPackageFile = Join-Path $newRoot 'package.json'
        if (-not (Test-Path -LiteralPath $newPackageFile -PathType Leaf)) { throw 'Package manager absent de la mise a jour.' }
        $newPackage = Get-Content -LiteralPath $newPackageFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ((Compare-CoAVersion ([string]$newPackage.version) $CurrentVersion) -le 0) {
            Remove-Item -LiteralPath $readyFile -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
            return $false
        }
        if ($ready.version -and [string]$ready.version -ne [string]$newPackage.version) { throw 'Version du package incoherente.' }
        Stop-CoAManagerProcesses
        Start-Sleep -Milliseconds 300
        foreach ($item in Get-ChildItem -LiteralPath $newRoot -Force) {
            Copy-Item -LiteralPath $item.FullName -Destination $appRoot -Recurse -Force
        }
        Remove-Item -LiteralPath $readyFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Write-Host "CoA Addon Manager mis a jour automatiquement : $CurrentVersion -> $($newPackage.version)"
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Stage-LatestManagerUpdate([string]$CurrentVersion) {
    $manifest = Invoke-RestMethod -Uri $manifestUrl -Method Get -TimeoutSec 15
    if (-not $manifest.version -or (Compare-CoAVersion ([string]$manifest.version) $CurrentVersion) -le 0) { return $false }
    $artifact = $manifest.artifacts | Where-Object {
        $_.component -eq 'addon-manager' -and $_.platform -eq 'win32' -and $_.arch -eq 'x64'
    } | Select-Object -First 1
    if (-not $artifact) { throw 'Artefact Windows du manager introuvable.' }
    $uri = [Uri]([string]$artifact.url)
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or -not $uri.AbsolutePath.StartsWith('/Cnbz13/coa-tools/releases/download/')) { throw 'URL de mise a jour non autorisee.' }
    if ([string]$artifact.sha256 -notmatch '^[a-f0-9]{64}$' -or -not $artifact.size) { throw 'Metadonnees de mise a jour invalides.' }
    $fileName = [IO.Path]::GetFileName($uri.AbsolutePath)
    if ($fileName -ne [string]$artifact.file -or $fileName -ne "CoAAddonManager-v$($artifact.version)-Windows.zip") { throw 'Nom de mise a jour invalide.' }
    New-Item -ItemType Directory -Path $updatesRoot -Force | Out-Null
    $archive = Join-Path $updatesRoot $fileName
    $partial = "$archive.part"
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $partial -UseBasicParsing -TimeoutSec 120
    if ((Get-Item -LiteralPath $partial).Length -ne [int64]$artifact.size) { throw 'Taille du telechargement invalide.' }
    $actualHash = Get-Sha256Hex $partial
    if ($actualHash -ne ([string]$artifact.sha256).ToLowerInvariant()) { throw 'Echec de verification SHA-256 du telechargement.' }
    Move-Item -LiteralPath $partial -Destination $archive -Force
    @{
        component = 'addon-manager'; version = [string]$artifact.version; file = $archive
        sha256 = $actualHash; size = [int64]$artifact.size; verifiedAt = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $updatesRoot 'ready.json') -Encoding UTF8
    Write-Host "Mise a jour $($artifact.version) telechargee et verifiee."
    return $true
}

$appRoot = Split-Path -Parent $PSScriptRoot
$stateRoot = Join-Path $env:LOCALAPPDATA 'CoAAddonManager'
$runtimeRoot = Join-Path $stateRoot 'runtime'
$logsRoot = Join-Path $stateRoot 'logs'
$dataRoot = Join-Path $stateRoot 'data'
$updatesRoot = Join-Path $appRoot '.updates'
$manifestUrl = if ($env:COA_UPDATE_MANIFEST) { $env:COA_UPDATE_MANIFEST } else { 'https://github.com/Cnbz13/coa-tools/releases/latest/download/manifest.json' }
$packageFile = Join-Path $appRoot 'package.json'
$package = Get-Content -LiteralPath $packageFile -Raw -Encoding UTF8 | ConvertFrom-Json
$nodeVersion = '24.14.0'
$runtimeDir = Join-Path $runtimeRoot "node-v$nodeVersion-win-x64"
$nodePath = Join-Path $runtimeDir 'node.exe'
$archiveName = "node-v$nodeVersion-win-x64.zip"
$nodeBaseUrl = "https://nodejs.org/dist/v$nodeVersion"
$serverProcess = $null
$stdoutPath = $null
$stderrPath = $null

try {
    try {
        $applied = Apply-PendingManagerUpdate ([string]$package.version)
        if ($applied) { $package = Get-Content -LiteralPath $packageFile -Raw -Encoding UTF8 | ConvertFrom-Json }
        $staged = Stage-LatestManagerUpdate ([string]$package.version)
        if ($staged -and (Apply-PendingManagerUpdate ([string]$package.version))) {
            $package = Get-Content -LiteralPath $packageFile -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }
    catch { Write-Warning "Mise a jour automatique indisponible : $($_.Exception.Message)" }

    $runtimeValid = $false
    if (Test-Path -LiteralPath $nodePath) {
        try { $runtimeValid = ((& $nodePath --version 2>$null) -eq "v$nodeVersion") } catch { }
    }
    if (-not $runtimeValid) {
        Write-Host 'Premier lancement : installation du moteur sécurisé CoA Tools...'
        $temporary = Join-Path ([IO.Path]::GetTempPath()) ("coa-runtime-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temporary -Force | Out-Null
        try {
            $archive = Join-Path $temporary $archiveName
            Invoke-WebRequest "$nodeBaseUrl/$archiveName" -OutFile $archive -UseBasicParsing
            $checksums = (Invoke-WebRequest "$nodeBaseUrl/SHASUMS256.txt" -UseBasicParsing).Content
            $line = ($checksums -split "`n" | Where-Object { $_ -match "\s$([regex]::Escape($archiveName))\s*$" } | Select-Object -First 1)
            if (-not $line) { throw 'Empreinte officielle Node.js introuvable.' }
            $expected = ($line.Trim() -split '\s+')[0].ToLowerInvariant()
            $actual = Get-Sha256Hex $archive
            if ($actual -ne $expected) { throw 'Échec de la vérification SHA-256 du moteur Node.js.' }
            Expand-Archive -LiteralPath $archive -DestinationPath $temporary -Force
            New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
            if (Test-Path -LiteralPath $runtimeDir) { Remove-Item -LiteralPath $runtimeDir -Recurse -Force }
            Move-Item -LiteralPath (Join-Path $temporary "node-v$nodeVersion-win-x64") -Destination $runtimeDir
        }
        finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    $preferredPort = 4173
    $existing = Get-CoAStatus $preferredPort
    if ($existing -and $existing.version -ne $package.version) {
        Stop-CoAManagerProcesses
        Start-Sleep -Milliseconds 300
        $existing = Get-CoAStatus $preferredPort
    }
    if ($existing -and $existing.version -eq $package.version) {
        $port = $preferredPort
        $url = "http://127.0.0.1:$port/"
        Write-Host "CoA Addon Manager $($package.version) est déjà actif : $url"
    }
    else {
        $port = if (Test-PortAvailable $preferredPort) { $preferredPort } else { Get-FreePort }
        $url = "http://127.0.0.1:$port/"
        New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $stdoutPath = Join-Path $logsRoot "server-$stamp.stdout.log"
        $stderrPath = Join-Path $logsRoot "server-$stamp.stderr.log"
        $env:PORT = [string]$port
        $env:COA_DATA_DIR = $dataRoot
        $env:COA_UPDATE_MANIFEST = $manifestUrl
        $serverProcess = Start-Process -FilePath $nodePath -ArgumentList 'src/server.js' -WorkingDirectory $appRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
        $ready = $false
        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $deadline) {
            $serverProcess.Refresh()
            if ($serverProcess.HasExited) {
                $serverProcess.WaitForExit()
                $exitCode = $serverProcess.ExitCode
                $details = "Node s'est arrêté avec le code $exitCode.`nSTDOUT:`n$(Read-Log $stdoutPath)`nSTDERR:`n$(Read-Log $stderrPath)"
                throw $details
            }
            $status = Get-CoAStatus $port
            if ($status -and $status.version -eq $package.version) { $ready = $true; break }
            Start-Sleep -Milliseconds 250
        }
        if (-not $ready) {
            $details = "Le serveur Node (PID $($serverProcess.Id)) n'est pas prêt après 60 secondes sur $url.`nSTDOUT:`n$(Read-Log $stdoutPath)`nSTDERR:`n$(Read-Log $stderrPath)"
            try { Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue } catch { }
            throw $details
        }
        Write-Host "CoA Addon Manager $($package.version) démarré : $url"
        Write-Host "Logs : $stdoutPath et $stderrPath"
    }

    $state = @{ version = $package.version; port = $port; url = $url; pid = if ($serverProcess) { $serverProcess.Id } else { $null }; stdout = $stdoutPath; stderr = $stderrPath; startedAt = (Get-Date).ToUniversalTime().ToString('o') }
    $state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'launch-state.json') -Encoding UTF8
    if ($env:COA_NO_BROWSER -ne '1') {
        try { Start-Process -FilePath $url | Out-Null }
        catch { Write-Warning "Le navigateur n'a pas pu être ouvert automatiquement. Ouvrez $url" }
    }
    exit 0
}
catch {
    [Console]::Error.WriteLine("ERREUR CoA Addon Manager :`n$($_.Exception.Message)")
    exit 1
}
