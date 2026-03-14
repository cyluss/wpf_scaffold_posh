# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///

import sys
import base64
import json
import time

method     = sys.argv[1] if len(sys.argv) > 1 else "GET"
url        = sys.argv[2] if len(sys.argv) > 2 else ""
tls_verify = sys.argv[3] if len(sys.argv) > 3 else "true"
body_type  = sys.argv[4] if len(sys.argv) > 4 else "None"
headers_b64 = sys.argv[5] if len(sys.argv) > 5 else ""
body_b64   = sys.argv[6] if len(sys.argv) > 6 else ""

import httpx

if not url:
    print("set lblStatus.Foreground #888")
    print("set lblStatus.Text Enter a URL")
    print("enable btnSend")
    print("disable btnCancel")
    sys.exit()

# Decode headers
headers = {}
if headers_b64:
    raw_headers = base64.b64decode(headers_b64).decode("utf-8")
    for line in raw_headers.splitlines():
        line = line.strip()
        if ":" in line:
            k, v = line.split(":", 1)
            headers[k.strip()] = v.strip()

# Decode body
body_text = ""
if body_b64:
    body_text = base64.b64decode(body_b64).decode("utf-8")

# Set content-type based on body_type if not already in headers
content = None
ct_key = next((k for k in headers if k.lower() == "content-type"), None)

if body_type == "JSON" and body_text:
    if not ct_key:
        headers["Content-Type"] = "application/json"
    content = body_text.encode("utf-8")
elif body_type == "Form" and body_text:
    if not ct_key:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    content = body_text.encode("utf-8")
elif body_type == "Text" and body_text:
    if not ct_key:
        headers["Content-Type"] = "text/plain"
    content = body_text.encode("utf-8")

verify = tls_verify == "true"

try:
    t0 = time.perf_counter()
    with httpx.Client(verify=verify, follow_redirects=True, timeout=30) as client:
        resp = client.request(method, url, headers=headers, content=content)
    elapsed = (time.perf_counter() - t0) * 1000

    # Status line
    size = len(resp.content)
    if size >= 1024:
        size_str = f"{size / 1024:.1f} KB"
    else:
        size_str = f"{size} B"
    status_text = f"{resp.status_code} {resp.reason_phrase} | {elapsed:.0f}ms | {size_str}"
    if resp.status_code < 400:
        color = "#4CAF50"
    else:
        color = "#FF8C00"
    print(f"set lblStatus.Foreground {color}")
    print(f"set lblStatus.Text {status_text}")
    sys.stdout.flush()

    # Build response text: headers + blank line + body
    resp_lines = []
    for k, v in resp.headers.items():
        resp_lines.append(f"{k}: {v}")
    resp_lines.append("")

    # Try pretty-print JSON
    body = resp.text
    ct = resp.headers.get("content-type", "")
    if "json" in ct or "javascript" in ct:
        try:
            parsed = json.loads(body)
            body = json.dumps(parsed, indent=2, ensure_ascii=False)
        except (json.JSONDecodeError, ValueError):
            pass

    resp_lines.append(body)
    full_response = "\n".join(resp_lines)

    encoded = base64.b64encode(full_response.encode("utf-8")).decode("ascii")
    print(f"setb64 txtResponse.Text {encoded}")

except Exception as e:
    err_msg = str(e).replace("\n", " ")
    print("set lblStatus.Foreground #FF8C00")
    print(f"set lblStatus.Text Error: {err_msg}")

print("enable btnSend")
print("disable btnCancel")
sys.stdout.flush()
