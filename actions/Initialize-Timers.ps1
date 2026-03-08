# Capture script directory at dot-source time
$script:_timersDir = $PSScriptRoot

function Initialize-Timers {
    param($window)

    $projectRoot   = Split-Path $script:_timersDir -Parent
    $actionsDir    = $script:_timersDir
    $timersXmlPath = Join-Path $projectRoot "timers.xml"

    if (-not (Test-Path $timersXmlPath)) { return }

    [xml]$timersXml = Get-Content $timersXmlPath -Raw
    $timers = [System.Collections.Generic.List[object]]::new()

    foreach ($node in $timersXml.Timers.Timer) {
        $tickFn   = $node.Tick
        $interval = [int]$node.Interval
        $autoStart = $node.AutoStart -ne 'false'

        # Scaffold stub if missing
        $actionFile = Join-Path $actionsDir "$tickFn.ps1"
        if (-not (Test-Path $actionFile)) {
            @(
                "function $tickFn {"
                "    param(`$sender, `$e)"
                "    # TODO: implement $tickFn"
                "}"
            ) | Set-Content $actionFile -Encoding UTF8
            Write-Host "Scaffolded: $actionFile"
        }

        # Dot-source if function not yet loaded
        if (-not (Get-Command $tickFn -ErrorAction SilentlyContinue)) {
            . $actionFile
        }

        $timer = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [TimeSpan]::FromMilliseconds($interval)

        $fn = Get-Item "function:$tickFn"
        $timer.Add_Tick($fn.ScriptBlock)

        Set-Variable -Name $node.Name -Value $timer -Scope Global

        if ($autoStart) { $timer.Start() }

        $timers.Add($timer)
    }

    return $timers
}
