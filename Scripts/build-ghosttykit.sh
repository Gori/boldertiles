#!/usr/bin/env bash
set -euo pipefail

# Build GhosttyKit.xcframework from the vendored Ghostty submodule.
#
# Requirements:
#   - Zig installed (version matching vendor/ghostty's minimum_zig_version)
#   - git submodules initialized (git submodule update --init)
#   - Metal Toolchain (xcodebuild -downloadComponent MetalToolchain)
#
# Override source location with GHOSTTY_SRC env var if needed.
#
# Output:
#   Frameworks/GhosttyKit.xcframework

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/Frameworks"
GHOSTTY_SRC="${GHOSTTY_SRC:-$PROJECT_ROOT/vendor/ghostty}"

if [ ! -d "$GHOSTTY_SRC" ] || [ ! -f "$GHOSTTY_SRC/build.zig" ]; then
    echo "Error: Ghostty source not found at $GHOSTTY_SRC"
    echo "Run: git submodule update --init"
    exit 1
fi

# Validate Zig is installed
if ! command -v zig &>/dev/null; then
    echo "Error: zig is not installed."
    echo "Install via: brew install zig"
    exit 1
fi

# Check minimum Zig version from build.zig.zon
REQUIRED_ZIG=$(grep 'minimum_zig_version' "$GHOSTTY_SRC/build.zig.zon" | head -1 | grep -o '"[^"]*"' | tr -d '"')
INSTALLED_ZIG=$(zig version)
if [ -n "$REQUIRED_ZIG" ] && [ "$INSTALLED_ZIG" != "$REQUIRED_ZIG" ]; then
    echo "Warning: Zig version mismatch (installed: $INSTALLED_ZIG, required: $REQUIRED_ZIG)"
    echo "Proceeding anyway — build may fail."
fi
echo "Zig version: $INSTALLED_ZIG (required: ${REQUIRED_ZIG:-unknown})"

echo "Building GhosttyKit from $GHOSTTY_SRC ..."
cd "$GHOSTTY_SRC"

# Build xcframework for native (macOS) only — skip iOS targets
zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dxcframework-target=native -Demit-macos-app=false

# The xcframework lands in macos/GhosttyKit.xcframework
BUILT_FRAMEWORK="$GHOSTTY_SRC/macos/GhosttyKit.xcframework"

if [ ! -d "$BUILT_FRAMEWORK" ]; then
    echo "Error: GhosttyKit.xcframework not found after build."
    echo "Searched: $BUILT_FRAMEWORK"
    exit 1
fi

# Copy to our Frameworks directory
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/GhosttyKit.xcframework"
cp -R "$BUILT_FRAMEWORK" "$OUTPUT_DIR/GhosttyKit.xcframework"

echo "GhosttyKit.xcframework installed at $OUTPUT_DIR/GhosttyKit.xcframework"
echo "Done. Run 'swift build' to compile with terminal support."
