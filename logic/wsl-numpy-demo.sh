#!/usr/bin/env bash
# NumPy demo running inside WSL2 via uv

set -uo pipefail

echo "set lblStatus.Foreground #888"
echo "set lblStatus.Text WSL2 NumPy - preparing uv..."

# Ensure uv is available
if ! command -v uv &>/dev/null; then
    echo "set lblStatus.Text WSL2 NumPy - installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh 2>/dev/null | sh &>/dev/null
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "set lblStatus.Text WSL2 NumPy - computing..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
uv run "$SCRIPT_DIR/numpy-demo.py"
