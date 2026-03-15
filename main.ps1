#Requires -Version 5.1
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$projectRoot = $PSScriptRoot
$engineDir   = Join-Path $projectRoot "engine"
$logicDir    = Join-Path $projectRoot "logic"
$xamlPath    = Join-Path $projectRoot "main.xaml"
$actionsDir  = Join-Path $projectRoot "actions"

# --- Engine: dot-source utility functions ---
Get-ChildItem $engineDir -Filter "*.ps1" | ForEach-Object { . $_.FullName }

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
    $sanitized = $sanitized -replace "(?<=\s)$evt=""[^""]*""", ''
}
[xml]$xaml = $sanitized

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# --- Runtime: find controls + entity registry ---
foreach ($c in $controls) {
    Set-Variable -Name $c -Value $window.FindName($c)
}
Register-XamlControls $controls $window

# --- Runtime: wire handlers ---
foreach ($h in $handlers) {
    if ($h.Control) {
        $control = Get-Variable -Name $h.Control -ValueOnly
    } else {
        $control = $window
    }
    $fn = Get-Item "function:$($h.Handler)"
    $control."Add_$($h.Event)"($fn.ScriptBlock)
}

# --- Queue: background stream processing ---
$drainTimer = Initialize-Queue

# --- Tray: setup ---
$tray = Initialize-Tray $window $projectRoot $actionsDir

# --- Timers: setup ---
$timers = Initialize-Timers $window $projectRoot $actionsDir

$window.ShowDialog()

# --- Cleanup ---
$drainTimer.Stop()
foreach ($t in $timers) { $t.Stop() }
Stop-LogicStream
foreach ($stream in $script:activeStreams) {
    if (-not $stream.Handle.IsCompleted) { $stream.Shell.Stop() }
    $stream.Shell.Dispose()
    $stream.Runspace.Dispose()
}
$script:activeProcesses.Clear()
$tray.Dispose()
