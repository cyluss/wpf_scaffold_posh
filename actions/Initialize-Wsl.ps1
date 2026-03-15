function Initialize-Wsl {
    param($sender, $e)
    Start-LogicStream "$logicDir\wsl-init.sh"
}
