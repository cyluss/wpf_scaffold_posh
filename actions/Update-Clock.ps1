function Update-Clock {
    param($sender, $e)
    $lblClock.Text = (Get-Date).ToString("HH:mm:ss")
}
