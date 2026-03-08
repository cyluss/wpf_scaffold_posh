function Start-App {
    param([string]$ProjectRoot)

    $xamlPath   = Join-Path $ProjectRoot "main.xaml"
    $actionsDir = Join-Path $ProjectRoot "actions"

    # Known event attributes
    $eventAttribs = @(
        'Click', 'Loaded', 'Closed', 'SelectionChanged', 'TextChanged',
        'MouseDown', 'MouseUp', 'KeyDown', 'KeyUp', 'GotFocus', 'LostFocus',
        'Checked', 'Unchecked', 'ValueChanged', 'DropDownOpened', 'DropDownClosed'
    )

    # --- Scaffold: parse XAML ---
    [xml]$xamlRaw = Get-Content $xamlPath -Raw

    $controls = [System.Collections.Generic.List[string]]::new()
    $handlers = [System.Collections.Generic.List[hashtable]]::new()

    $xamlRaw.SelectNodes("//*") | ForEach-Object {
        $node = $_
        $name = $node.GetAttribute("Name", "http://schemas.microsoft.com/winfx/2006/xaml")
        if (-not $name) { $name = $node.GetAttribute("Name") }
        if ($name) { $controls.Add($name) }

        foreach ($evt in $eventAttribs) {
            $handlerName = $node.GetAttribute($evt)
            if ($handlerName) {
                $handlers.Add(@{ Control = $name; Event = $evt; Handler = $handlerName })
            }
        }
    }

    # --- Scaffold: generate one file per handler ---
    if (-not (Test-Path $actionsDir)) {
        New-Item -ItemType Directory -Path $actionsDir | Out-Null
    }

    foreach ($h in $handlers) {
        Ensure-ActionLoaded $h.Handler $actionsDir
    }

    # --- Runtime: dot-source all action files ---
    Get-ChildItem $actionsDir -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # --- Runtime: load XAML ---
    $sanitized = (Get-Content $xamlPath -Raw) -replace 'x:Class="[^"]*"', ''
    foreach ($evt in $eventAttribs) {
        $sanitized = $sanitized -replace "$evt=""[^""]*""", ''
    }
    [xml]$xaml = $sanitized

    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $script:window = [System.Windows.Markup.XamlReader]::Load($reader)
    Set-Variable -Name window -Value $script:window -Scope Global

    # --- Runtime: find controls ---
    foreach ($c in $controls) {
        Set-Variable -Name $c -Value $script:window.FindName($c) -Scope Global
    }

    # --- Runtime: wire handlers ---
    foreach ($h in $handlers) {
        $control = Get-Variable -Name $h.Control -ValueOnly
        $fn = Get-Item "function:$($h.Handler)"
        $control."Add_$($h.Event)"($fn.ScriptBlock)
    }

    # --- Tray: setup ---
    $tray = Initialize-Tray $script:window $ProjectRoot $actionsDir

    # --- Timers: setup ---
    $timers = Initialize-Timers $script:window $ProjectRoot $actionsDir

    $script:window.ShowDialog()

    # --- Cleanup ---
    foreach ($t in $timers) { $t.Stop() }
    $tray.Dispose()
}
