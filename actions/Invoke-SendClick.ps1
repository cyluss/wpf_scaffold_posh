function Invoke-SendClick {
    param($sender, $e)
    $btnSend.IsEnabled = $false
    $btnCancel.IsEnabled = $true
    $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#888')
    $lblStatus.Text = "Sending..."
    $txtResponse.Text = ""
    $method   = $cboMethod.SelectedItem.Content
    $url      = $txtUrl.Text
    $tlsVerify = if ($chkTls.IsChecked) { "true" } else { "false" }
    $bodyType  = $cboBodyType.SelectedItem.Content
    $headersB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($txtHeaders.Text))
    $bodyB64    = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($txtBody.Text))
    $script:sendStreamTag = Start-LogicStream "$logicDir\http-request.py" @(
        $method, $url, $tlsVerify, $bodyType, $headersB64, $bodyB64
    )
}
