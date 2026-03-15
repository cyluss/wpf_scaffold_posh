#Requires -Version 5.1
# Integration test: WSL2 wsl-sysinfo.sh

param(
    [string]$Distro = "Rocky9"
)

$scriptPath = Join-Path $PSScriptRoot "..\logic\wsl-sysinfo.sh"
$wslPath = "/mnt/c" + ($scriptPath.Substring(2) -replace '\\', '/')
$failed = 0

function Pass($msg) { Write-Host "  PASS  $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  FAIL  $msg" -ForegroundColor Red; $script:failed++ }

Write-Host "=== WSL2 Integration Test ===" -ForegroundColor Cyan
Write-Host ""

# 1. Distro exists
Write-Host "[1] WSL distro exists"
# wsl -l outputs UTF-16LE with null bytes — normalize
$raw = wsl -l -q 2>&1 | Out-String
$list = $raw -replace "`0", ''
if ($list -match $Distro) { Pass $Distro } else { Fail "distro '$Distro' not found"; exit 1 }

# 2. Distro state
Write-Host "[2] WSL distro state"
$rawState = wsl -l -v 2>&1 | Out-String
$state = $rawState -replace "`0", ''
if ($state -match "$Distro\s+Running") {
    Pass "Running"
} elseif ($state -match "$Distro\s+Stopped") {
    Write-Host "  WARN  Stopped (cold boot expected)" -ForegroundColor Yellow
} else {
    Fail "unknown state"
}

# 3. Execute script
Write-Host "[3] Execute wsl-sysinfo.sh"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$output = wsl -d $Distro -- bash $wslPath 2>&1
$exitCode = $LASTEXITCODE
$sw.Stop()
$elapsed = $sw.ElapsedMilliseconds

if ($exitCode -eq 0) {
    Pass "${elapsed}ms"
} else {
    Fail "exit code $exitCode (${elapsed}ms)"
    $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    exit 1
}

# 4. Validate UI commands
Write-Host "[4] UI commands present"
$lines = $output | Where-Object { $_ -ne '' }

$cmds = @(
    @{ Pattern = '^setb64 txtResponse\.Text '; Label = 'setb64 txtResponse.Text' },
    @{ Pattern = '^enable btnSend$';           Label = 'enable btnSend' },
    @{ Pattern = '^enable btnWsl$';            Label = 'enable btnWsl' },
    @{ Pattern = '^disable btnCancel$';        Label = 'disable btnCancel' },
    @{ Pattern = '^set lblStatus\.Foreground #4CAF50'; Label = 'success color' }
)

foreach ($cmd in $cmds) {
    if ($lines | Where-Object { $_ -match $cmd.Pattern }) {
        Pass $cmd.Label
    } else {
        Fail "missing: $($cmd.Label)"
    }
}

# 5. Decode base64 payload
Write-Host "[5] Payload content"
$b64line = $lines | Where-Object { $_ -match '^setb64 txtResponse\.Text ' } | Select-Object -First 1
$b64 = ($b64line -split ' ', 3)[2]
$decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
$items = $decoded -split "`n" | Where-Object { $_ -ne '' }

$required = @('OS:', 'Kernel:', 'CPU:', 'Memory:', 'Disk')
foreach ($key in $required) {
    if ($items | Where-Object { $_ -match "^$key" }) {
        Pass $key
    } else {
        Fail "missing: $key"
    }
}

# 6. Summary
Write-Host ""
Write-Host "--- Payload (${items.Count} items) ---" -ForegroundColor DarkGray
$decoded | Write-Host
Write-Host ""

if ($failed -eq 0) {
    Write-Host "=== All tests passed (${elapsed}ms) ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== $failed test(s) failed ===" -ForegroundColor Red
    exit 1
}
