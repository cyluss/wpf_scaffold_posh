function Initialize-Tray {
    param($window, $projectRoot, $actionsDir)

    $trayXmlPath = Join-Path $projectRoot "tray.xml"

    # --- Parse tray.xml ---
    [xml]$trayXml  = Get-Content $trayXmlPath -Raw
    $trayNode      = $trayXml.Tray
    $balloonMsg    = $trayNode.BalloonMessage

    # --- Build NotifyIcon ---
    $tray = [System.Windows.Forms.NotifyIcon]::new()
    $psExe = Join-Path $PSHOME "powershell.exe"
    $tray.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($psExe)
    $tray.Text    = $trayNode.ToolTip
    $tray.Visible = $true

    $ctxMenu = [System.Windows.Forms.ContextMenuStrip]::new()
    $tray.ContextMenuStrip = $ctxMenu

    # --- Scaffold & wire menu items from tray.xml ---
    foreach ($item in $trayNode.ContextMenu.MenuItem) {
        $header = $item.Header
        $action = $item.Action

        if ($header -eq '---') {
            $ctxMenu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
            continue
        }

        $menuItem = [System.Windows.Forms.ToolStripMenuItem]::new($header)
        $ctxMenu.Items.Add($menuItem) | Out-Null

        if ($action) {
            Ensure-ActionLoaded $action $actionsDir

            $fn = Get-Item "function:$action"
            $menuItem.Add_Click($fn.ScriptBlock)
        }
    }

    # Minimize to tray on close
    $window.Add_Closing({
        param($s, $e)
        $e.Cancel = $true
        $window.Hide()
        $tray.ShowBalloonTip(1500, $window.Title, $balloonMsg, [System.Windows.Forms.ToolTipIcon]::Info)
    }.GetNewClosure())

    # Restore on tray double-click
    $tray.Add_DoubleClick({
        $window.Show()
        $window.WindowState = 'Normal'
        $window.Activate()
    }.GetNewClosure())

    return $tray
}
