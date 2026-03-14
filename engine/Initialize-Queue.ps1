function Initialize-Queue {
    $script:uiQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $script:activeStreams = [System.Collections.Generic.List[hashtable]]::new()
    $script:activeProcesses = [System.Collections.Concurrent.ConcurrentDictionary[string,System.Diagnostics.Process]]::new()

    $q       = $script:uiQueue
    $streams = $script:activeStreams
    $uiCmd   = (Get-Item "function:Invoke-UICommands").ScriptBlock

    $drainTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $drainTimer.Interval = [TimeSpan]::FromMilliseconds(16)

    $drainTimer.Add_Tick({
        # Drain queued UI commands
        $line = $null
        while ($q.TryDequeue([ref]$line)) {
            & $uiCmd @($line)
        }

        # Cleanup completed background streams
        for ($i = $streams.Count - 1; $i -ge 0; $i--) {
            if ($streams[$i].Handle.IsCompleted) {
                $streams[$i].Shell.EndInvoke($streams[$i].Handle)
                $streams[$i].Shell.Dispose()
                $streams[$i].Runspace.Dispose()
                $streams.RemoveAt($i)
            }
        }
    }.GetNewClosure())

    $drainTimer.Start()
    return $drainTimer
}
