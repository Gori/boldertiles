#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
UI_DIR="$PROJECT_DIR/notes-ui"

echo "Building Notes UI..."
cd "$UI_DIR"

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Copy fonts into public/ so Vite includes them in the build
mkdir -p public/fonts
cp "$PROJECT_DIR/Fonts/JetBrainsMono[wght].ttf" "public/fonts/JetBrainsMono.ttf"
cp "$PROJECT_DIR/Fonts/JetBrainsMono-Italic[wght].ttf" "public/fonts/JetBrainsMono-Italic.ttf"

npm run build

echo "Notes UI built to Sources/Bolder/Resources/NotesUI/"
