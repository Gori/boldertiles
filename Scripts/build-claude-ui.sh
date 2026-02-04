#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
UI_DIR="$PROJECT_DIR/claude-ui"

echo "Building Claude UI..."
cd "$UI_DIR"

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

npm run build

echo "Claude UI built to Sources/Bolder/Resources/ClaudeUI/"
