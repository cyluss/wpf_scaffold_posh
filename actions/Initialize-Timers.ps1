function Initialize-Timers {
    param($window, $projectRoot, $actionsDir)

    $timersXmlPath = Join-Path $projectRoot "timers.xml"

    if (-not (Test-Path $timersXmlPath)) { return }

    [xml]$timersXml = Get-Content $timersXmlPath -Raw
    $timers = [System.Collections.Generic.List[object]]::new()

    foreach ($node in $timersXml.Timers.Timer) {
        $tickFn   = $node.Tick
        $interval = [int]$node.Interval
        $autoStart = $node.AutoStart -ne 'false'

        Ensure-ActionLoaded $tickFn $actionsDir

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
