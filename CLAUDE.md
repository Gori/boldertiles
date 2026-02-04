# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build          # Build the project
swift test           # Run all 29 tests
swift test --filter BolderTests.StripLayoutTests    # Run a single test suite
swift test --filter BolderTests.StripLayoutTests/testSingleTileAtOrigin  # Run a single test
```

GhosttyKit is optional. The app builds and runs without it (no terminal tiles). To build with terminal support:
```bash
./Scripts/build-ghosttykit.sh   # Requires Zig (version matching vendor/ghostty/.zigversion)
```

## Architecture

Bolder is a macOS fullscreen horizontal tiling compositor. A single window contains a `StripView` with an unlimited horizontal strip of tiles. Users swipe between tiles, resize them, and each tile hosts content (notes editor, terminal, or placeholder).

### Core data flow

`StripModel` (tiles + focusedIndex + scrollOffset) → `StripLayout.layout()` (pure function) → `[TileFrame]` → applied to both `CALayer`s (visual) and `NSView`s (content) via `VirtualizationEngine`.

Layout is a pure function with no side effects. All state lives in `StripModel`. The `StripView` orchestrates input, layout, and rendering.

### Virtualization (3-zone lifecycle)

`VirtualizationEngine` classifies tiles into zones based on viewport proximity:
- **Live**: intersects viewport — `activate()` called, fully rendering
- **Warm**: within 2 tiles of viewport — `throttle()` called, initialized but reduced work
- **Cold**: offscreen — `suspend()` called, view recycled to `TileViewPool`

Exception: terminal views are never pooled. They stay in `activeViews` when cold (removed from superview but surface/PTY kept alive) so sessions survive scrolling.

### Tile content protocol

```swift
protocol TileContentView: NSView {
    func activate()
    func throttle()
    func suspend()
    func resetForReuse()
    func configure(with tile: TileModel)
}
```

Implementations: `PlaceholderTileView`, `NotesTileView`, `TerminalTileView`. New tile types implement this protocol and register in `DefaultTileViewFactory`.

### Width system

`WidthSpec` is either `.proportional(Fraction)` or `.fixed(CGFloat)`. `Fraction` uses exact rational arithmetic (numerator/denominator with GCD). After manual resize, widths snap to the nearest proportional preset within 20px tolerance.

### GhosttyKit conditional compilation

All Ghostty code is gated behind `#if GHOSTTY_AVAILABLE`. Package.swift detects the xcframework at build time and sets the flag. The app degrades gracefully without it.

Terminal architecture: `GhosttyBridge` (singleton, owns `ghostty_app_t`) → `TerminalSurfaceView` (owns `ghostty_surface_t`, translates NSEvents to Ghostty input) → wrapped by `TerminalTileView`. The C/Zig layer manages Metal rendering internally.

### Persistence

```
<project>/.bolder/
├── tiles.json              # StripModel (tile array, focus index)
├── notes/<uuid>.md         # Note content per tile
└── terminal/<uuid>.json    # TerminalMeta per tile
```

### Input routing

Keyboard shortcuts use `performKeyEquivalent` (fires before the responder chain) so Ctrl combos work regardless of which tile's inner view is first responder. Focus routing (`updateFirstResponder`) makes the appropriate inner view (NSTextView for notes, TerminalSurfaceView for terminal) the first responder.

### Rendering

Layer-backed with `CATransaction.setDisableActions(true)` during layout. Scroll uses GPU position transforms (no relayout). `pixelSnap()` rounds to physical pixels using display scale factor. `FrameMetrics` uses `os_signpost` for Instruments profiling.
