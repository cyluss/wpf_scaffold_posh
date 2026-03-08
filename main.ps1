#Requires -Version 5.1
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$xamlPath    = Join-Path $PSScriptRoot "main.xaml"
$actionsDir  = Join-Path $PSScriptRoot "actions"

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
    $actionFile = Join-Path $actionsDir "$($h.Handler).ps1"
    if (-not (Test-Path $actionFile)) {
        @(
            "function $($h.Handler) {"
            "    param(`$sender, `$e)"
            "    # TODO: implement $($h.Handler)"
            "}"
        ) | Set-Content $actionFile -Encoding UTF8
        Write-Host "Scaffolded: $actionFile"
    }
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
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# --- Runtime: find controls ---
foreach ($c in $controls) {
    Set-Variable -Name $c -Value $window.FindName($c)
}

# --- Runtime: wire handlers ---
foreach ($h in $handlers) {
    $control = Get-Variable -Name $h.Control -ValueOnly
    $fn = Get-Item "function:$($h.Handler)"
    $control."Add_$($h.Event)"($fn.ScriptBlock)
}

# --- Tray: setup ---
$tray = Initialize-Tray $window

# --- Timers: setup ---
$timers = Initialize-Timers $window

$window.ShowDialog()

# --- Cleanup ---
foreach ($t in $timers) { $t.Stop() }
$tray.Dispose()
