# Bolder — Developer Handoff Brief (macOS, compositor-grade performance)

## 0) Summary

**Bolder** is a macOS-only, fullscreen, ultra-smooth, one-dimensional horizontal tiling workspace. The user can scroll/swipe through an endless strip of **tiles**. Tiles can be **resized with handles** to occupy proportions of the screen (½, ¾, etc.), and on ultrawide monitors **multiple tiles are visible and active simultaneously**.

Bolder is **project-based**: opening a folder creates a `.bolder/` directory inside it that stores project state (tiles, notes, etc.). Bolder will ship as an **open-source executable** (not App Store constrained). Later, tiles will include a `libghostty` terminal running multiple independent Claude Code sessions (within the same project).

Performance is a core requirement: interaction should feel like a window manager/compositor.

---

## 1) Non-negotiables

* Platform: **macOS only**
* Windowing: **single window**, designed for **fullscreen**
* Workspace: **one-dimensional horizontal strip**
* Multiple tiles visible side-by-side **and active at the same time**
* Navigation: linear only (no overview mode for now)
* Tile resize: **drag handle** between tiles
* Notes: **one tile = one note**, plain text + **Markdown support** but **no syntax colors**
* Claude Code: **separate Claude sessions**, same project
* `.bolder/` is created **automatically**
* Both **global settings** and **per-project settings**
* Visuals: “slick” but minimal (no parallax); focus on smoothness
* Distribution: open source, downloadable executable (no App Store sandbox constraints)

---

## 2) Phased delivery plan

### Phase 1 — Tiling system only (feel perfect)

Goal: the tiling compositor works and feels impeccable before adding content complexity.

Requirements:

* Horizontal strip of tiles
* Smooth trackpad scrolling + inertial scrolling
* Snap behavior: on gesture end, **snap to left-aligned focused tile**
* Multiple tiles visible and active simultaneously (viewport can include several tiles)
* Tile resize via handles
* Virtualization + performance instrumentation from day one
* Persistence of tile strip state to `.bolder/`

Deferred:

* Rule for “overscroll creates new tile” (explicitly TBD)

### Phase 2 — Add 2 tile types: Notes + Terminal

* Notes tile: plain text editor with Markdown (no coloring)
* Terminal tile: embedded terminal surface via `libghostty` (initially just shell)
* Verify virtualization doesn’t break editor/terminal input and rendering

### Phase 3 — Claude Code integration

* Terminal tile can launch Claude Code in PTY
* Multiple independent Claude sessions per project
* “Send note to Claude” / “Claude → note” is intentionally deferred (design space wide)

### Phase 4 — More tile types (including web tiles)

* Introduce WKWebView tiles only when needed
* Must not compromise compositor smoothness (aggressive lifecycle control)

---

## 3) Core UX spec (Phase 1)

### 3.1 Workspace model

* One strip of tiles `tiles[0...n-1]`
* User scrolls horizontally through strip
* There is always a “focused tile” (index)
* Snap aligns the focused tile’s **left edge** to the viewport left padding

### 3.2 Visibility + “active simultaneously”

* If multiple tiles are visible, **they are active** (not suspended simply because not focused).
* “Active” means: their content can update/respond (e.g., terminal output continues, note caret can exist only in one tile at a time, but tile itself remains alive if visible).
* However: heavy background work must still be controlled (see virtualization rules)

### 3.3 Tile sizing (niri-inspired)

Each tile has a `WidthSpec`:

* Proportional widths (fractions of viewport width): e.g. 1/3, 1/2, 2/3, 3/4, 1.0
* Fixed width (px) as a result of manual resize end-state

Sizing must account for:

* Inter-tile gap and viewport padding in width calculations
* Pixel snapping to avoid shimmer/blur during resize and animations (round to physical pixels)

### 3.4 Resize handles

* There is a draggable handle between adjacent tiles
* Dragging adjusts widths live
* Developer may choose constraints:

  * minimum width per tile
  * whether the drag affects just right tile, left tile, or distributes across visible region
* After drag end, widths persist as `.fixed(px)` or snapped to nearest preset fraction (developer decision; must feel good)

### 3.5 Scrolling + snapping

* Trackpad scroll should allow continuous movement
* On scroll end (gesture end), compute the best target focused tile (likely nearest by left-edge distance) and animate settle to left alignment
* No parallax; minimal but smooth animations

---

## 4) Performance architecture (Option A)

### 4.1 Rendering model

* AppKit as shell (window/input)
* Custom compositor view as the “strip host”
* Layer-backed tile containers
* During scroll/settle, move tile containers primarily with **GPU transforms** (translation), avoiding expensive layout churn

