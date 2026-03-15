function Invoke-WslClick {
    param($sender, $e)
    $btnWsl.IsEnabled = $false
    $btnSend.IsEnabled = $false
    $btnCancel.IsEnabled = $true
    $txtResponse.Text = ""
    $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#888')
    $lblStatus.Text = "WSL2 starting..."
    $script:wslStreamTag = Start-LogicStream "$logicDir\wsl-sysinfo.sh"
}
