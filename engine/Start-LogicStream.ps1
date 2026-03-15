function Start-LogicStream {
    param(
        [string]$Script,
        [string[]]$Arguments,
        [int]$TimeoutMs = 30000,
        [string]$Tag
    )

    if (-not $Tag) { $Tag = [guid]::NewGuid().ToString('N') }

    $escapedArgs = ($Arguments | ForEach-Object { "`"$_`"" }) -join ' '
    $ext = [System.IO.Path]::GetExtension($Script).ToLower()

    $psi = [System.Diagnostics.ProcessStartInfo]::new()

    switch ($ext) {
        '.ps1' {
            $psi.FileName  = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Script`" $escapedArgs"
        }
        '.py' {
            if (Get-Command uv -ErrorAction SilentlyContinue) {
                $psi.FileName  = "uv"
                $psi.Arguments = "run `"$Script`" $escapedArgs"
            } else {
                $psi.FileName  = "python"
                $psi.Arguments = "-u `"$Script`" $escapedArgs"
            }
        }
        '.js' {
            if (Get-Command deno -ErrorAction SilentlyContinue) {
                $psi.FileName  = "deno"
                $psi.Arguments = "run --allow-net --allow-read `"$Script`" $escapedArgs"
            } else {
                $psi.FileName  = "node"
                $psi.Arguments = "`"$Script`" $escapedArgs"
            }
        }
        '.ts' {
            $psi.FileName  = "deno"
            $psi.Arguments = "run --allow-net --allow-read `"$Script`" $escapedArgs"
        }
        '.rb' {
            $psi.FileName  = "ruby"
            $psi.Arguments = "`"$Script`" $escapedArgs"
        }
        '.sh' {
            $distro = if ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { "Rocky9" }
            $wslPath = ($Script -replace '\\', '/')
            $wslPath = [regex]::Replace($wslPath, '^([A-Za-z]):', { "/mnt/$($args[0].Groups[1].Value.ToLower())" })
            $psi.FileName  = "wsl"
            $psi.Arguments = "-d $distro -- bash `"$wslPath`" $escapedArgs"
            $psi.RedirectStandardInput = $true
        }
        default {
            $psi.FileName  = $Script
            $psi.Arguments = $escapedArgs
        }
    }

    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $q = $script:uiQueue
    $procMap = $script:activeProcesses

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()

    $shell = [powershell]::Create()
    $shell.Runspace = $runspace

    [void]$shell.AddScript({
        param($processInfo, $queue, $timeout, $processMap, $streamTag)

        $proc = [System.Diagnostics.Process]::new()
        $proc.StartInfo = $processInfo
        $proc.Start() | Out-Null

        # Close stdin immediately to prevent WSL pipe hang (WSL#4424)
        if ($processInfo.RedirectStandardInput) {
            $proc.StandardInput.Close()
        }

        # Expose process handle for cancellation from UI thread
        $processMap.TryAdd($streamTag, $proc) | Out-Null

        # Drain stderr asynchronously to prevent pipe deadlock
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        # Stream stdout line-by-line to queue
        while ($null -ne ($line = $proc.StandardOutput.ReadLine())) {
            if ($line) { $queue.Enqueue($line) }
        }

        if (-not $proc.WaitForExit($timeout)) {
            $proc.Kill()
        }

        $removed = $null
        $processMap.TryRemove($streamTag, [ref]$removed) | Out-Null
        $proc.Dispose()
    }).AddArgument($psi).AddArgument($q).AddArgument($TimeoutMs).AddArgument($procMap).AddArgument($Tag)

    $asyncResult = $shell.BeginInvoke()

    $script:activeStreams.Add(@{
        Shell    = $shell
        Runspace = $runspace
        Handle   = $asyncResult
        Tag      = $Tag
    })

    return $Tag
}
