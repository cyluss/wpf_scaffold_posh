function Stop-App {
    param($sender, $e)
    $tray.Visible = $false
    $window.Remove_Closing($null)
    $window.Close()
    [System.Windows.Application]::Current.Shutdown()
}
