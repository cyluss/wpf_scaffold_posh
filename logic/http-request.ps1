param(
    [string]$Method     = "GET",
    [string]$Url        = "",
    [string]$TlsVerify  = "true",
    [string]$BodyType   = "None",
    [string]$HeadersB64 = "",
    [string]$BodyB64    = ""
)

if (-not $Url) {
    "set lblStatus.Foreground #888"
    "set lblStatus.Text Enter a URL"
    "enable btnSend"
    "disable btnCancel"
    exit
}

# Decode headers
$headers = @{}
if ($HeadersB64) {
    $rawHeaders = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($HeadersB64))
    foreach ($line in $rawHeaders -split "`n") {
        $line = $line.Trim()
        if ($line -match '^([^:]+):\s*(.*)$') {
            $headers[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
}

# Decode body
$bodyText = ""
if ($BodyB64) {
    $bodyText = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($BodyB64))
}

# Set content-type based on body type
$ctExists = $headers.Keys | Where-Object { $_.ToLower() -eq "content-type" }
if ($BodyType -eq "JSON" -and $bodyText -and -not $ctExists) {
    $headers["Content-Type"] = "application/json"
} elseif ($BodyType -eq "Form" -and $bodyText -and -not $ctExists) {
    $headers["Content-Type"] = "application/x-www-form-urlencoded"
} elseif ($BodyType -eq "Text" -and $bodyText -and -not $ctExists) {
    $headers["Content-Type"] = "text/plain"
}

# TLS bypass for PS 5.1
if ($TlsVerify -eq "false") {
    try {
        Add-Type @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class TrustAll {
    public static void Enable() {
        ServicePointManager.ServerCertificateValidationCallback =
            delegate { return true; };
    }
}
"@
        [TrustAll]::Enable()
    } catch {
        # Type may already be added
    }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $iwr = @{
        Uri     = $Url
        Method  = $Method
        Headers = $headers
        UseBasicParsing = $true
    }
    if ($bodyText -and $BodyType -ne "None") {
        $iwr.Body = $bodyText
    }
    $resp = Invoke-WebRequest @iwr
    $sw.Stop()
    $elapsed = $sw.ElapsedMilliseconds

    # Status line
    $size = if ($resp.Content) { [System.Text.Encoding]::UTF8.GetByteCount($resp.Content) } else { 0 }
    if ($size -ge 1024) {
        $sizeStr = "{0:F1} KB" -f ($size / 1024)
    } else {
        $sizeStr = "$size B"
    }
    $statusText = "$($resp.StatusCode) $($resp.StatusDescription) | ${elapsed}ms | $sizeStr"
    $color = if ([int]$resp.StatusCode -lt 400) { "#4CAF50" } else { "#FF8C00" }
    "set lblStatus.Foreground $color"
    "set lblStatus.Text $statusText"

    # Build response: headers + body
    $respLines = @()
    foreach ($key in $resp.Headers.Keys) {
        $respLines += "${key}: $($resp.Headers[$key])"
    }
    $respLines += ""

    $body = $resp.Content
    $ct = $resp.Headers["Content-Type"]
    if ($ct -and ($ct -match "json|javascript")) {
        try {
            $parsed = $body | ConvertFrom-Json
            $body = $parsed | ConvertTo-Json -Depth 10
        } catch { }
    }
    $respLines += $body
    $fullResponse = $respLines -join "`n"

    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($fullResponse))
    "setb64 txtResponse.Text $encoded"
} catch {
    $sw.Stop()
    $errMsg = $_.Exception.Message -replace "`n", " "
    "set lblStatus.Foreground #FF8C00"
    "set lblStatus.Text Error: $errMsg"
}

"enable btnSend"
"disable btnCancel"
