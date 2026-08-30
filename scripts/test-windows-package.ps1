param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
)

$ErrorActionPreference = 'Stop'
$zip = (Resolve-Path -LiteralPath $ZipPath).Path
$qaRoot = Join-Path ([IO.Path]::GetTempPath()) ("coa-windows-e2e-" + [guid]::NewGuid().ToString('N'))
$extractRoot = Join-Path $qaRoot 'Extraction With Spaces'
$profileRoot = Join-Path $qaRoot 'Local AppData With Spaces'
$oldLocalAppData = $env:LOCALAPPDATA
$oldNoBrowser = $env:COA_NO_BROWSER
$oldNonInteractive = $env:COA_NONINTERACTIVE
$oldAddonsDir = $env:WARMANE_ADDONS_DIR
$cmdProcess = $null
$nodePid = $null
$portJob = $null

try {
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $extractRoot -Force
    $appRoot = Join-Path $extractRoot 'CoAAddonManager'
    $launcher = Join-Path $appRoot 'CoAAddonManager.cmd'
    if (-not (Test-Path -LiteralPath $launcher)) { throw "Launcher missing: $launcher" }
    $currentPackageFile = Join-Path $appRoot 'package.json'
    $currentPackage = Get-Content -LiteralPath $currentPackageFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $currentVersion = [Version]$currentPackage.version
    $futureVersion = "$($currentVersion.Major).$($currentVersion.Minor).$($currentVersion.Build + 1)"
    $futureParent = Join-Path $qaRoot 'Future manager package'
    $futureRoot = Join-Path $futureParent 'CoAAddonManager'
    New-Item -ItemType Directory -Path $futureParent -Force | Out-Null
    Copy-Item -LiteralPath $appRoot -Destination $futureRoot -Recurse -Force
    $futurePackageFile = Join-Path $futureRoot 'package.json'
    $futurePackage = Get-Content -LiteralPath $futurePackageFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $futurePackage.version = $futureVersion
    [IO.File]::WriteAllText($futurePackageFile, (($futurePackage | ConvertTo-Json -Depth 20) + "`n"), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $futureRoot 'self-update-applied.txt'), $futureVersion, [Text.UTF8Encoding]::new($false))
    $updatesRoot = Join-Path $appRoot '.updates'
    New-Item -ItemType Directory -Path $updatesRoot -Force | Out-Null
    $futureArchive = Join-Path $updatesRoot "CoAAddonManager-v$futureVersion-Windows.zip"
    Compress-Archive -LiteralPath $futureRoot -DestinationPath $futureArchive -CompressionLevel Optimal
    $futureHash = (Get-FileHash -LiteralPath $futureArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    $ready = @{
        component = 'addon-manager'; version = $futureVersion; file = $futureArchive
        sha256 = $futureHash; size = (Get-Item -LiteralPath $futureArchive).Length; verifiedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    [IO.File]::WriteAllText((Join-Path $updatesRoot 'ready.json'), (($ready | ConvertTo-Json) + "`n"), [Text.UTF8Encoding]::new($false))
    if (Get-Command node -ErrorAction SilentlyContinue) { Write-Host 'A global Node exists but the launcher must not use it.' }
    $env:LOCALAPPDATA = $profileRoot
    $env:COA_NO_BROWSER = '1'
    $env:COA_NONINTERACTIVE = '1'
    $fixtureAddons = Join-Path $qaRoot 'Warmane Game With Spaces\Interface\AddOns'
    $fixture = Join-Path $fixtureAddons 'E2EFixture'
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixture 'E2EFixture.toc'), "## Title: E2E Fixture`n## Version: 1.0.0`n## Notes: Windows package scan`n", [Text.UTF8Encoding]::new($false))
    $env:WARMANE_ADDONS_DIR = $fixtureAddons
    $portJob = Start-Job -ScriptBlock {
        $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 4173)
        try { $listener.Start(); while ($true) { Start-Sleep -Seconds 1 } }
        finally { $listener.Stop() }
    }
    $portDeadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $client = New-Object Net.Sockets.TcpClient
        try { $client.Connect('127.0.0.1', 4173); $portOccupied = $true }
        catch { $portOccupied = $false }
        finally { $client.Dispose() }
    } while (-not $portOccupied -and (Get-Date) -lt $portDeadline)
    if (-not $portOccupied) { throw 'Could not reserve port 4173 for the conflict test.' }
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $stdout = Join-Path $qaRoot 'launcher.stdout.log'
    $stderr = Join-Path $qaRoot 'launcher.stderr.log'
    $startInfo.Arguments = '/d /s /c ""CoAAddonManager.cmd" 1>"' + $stdout + '" 2>"' + $stderr + '""'
    $startInfo.WorkingDirectory = $appRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $cmdProcess = New-Object Diagnostics.Process
    $cmdProcess.StartInfo = $startInfo
    if (-not $cmdProcess.Start()) { throw 'Could not start the packaged Windows launcher.' }
    $stateFile = Join-Path $profileRoot 'CoAAddonManager\launch-state.json'
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $stateFile)) {
        $cmdProcess.Refresh()
        if ($cmdProcess.HasExited -and $cmdProcess.ExitCode -ne 0) {
            throw "Launcher exited with $($cmdProcess.ExitCode).`nSTDOUT:`n$([IO.File]::ReadAllText($stdout))`nSTDERR:`n$([IO.File]::ReadAllText($stderr))"
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path -LiteralPath $stateFile)) {
        $capturedOut = if (Test-Path -LiteralPath $stdout) { [IO.File]::ReadAllText($stdout) } else { '(aucune sortie)' }
        $capturedErr = if (Test-Path -LiteralPath $stderr) { [IO.File]::ReadAllText($stderr) } else { '(aucune erreur)' }
        throw "Launcher state file was not created in 120 seconds.`nSTDOUT:`n$capturedOut`nSTDERR:`n$capturedErr"
    }
    $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $nodePid = $state.pid
    $status = Invoke-RestMethod "$($state.url)api/status" -TimeoutSec 5
    $inventory = Invoke-RestMethod "$($state.url)api/addons" -TimeoutSec 20
    $updatedPackage = Get-Content -LiteralPath $currentPackageFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($updatedPackage.version -ne $futureVersion) { throw "Pending manager update was not applied: $($updatedPackage.version) instead of $futureVersion." }
    if (-not (Test-Path -LiteralPath (Join-Path $appRoot 'self-update-applied.txt'))) { throw 'Pending manager update marker is missing.' }
    if (Test-Path -LiteralPath (Join-Path $updatesRoot 'ready.json')) { throw 'Pending manager ready marker was not cleared.' }
    if ($state.port -eq 4173) { throw 'Launcher did not select a free port when 4173 was occupied.' }
    if ($status.name -ne 'CoA Tools' -or $status.version -ne $state.version) { throw 'Unexpected HTTP status payload.' }
    if (-not $inventory.exists -or $inventory.localCount -lt 1) { throw 'Packaged Addon Manager did not scan an actual AddOns folder.' }
    if ($inventory.managed.Count -lt 2) { throw 'Packaged Addon Manager did not load the managed CoA catalog.' }
    $nodeProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$nodePid"
    if (-not $nodeProcess) { throw 'Packaged Node process is not running.' }
    if (-not $nodeProcess.ExecutablePath.StartsWith($profileRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Launcher used an unexpected Node: $($nodeProcess.ExecutablePath)" }
    $runtimeNode = Join-Path $profileRoot 'CoAAddonManager\runtime\node-v24.14.0-win-x64\node.exe'
    if (-not (Test-Path -LiteralPath $runtimeNode)) { throw 'Bootstrapped Node runtime is missing.' }
    Write-Host "Windows package E2E succeeded: $($state.url), PID $nodePid, Node $($nodeProcess.ExecutablePath)"
}
finally {
    if ($nodePid) { Stop-Process -Id $nodePid -Force -ErrorAction SilentlyContinue }
    if ($cmdProcess -and -not $cmdProcess.HasExited) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $cmdProcess.Id /T /F 2>$null | Out-Null
    }
    if ($portJob) { Stop-Job $portJob -ErrorAction SilentlyContinue; Remove-Job $portJob -Force -ErrorAction SilentlyContinue }
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:COA_NO_BROWSER = $oldNoBrowser
    $env:COA_NONINTERACTIVE = $oldNonInteractive
    $env:WARMANE_ADDONS_DIR = $oldAddonsDir
    if (Test-Path -LiteralPath $qaRoot) { Remove-Item -LiteralPath $qaRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
