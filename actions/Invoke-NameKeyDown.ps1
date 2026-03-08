function Invoke-NameKeyDown {
    param($sender, $e)
    if ($e.Key -eq 'Return') {
        $e.Handled = $true
        $btnHello.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    }
}
