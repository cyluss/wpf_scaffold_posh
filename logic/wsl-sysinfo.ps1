param([string[]]$ScriptArgs)

$distro = if ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { "Rocky9" }
$shPath = Join-Path $PSScriptRoot "wsl-sysinfo.sh"
$wslPath = ($shPath -replace '\\', '/')
$wslPath = [regex]::Replace($wslPath, '^([A-Za-z]):', { "/mnt/$($args[0].Groups[1].Value.ToLower())" })

$argStr = ($ScriptArgs | ForEach-Object { "`"$_`"" }) -join ' '

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = "wsl"
$psi.Arguments = "-d $distro -- bash `"$wslPath`" $argStr"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.RedirectStandardInput = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $psi
$proc.Start() | Out-Null

# Close stdin immediately to prevent WSL pipe hang (WSL#4424)
$proc.StandardInput.Close()

# Read stderr async to avoid deadlock
$stderrTask = $proc.StandardError.ReadToEndAsync()

while ($null -ne ($line = $proc.StandardOutput.ReadLine())) {
    if ($line) { $line }
}

$proc.WaitForExit(30000) | Out-Null
$proc.Dispose()
