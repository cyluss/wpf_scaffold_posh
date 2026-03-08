function Invoke-HelloClick {
    param($sender, $e)
    $name = $txtName.Text
    Start-LogicStream "$logicDir\hello.py" @($name)
}
