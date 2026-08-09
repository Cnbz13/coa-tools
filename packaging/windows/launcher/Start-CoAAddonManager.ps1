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

$appRoot = Split-Path -Parent $PSScriptRoot
$package = Get-Content -LiteralPath (Join-Path $appRoot 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$stateRoot = Join-Path $env:LOCALAPPDATA 'CoAAddonManager'
$runtimeRoot = Join-Path $stateRoot 'runtime'
$logsRoot = Join-Path $stateRoot 'logs'
$dataRoot = Join-Path $stateRoot 'data'
$nodeVersion = '24.14.0'
$runtimeDir = Join-Path $runtimeRoot "node-v$nodeVersion-win-x64"
$nodePath = Join-Path $runtimeDir 'node.exe'
$archiveName = "node-v$nodeVersion-win-x64.zip"
$nodeBaseUrl = "https://nodejs.org/dist/v$nodeVersion"
$serverProcess = $null
$stdoutPath = $null
$stderrPath = $null

try {
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
            $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
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
        $env:COA_ADDONS_DIR = Join-Path $stateRoot 'addons'
        $env:COA_UPDATE_MANIFEST = 'https://github.com/Cnbz13/coa-tools/releases/latest/download/manifest.json'
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
