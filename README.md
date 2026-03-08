# WPF Scaffold for PowerShell

A declarative WPF GUI scaffold for PowerShell — define your UI, tray, and timers in XML/XAML, and implement logic in auto-scaffolded `actions/*.ps1` files. No C#, no Visual Studio required.

## Structure

```
main.ps1              # Engine — never needs editing
main.xaml             # WPF UI layout
tray.xml              # System tray icon & context menu
timers.xml            # DispatcherTimer definitions
actions/
    Initialize-Tray.ps1     # Tray setup (reads tray.xml)
    Initialize-Timers.ps1   # Timer setup (reads timers.xml)
    Show-Window.ps1         # Tray: Show action
    Stop-App.ps1            # Tray: Exit action
    Update-Clock.ps1        # Timer tick: update clock label
    Invoke-HelloClick.ps1   # Button click handler
```

## How It Works

1. **UI** — Add controls to `main.xaml`. Wire events with `Click="Verb-Noun"`.
2. **Tray** — Add `<MenuItem Header="..." Action="Verb-Noun"/>` to `tray.xml`.
3. **Timers** — Add `<Timer Name="..." Interval="1000" AutoStart="true" Tick="Verb-Noun"/>` to `timers.xml`.
4. **Run** — `main.ps1` auto-scaffolds missing `actions/*.ps1` stubs on first run.
5. **Implement** — Fill in the function body in the generated file.

## Running

```powershell
powershell -ExecutionPolicy Bypass -File main.ps1
```

## Tray Behaviour

- Closing the window minimizes to the system tray (PowerShell blue icon).
- Double-click tray icon to restore.
- Right-click for **Show** / **Exit** menu (configurable in `tray.xml`).

## Adding a New Button

1. Add to `main.xaml`:
   ```xml
   <Button x:Name="btnSave" Content="Save" Click="Invoke-Save"/>
   ```
2. Run `main.ps1` — `actions/Invoke-Save.ps1` is auto-created.
3. Edit `actions/Invoke-Save.ps1` with your logic.

## Adding a New Timer

1. Add to `timers.xml`:
   ```xml
   <Timer Name="refreshTimer" Interval="5000" AutoStart="true" Tick="Invoke-Refresh"/>
   ```
2. Run `main.ps1` — `actions/Invoke-Refresh.ps1` is auto-created.
3. Edit `actions/Invoke-Refresh.ps1` with your logic.

## Requirements

- Windows PowerShell 5.1+
- .NET Framework (ships with Windows)
