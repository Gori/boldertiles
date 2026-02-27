# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build          # Build the project
swift test           # Run all 125 tests
swift test --filter BolderTests.StripLayoutTests    # Run a single test suite
swift test --filter BolderTests.StripLayoutTests/testSingleTileAtOrigin  # Run a single test
```

GhosttyKit is optional. The app builds and runs without it (no terminal tiles). To build with terminal support:
```bash
./Scripts/build-ghosttykit.sh   # Requires Zig (version matching vendor/ghostty/.zigversion)
```

## Architecture

Bolder is a macOS fullscreen idea-centric tiling compositor. Ideas are the primary entity — each idea is an evolved note that gains a Claude Code session when it reaches the Build phase. Three view modes (Strip, Build, Kanban) provide different lenses onto the same data.

### Core data model

- **IdeaModel**: primary entity with `phase` (Note → Plan → Build → Done), `widthSpec`, `color`, `marinationPhase`, `noteStatus`
- **StripItem**: enum `.idea(IdeaModel)` | `.terminal(TerminalItem)` — items in the strip
- **WorkspaceModel**: top-level state containing `[StripItem]`, `focusedIndex`, `scrollOffset`, `viewMode`, `selectedBuildIdeaID`, `fontSizes`
- **ViewMode**: `.strip` | `.build` | `.kanban`

### View hierarchy

`WorkspaceView` (top-level) owns three child views, one visible at a time:
- **StripView**: horizontal tile strip (Cmd+1)
- **BuildView**: sidebar + Claude Code + note panel (Cmd+2)
- **KanbanView**: four-column board (Cmd+3)

### Core data flow (Strip mode)

`WorkspaceModel` (items + focusedIndex + scrollOffset) → `StripLayout.layout()` (pure generic function over `Layoutable` protocol) → `[TileFrame]` → applied to both `CALayer`s (visual) and `NSView`s (content) via `VirtualizationEngine`.

Layout is a pure function with no side effects. All state lives in `WorkspaceModel`. The `StripView` orchestrates input, layout, and rendering.

### Idea phases and AI behavior

- **Note**: free writing, no AI assistance
- **Plan**: structured suggestions via MarinationEngine (background Claude requests)
- **Build**: Claude Code terminal session (toggled with note view via Cmd+.)
- **Done**: read-only appearance (dimmed)

### IdeaTileView (composite tile)

`IdeaTileView` adapts its content based on idea phase. Internally owns a `NotesTileView` (always) and a `ClaudeTileView` (lazy, created on first Build phase entry). In Build phase, Cmd+. toggles between note and Claude Code views.

### Virtualization (3-zone lifecycle)

`VirtualizationEngine` classifies items into zones based on viewport proximity:
- **Live**: intersects viewport — `activate()` called, fully rendering
- **Warm**: within 2 items of viewport — `throttle()` called, initialized but reduced work
- **Cold**: offscreen — `suspend()` called, view recycled to `TileViewPool`

Exception: terminals and Build-phase ideas are never pooled (`keepAliveWhenCold`). They stay in `activeViews` when cold so sessions survive scrolling.

Pool is keyed by `ViewCategory` (`.idea` | `.terminal`).

### Tile content protocol

```swift
protocol TileContentView: NSView {
    func activate()
    func throttle()
    func suspend()
    func resetForReuse()
    func configure(with tile: TileModel)
    func configureWithItem(_ item: StripItem)
}
```

Implementations: `IdeaTileView`, `NotesTileView`, `TerminalTileView`, `ClaudeTileView`. New tile types implement this protocol and register in `DefaultTileViewFactory`.

### Width system

`WidthSpec` is either `.proportional(Fraction)` or `.fixed(CGFloat)`. `Fraction` uses exact rational arithmetic (numerator/denominator with GCD). After manual resize, widths snap to the nearest proportional preset within 20px tolerance.

### GhosttyKit conditional compilation

All Ghostty code is gated behind `#if GHOSTTY_AVAILABLE`. Package.swift detects the xcframework at build time and sets the flag. The app degrades gracefully without it.

Terminal architecture: `GhosttyBridge` (singleton, owns `ghostty_app_t`) → `TerminalSurfaceView` (owns `ghostty_surface_t`, translates NSEvents to Ghostty input) → wrapped by `TerminalTileView`. The C/Zig layer manages Metal rendering internally.

### Persistence

```
<project>/.bolder/
├── workspace.json          # WorkspaceModel (items, focus index, view mode)
├── notes/<uuid>.md         # Note content per idea
├── terminal/<uuid>.json    # TerminalMeta per terminal
└── marination/<uuid>.json  # MarinationState per idea (Plan phase)
```

Legacy `tiles.json` is auto-migrated to `workspace.json` via `WorkspaceMigration` on first load.

### Input routing

Keyboard shortcuts use `performKeyEquivalent` (fires before the responder chain) so Ctrl combos work regardless of which tile's inner view is first responder. Focus routing (`updateFirstResponder`) makes the appropriate inner view (WKWebView for notes, TerminalSurfaceView for terminal/claude) the first responder.

Key shortcuts: Cmd+1/2/3 switch modes, Cmd+Shift+Right advances idea phase, Cmd+. toggles note/Claude in Build phase.

### Rendering

Layer-backed with `CATransaction.setDisableActions(true)` during layout. Scroll uses GPU position transforms (no relayout). `pixelSnap()` rounds to physical pixels using display scale factor. `FrameMetrics` uses `os_signpost` for Instruments profiling.
