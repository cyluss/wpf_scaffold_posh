function Invoke-NumpyClick {
    param($sender, $e)
    $btnNumpy.IsEnabled = $false
    $btnSend.IsEnabled = $false
    $btnCancel.IsEnabled = $true
    $txtResponse.Text = ""
    $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#888')
    $lblStatus.Text = "Running NumPy demo..."
    $script:numpyStreamTag = Start-LogicStream "$logicDir\wsl-numpy-demo.sh"
}
