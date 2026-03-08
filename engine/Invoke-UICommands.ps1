function Invoke-UICommands {
    param([string[]]$Commands)
    foreach ($cmd in $Commands) {
        if (-not $cmd -or $cmd.StartsWith('#')) { continue }

        $parts = $cmd -split ' ', 3
        $verb  = $parts[0]
        $target = $parts[1]

        switch ($verb) {
            'set' {
                $dot   = $target.IndexOf('.')
                $ctrl  = $target.Substring(0, $dot)
                $prop  = $target.Substring($dot + 1)
                $value = $parts[2]
                (Get-Variable $ctrl -ValueOnly).$prop = $value
            }
            'show'    { (Get-Variable $target -ValueOnly).Visibility = 'Visible' }
            'hide'    { (Get-Variable $target -ValueOnly).Visibility = 'Collapsed' }
            'enable'  { (Get-Variable $target -ValueOnly).IsEnabled = $true }
            'disable' { (Get-Variable $target -ValueOnly).IsEnabled = $false }
        }
    }
}
