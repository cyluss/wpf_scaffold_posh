# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///

import sys
import httpx

name = sys.argv[1] if len(sys.argv) > 1 else ""

if not name:
    print("set lblOutput.Text Please enter your name")
    sys.exit()

print("set lblOutput.Text Looking up info...")
print("disable btnHello")
sys.stdout.flush()

try:
    resp = httpx.get(f"https://api.agify.io/?name={name}", timeout=5)
    data = resp.json()
    age = data.get("age", "unknown")
    print(f"set lblOutput.Text Hello, {name}! (predicted age: {age})")
except Exception as e:
    print(f"set lblOutput.Text Hello, {name}! (offline)")

print("enable btnHello")
