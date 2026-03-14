function Stop-LogicStream {
    param(
        [string]$Tag
    )

    if ($Tag) {
        # Cancel a specific stream by tag
        $proc = $null
        if ($script:activeProcesses.TryGetValue($Tag, [ref]$proc)) {
            if (-not $proc.HasExited) { $proc.Kill() }
        }
    } else {
        # Cancel all running streams
        foreach ($key in @($script:activeProcesses.Keys)) {
            $proc = $null
            if ($script:activeProcesses.TryGetValue($key, [ref]$proc)) {
                if (-not $proc.HasExited) { $proc.Kill() }
            }
        }
    }
}
