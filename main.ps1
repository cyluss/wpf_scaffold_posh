#Requires -Version 5.1
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$engineDir = Join-Path $PSScriptRoot "engine"
$logicDir  = Join-Path $PSScriptRoot "logic"

# --- Engine: dot-source all engine files ---
Get-ChildItem $engineDir -Filter "*.ps1" | ForEach-Object { . $_.FullName }

# --- Launch ---
Start-App $PSScriptRoot
