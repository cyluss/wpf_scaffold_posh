#!/usr/bin/env bash
# WSL2 daemon warmup — run on window load to eliminate cold-boot delay

set -uo pipefail

echo "set lblStatus.Foreground #888"
echo "set lblStatus.Text WSL2 booting..."

# Quick distro check
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro="$PRETTY_NAME"
else
    distro="$(uname -s)"
fi

kernel="$(uname -r)"

echo "set lblStatus.Foreground #4CAF50"
echo "set lblStatus.Text WSL2 ready — $distro ($kernel)"
