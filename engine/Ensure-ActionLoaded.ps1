function Ensure-ActionLoaded {
    param([string]$Name, [string]$Dir)
    $file = Join-Path $Dir "$Name.ps1"
    if (-not (Test-Path $file)) {
        @(
            "function $Name {"
            "    param(`$sender, `$e)"
            "    # TODO: implement $Name"
            "}"
        ) | Set-Content $file -Encoding UTF8
        Write-Host "Scaffolded: $file"
    }
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        . $file
    }
}
