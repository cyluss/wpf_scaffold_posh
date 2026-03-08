function Update-Clock {
    param($sender, $e)
    $commands = & powershell -NoProfile -File "$logicDir\clock.ps1"
    Invoke-UICommands $commands
}
