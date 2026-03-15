#!/usr/bin/env bash
# WSL2 Rocky 9 system info — outputs UI commands to stdout

set -uo pipefail

echo "set lblStatus.Foreground #888"
echo "set lblStatus.Text Querying WSL2 Rocky 9..."

lines=()

# OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    lines+=("OS: $PRETTY_NAME")
fi

# Kernel
lines+=("Kernel: $(uname -r)")

# Hostname
lines+=("Hostname: $(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo 'unknown')")

# Uptime
lines+=("Uptime: $(uptime -p 2>/dev/null || uptime)")

# CPU
cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
cores=$(nproc 2>/dev/null || echo "?")
lines+=("CPU: ${cpu:-unknown} (${cores} cores)")

# Memory
if command -v free &>/dev/null; then
    mem=$(free -h | awk '/^Mem:/{printf "%s used / %s total", $3, $2}')
    lines+=("Memory: $mem")
fi

# Disk
if command -v df &>/dev/null; then
    disk=$(df -h / | awk 'NR==2{printf "%s used / %s total (%s)", $3, $2, $5}')
    lines+=("Disk (/): $disk")
fi

# IP
if command -v ip &>/dev/null; then
    ipaddr=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}' | head -1)
    [ -n "$ipaddr" ] && lines+=("IP (eth0): $ipaddr")
fi

# DNF packages (Rocky/RHEL) — rpm is instant, dnf is slow
if command -v rpm &>/dev/null; then
    pkg_count=$(rpm -qa 2>/dev/null | wc -l)
    lines+=("Packages (rpm): $pkg_count installed")
fi

# SELinux
if command -v getenforce &>/dev/null; then
    lines+=("SELinux: $(getenforce 2>/dev/null || echo 'unknown')")
fi

# Systemd (if available in WSL)
if command -v systemctl &>/dev/null; then
    state=$(systemctl is-system-running 2>/dev/null || true)
    if [ "$state" != "offline" ]; then
        running=$(timeout 3 systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)
        lines+=("Services: $running running")
    fi
fi

# Format output
result=$(printf '%s\n' "${lines[@]}")
encoded=$(printf '%s' "$result" | base64 -w 0)

echo "setb64 txtResponse.Text $encoded"
echo "set lblStatus.Foreground #4CAF50"
echo "set lblStatus.Text WSL2 Rocky 9 — ${#lines[@]} items collected"
echo "enable btnSend"
echo "enable btnWsl"
echo "disable btnCancel"
