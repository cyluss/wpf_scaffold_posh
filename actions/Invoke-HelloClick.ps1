function Invoke-HelloClick {
    param($sender, $e)
    $btnHello.IsEnabled = $false
    $name = $txtName.Text
    Start-LogicStream "$logicDir\hello.py" @($name)
}
