function Show-Window {
    param($sender, $e)
    $window.Show()
    $window.WindowState = 'Normal'
    $window.Activate()
}
