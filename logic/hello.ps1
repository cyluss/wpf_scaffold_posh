# Pure logic — outputs UI commands to stdout, line by line
# Each line is dispatched to the UI as it arrives
param([string]$Name)

if (-not $Name) {
    "set lblOutput.Text Please enter your name"
    exit
}

"set lblOutput.Text Thinking..."
"disable btnHello"
Start-Sleep -Milliseconds 500

"set lblOutput.Text Hello, $Name!"
"enable btnHello"
