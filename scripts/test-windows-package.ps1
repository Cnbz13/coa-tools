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
$oldAddonsDir = $env:COA_ADDONS_DIR
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
    if (Get-Command node -ErrorAction SilentlyContinue) { Write-Host 'A global Node exists but the launcher must not use it.' }
    $env:LOCALAPPDATA = $profileRoot
    $env:COA_NO_BROWSER = '1'
    $env:COA_NONINTERACTIVE = '1'
    $fixtureAddons = Join-Path $qaRoot 'Ascension Game With Spaces\Interface\AddOns'
    $fixture = Join-Path $fixtureAddons 'E2EFixture'
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixture 'E2EFixture.toc'), "## Title: E2E Fixture`n## Version: 1.0.0`n## Notes: Windows package scan`n", [Text.UTF8Encoding]::new($false))
    $env:COA_ADDONS_DIR = $fixtureAddons
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
    $stdout = Join-Path $qaRoot 'launcher.stdout.log'
    $stderr = Join-Path $qaRoot 'launcher.stderr.log'
    $cmdProcess = Start-Process -FilePath $env:ComSpec -ArgumentList '/d', '/c', 'CoAAddonManager.cmd' -WorkingDirectory $appRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $stateFile = Join-Path $profileRoot 'CoAAddonManager\launch-state.json'
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $stateFile)) {
        $cmdProcess.Refresh()
        if ($cmdProcess.HasExited -and $cmdProcess.ExitCode -ne 0) {
            throw "Launcher exited with $($cmdProcess.ExitCode).`nSTDOUT:`n$([IO.File]::ReadAllText($stdout))`nSTDERR:`n$([IO.File]::ReadAllText($stderr))"
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path -LiteralPath $stateFile)) { throw 'Launcher state file was not created in 120 seconds.' }
    $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $nodePid = $state.pid
    $status = Invoke-RestMethod "$($state.url)api/status" -TimeoutSec 5
    $inventory = Invoke-RestMethod "$($state.url)api/addons" -TimeoutSec 20
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
    if ($cmdProcess -and -not $cmdProcess.HasExited) { Stop-Process -Id $cmdProcess.Id -Force -ErrorAction SilentlyContinue }
    if ($portJob) { Stop-Job $portJob -ErrorAction SilentlyContinue; Remove-Job $portJob -Force -ErrorAction SilentlyContinue }
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:COA_NO_BROWSER = $oldNoBrowser
    $env:COA_NONINTERACTIVE = $oldNonInteractive
    $env:COA_ADDONS_DIR = $oldAddonsDir
    if (Test-Path -LiteralPath $qaRoot) { Remove-Item -LiteralPath $qaRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
