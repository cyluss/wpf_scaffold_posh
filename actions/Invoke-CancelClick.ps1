function Invoke-CancelClick {
    param($sender, $e)
    if ($script:sendStreamTag) {
        Stop-LogicStream -Tag $script:sendStreamTag
        $script:sendStreamTag = $null
        $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#888')
        $lblStatus.Text = "Cancelled"
        $btnSend.IsEnabled = $true
        $btnCancel.IsEnabled = $false
    }
}
