# Pure logic — outputs UI commands to stdout
# Can be rewritten in any language (Python, Rust, Go, etc.)
$time = (Get-Date).ToString("HH:mm:ss")
"set lblClock.Text $time"
