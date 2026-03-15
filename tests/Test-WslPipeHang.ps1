# Test-WslPipeHang.ps1 — Compare 3 approaches to wsl.exe stdout pipe
# Usage: powershell -NoProfile -File tests/Test-WslPipeHang.ps1

$distro = if ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { "Rocky9" }
$TimeoutMs = 15000

function Test-Approach {
    param([string]$Name, [scriptblock]$Setup)
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true

    & $Setup $psi

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc.Start() | Out-Null

    # Close stdin if redirected (approach B/C fix)
    if ($psi.RedirectStandardInput) {
        $proc.StandardInput.Close()
    }

    # Use ReadToEndAsync for stdout to allow timeout
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    $exited = $proc.WaitForExit($TimeoutMs)
    $sw.Stop()

    if (-not $exited) {
        try { $proc.Kill() } catch {}
        Write-Host "  TIMEOUT after ${TimeoutMs}ms" -ForegroundColor Red
        $result = "TIMEOUT"
    } else {
        # Give async reads a moment to complete
        [void]$stdoutTask.Wait(2000)
        $stdout = $stdoutTask.Result
        $lines = ($stdout -split "`n") | Where-Object { $_.Trim() }

        if ($lines.Count -gt 0) {
            Write-Host "  PASS — $($lines.Count) lines in $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
            $lines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            $result = "PASS"
        } else {
            [void]$stderrTask.Wait(1000)
            $stderr = if ($stderrTask.IsCompleted) { $stderrTask.Result } else { "(pending)" }
            Write-Host "  FAIL — 0 lines, stderr: $stderr" -ForegroundColor Yellow
            $result = "FAIL"
        }
    }

    try { $proc.Dispose() } catch {}
    return $result
}

Write-Host "WSL Pipe Hang Test — distro: $distro, timeout: ${TimeoutMs}ms"

# --- Approach A: current code (cmd /c wsl, no stdin close) ---
$resultA = Test-Approach "A: cmd /c wsl (current — expect TIMEOUT)" {
    param($psi)
    $psi.FileName  = "cmd"
    $psi.Arguments = "/c wsl -d $distro -- echo hello-from-wsl"
}

# --- Approach B: direct wsl + close stdin ---
$resultB = Test-Approach "B: wsl + close stdin (expect PASS)" {
    param($psi)
    $psi.FileName  = "wsl"
    $psi.Arguments = "-d $distro -- echo hello-from-wsl"
    $psi.RedirectStandardInput = $true
}

# --- Approach C: powershell wrapper calling wsl ---
$wrapperScript = Join-Path (Join-Path $PSScriptRoot "..") "logic" | Join-Path -ChildPath "wsl-sysinfo.ps1"
$resultC = if (Test-Path $wrapperScript) {
    Test-Approach "C: .ps1 wrapper (expect PASS)" {
        param($psi)
        $psi.FileName  = "powershell"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperScript`""
        $psi.RedirectStandardInput = $true
    }
} else {
    Write-Host "`n=== C: .ps1 wrapper — SKIPPED (not found: $wrapperScript) ===" -ForegroundColor Yellow
    "SKIP"
}

# --- Summary ---
Write-Host "`n=== Summary ===" -ForegroundColor White
Write-Host "  A (cmd /c wsl):    $resultA"
Write-Host "  B (wsl+close):     $resultB"
Write-Host "  C (.ps1 wrapper):  $resultC"

if ($resultB -eq "PASS") {
    Write-Host "`nRecommendation: Use approach B (RedirectStandardInput + Close)" -ForegroundColor Green
} elseif ($resultC -eq "PASS") {
    Write-Host "`nRecommendation: Use approach C (.ps1 wrapper)" -ForegroundColor Green
} else {
    Write-Host "`nNo approach passed — check WSL distro '$distro'" -ForegroundColor Red
}
