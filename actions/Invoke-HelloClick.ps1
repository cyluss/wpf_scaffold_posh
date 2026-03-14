function Invoke-HelloClick {
    param($sender, $e)
    $btnHello.IsEnabled = $false
    $btnCancel.IsEnabled = $true
    $name = $txtName.Text
    $script:helloStreamTag = Start-LogicStream "$logicDir\hello.py" @($name)
}
