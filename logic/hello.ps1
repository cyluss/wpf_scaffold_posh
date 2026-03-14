# Pure logic — outputs UI commands to stdout, line by line
# Each line is dispatched to the UI as it arrives
param([string]$Name)

if (-not $Name) {
    "set lblOutput.Text Please enter your name"
    "enable btnHello"
    "disable btnCancel"
    exit
}

"set lblOutput.Text Thinking..."
"disable btnHello"
"enable btnCancel"

Start-Sleep -Milliseconds 500

# Check formal checkbox via type-aware set
"set chkFormal.IsChecked true"

# Spawn dynamic controls to show API result
"archetype labeled-input Label TextBox"
"spawn @labeled-input api-result pnlDynamic"
"set api-result_lbl.Content Endpoint:"
"set api-result_tbx.Text https://httpbin.org/get"

try {
    $resp = Invoke-RestMethod -Uri "https://httpbin.org/get?name=$Name" -TimeoutSec 5
    $origin = $resp.origin
    "set api-result_tbx.Text $origin"
    "set lblOutput.Text Hello, $Name! (origin: $origin)"
} catch {
    "set lblOutput.Text Hello, $Name! (offline)"
}
"enable btnHello"
"disable btnCancel"
