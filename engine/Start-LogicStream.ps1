function Start-LogicStream {
    param(
        [string]$Script,
        [string[]]$Arguments
    )

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
        default {
            $psi.FileName  = $Script
            $psi.Arguments = $escapedArgs
        }
    }

    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true

    $dispatcher = $window.Dispatcher

    # Stream stdout line-by-line → dispatch each as a UI command
    Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action {
        $line = $Event.SourceEventArgs.Data
        if ($line) {
            $dispatcher.Invoke([Action]{
                Invoke-UICommands @($line)
            }, [System.Windows.Threading.DispatcherPriority]::Normal)
        }
    } | Out-Null

    # Stream stderr → write to host for debugging
    Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
        $errLine = $Event.SourceEventArgs.Data
        if ($errLine) {
            $dispatcher.Invoke([Action]{
                Write-Host "Logic error: $errLine" -ForegroundColor Red
            }, [System.Windows.Threading.DispatcherPriority]::Normal)
        }
    } | Out-Null

    $proc.Start() | Out-Null
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()

    return $proc
}