### 4.2 Virtualization rules

Hard requirement: keep frame pacing consistent.

Define 3 states for tiles based on distance from viewport:

* **Live-visible**: intersects viewport (or within small margin)
* **Warm**: adjacent (prefetch and keep lightweight state ready)
* **Cold**: far offscreen

Rules:

* Live-visible tiles can run (render, terminal output, etc.)
* Warm tiles should be initialized but throttled
* Cold tiles must do near-zero work:

  * no redraw
  * no timers
  * no text layout updates
  * terminals detach renderer (PTY may remain alive)
  * web tiles should be suspended or replaced with snapshots later

Mounting policy:

* Maintain only a bounded number of instantiated views (e.g., visible + 2 on either side)
* Reuse views where possible

### 4.3 Input and focus

* Exactly one focused tile receives keyboard input
* Trackpad gesture handling must not interfere with:

  * text selection in notes
  * terminal selection/paste
  * IME
* Developer should treat focus routing as a first-class subsystem

### 4.4 Metrics and tooling

Developer should build with Instruments in mind:

* Track frame drops during swipe
* Track time spent in layout, text, terminal rendering
* Guard against offscreen work regressions

---

## 5) Tile types

### 5.1 Note tile (Phase 2)

* Each tile corresponds to one note
* Plain text editor with Markdown support

  * Rendering can be plain text initially; Markdown parsing can be stored/used for future features
  * No syntax colors
* Must feel instant (fast typing, minimal UI)
* Persist note content per tile to `.bolder/notes/`

### 5.2 Terminal tile with libghostty (Phase 2)

* Each terminal tile hosts a PTY session
* Render with `libghostty`
* Terminal is a tile surface, subject to virtualization
* Ensure resizing tile triggers PTY resize events correctly

### 5.3 Claude Code (Phase 3)

* Claude Code runs in terminal tiles as separate sessions
* Multiple Claude Code sessions can exist in the same project

Deferred spec:

* “Send note to Claude / Claude to note” transformation behavior is intentionally postponed
* Expect eventual concept of “Claude blocks” and two-way conversion

---

## 6) Project model and persistence

### 6.1 Folder-based projects

* App opens exactly one folder (project root)
* On open, create `.bolder/` automatically

### 6.2 `.bolder/` structure (proposal)

Developer can adapt, but must meet goals: portable, inspectable, stable.

```
<ProjectRoot>/
  .bolder/
    project.json
    tiles.json
    notes/
      <tile-uuid>.md
    terminals/
      <tile-uuid>.json   (optional)
    cache/
      snapshots/         (optional)
```

### 6.3 State to persist

* Tiles: order, type, widthSpec, focused tile
* Note tile mapping to note file
* Terminal tile metadata (command, cwd, environment, etc.)
* Global settings live outside project (see below)

### 6.4 Global settings

* There are global settings in addition to per-project
* Where they live is up to developer (Application Support / UserDefaults / config file)
* Global settings should include at least:

  * default tile widths/presets
  * default tile kind created when needed
  * UI tuning (gap size, padding, scroll sensitivity)

---

## 7) Deferred / open decisions (explicitly allowed)

The developer is empowered to choose:

* The exact algorithm for:

  * how resizing affects neighboring tiles
  * whether manual resize snaps to presets or stays fixed
  * how to choose “focused tile” during scroll end
* The behavior for “swipe past end creates new tile” (deferred by product owner)
* The exact text engine approach (TextKit 2 vs custom) as long as performance and behavior are met
* Claude note↔block workflows (deferred)

---

## 8) Acceptance criteria (what “done” means per phase)

### Phase 1 acceptance

* Fullscreen horizontal strip
* Smooth scroll with inertia
* Snap to left-aligned focused tile
* Resize handles work and persist
* Multiple visible tiles remain interactive (not blank/suspended)
* Virtualization prevents offscreen work and keeps swipe smooth

### Phase 2 acceptance

* Notes tile edits markdown text; saved to `.bolder`
* Terminal tile runs a shell; stable, resizable; libghostty renders correctly
* No major perf regression vs Phase 1

### Phase 3 acceptance

* Terminal can launch Claude Code; multiple sessions in same project
* Sessions stable across app relaunch (at minimum: restore tiles; session persistence optional depending on feasibility)

---

# A few final “handoff notes” for the developer

* This product is effectively a lightweight compositor: treat tiles as surfaces, keep transforms cheap, and control lifecycle aggressively.
* Avoid Electron entirely; use native AppKit/CA, and later WKWebView only as tile content when needed.
* Always measure. Make smoothness a testable requirement.
