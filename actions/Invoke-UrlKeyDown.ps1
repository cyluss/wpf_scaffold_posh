function Invoke-UrlKeyDown {
    param($sender, $e)
    if ($e.Key -eq 'Return') {
        Invoke-SendClick $sender $e
        $e.Handled = $true
    }
}
