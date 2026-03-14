# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///

import sys
import httpx

name = sys.argv[1] if len(sys.argv) > 1 else ""

if not name:
    print("set lblOutput.Text Please enter your name")
    print("enable btnHello")
    print("disable btnCancel")
    sys.exit()

print("set lblOutput.Text Looking up info...")
print("disable btnHello")
print("enable btnCancel")
sys.stdout.flush()

# Check formal checkbox via type-aware set
print("set chkFormal.IsChecked true")

# Spawn dynamic controls to show API result
print("archetype labeled-input Label TextBox")
print("spawn @labeled-input api-result pnlDynamic")
print("set api-result_lbl.Content Endpoint:")
print("set api-result_tbx.Text https://httpbin.org/get")
sys.stdout.flush()

try:
    resp = httpx.get(f"https://httpbin.org/get?name={name}", timeout=5)
    data = resp.json()
    origin = data.get("origin", "unknown")
    print(f"set api-result_tbx.Text {origin}")
    print(f"set lblOutput.Text Hello, {name}! (origin: {origin})")
except Exception as e:
    print(f"set lblOutput.Text Hello, {name}! (offline)")

print("enable btnHello")
print("disable btnCancel")
