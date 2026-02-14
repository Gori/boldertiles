# Plan: Task Tile Type with Claude-Assisted Refinement

## Overview

Add a new `task` tile type. Users write rough notes, then convert them into structured tasks with Claude's help. Tasks live in their own tile with status tracking.

## User Flow

1. User has a Notes tile with rough text (e.g. "fix the scroll jank when resizing")
2. User presses a keyboard shortcut (e.g. Ctrl+T) on the focused Notes tile
3. A new Task tile is created next to the note, pre-populated with the note's text
4. A Claude session starts automatically, receiving the note text with a system prompt like: "Refine this into a clear, actionable task. Include: title, description, acceptance criteria, and suggested subtasks."
5. Claude's response streams into the Task tile, replacing/structuring the raw text
6. User can edit the result, or send follow-up messages to Claude to refine further

## Files to Change

### 1. `Sources/Bolder/Tile/TileModel.swift`
- Add `case task` to the `TileType` enum
- Add `contentInsets` for `.task` (same as notes: 28px all sides)
- Add default font size for `.task` (20, same as notes)

### 2. New file: `Sources/Bolder/Tile/TaskTileView.swift`
- Implements `TileContentView` protocol
- **UI**: Split layout — top section shows structured task fields (title, description, acceptance criteria, subtasks as checkboxes), bottom section is a small text input for sending refinement messages to Claude
- **Simpler alternative**: A single NSTextView (like NotesTileView) that displays the task as structured markdown, plus a small input field at the bottom for Claude interaction
- Uses same debounced-save pattern as NotesTileView
- Has a `ClaudeSession` instance for the refinement conversation (like ClaudeTileView but headless — no web UI, just process I/O)
- Renders Claude's streaming response into the task content area

### 3. New file: `Sources/Bolder/Persistence/TaskMeta.swift`
- `TaskMeta: Codable` struct with:
  - `sessionID: String?` — Claude session for ongoing refinement
  - `status: TaskStatus` — enum: `draft`, `todo`, `inProgress`, `done`
  - `sourceNoteID: UUID?` — link back to the originating note

### 4. `Sources/Bolder/Persistence/ProjectStore.swift`
- Add `tasksDirURL` (`.bolder/tasks/`)
- Add `loadTaskContent(for:)` / `saveTaskContent(_:for:)` / `deleteTaskContent(for:)` — same pattern as notes, saves as `.md`
- Add `loadTaskMeta(for:)` / `saveTaskMeta(_:for:)` / `deleteTaskMeta(for:)` — same pattern as ClaudeMeta, saves as `.json`

### 5. `Sources/Bolder/Tile/DefaultTileViewFactory.swift`
- Add `case .task` to the switch in `makeView(for:frame:)`, returning `TaskTileView(frame:projectStore:)`

### 6. `Sources/Bolder/Strip/StripView.swift`
- Add a new action/keyboard shortcut: "Convert note to task" (e.g. `convertNoteToTask`)
- Implementation: reads the focused tile's note content, calls `addTile(type: .task)`, passes the note content to the new TaskTileView, which kicks off a Claude refinement session
- Add `case .task` to the `removeFocusedTile()` cleanup switch (delete task content + meta, terminate Claude session)
- Add menu item for creating a task tile

### 7. `Sources/Bolder/App/KeyBinding.swift`
- Add `.convertNoteToTask` action and a default key binding (e.g. Ctrl+T)
- Add `.addTaskTile` action for creating an empty task tile

### 8. `Sources/Bolder/Virtualization/TileViewPool.swift` / `VirtualizationEngine.swift`
- Task tiles with active Claude sessions should follow the same policy as Claude tiles — not pooled when cold, session stays alive

## Key Design Decisions

**Why a separate tile type instead of a mode on Notes?**
- Tasks have metadata (status, acceptance criteria) that notes don't
- Separation keeps both tile types simple
- Tasks can be filtered/found by type later

**Why embed a headless ClaudeSession instead of reusing ClaudeTileView?**
- ClaudeTileView is a full WKWebView with React UI — heavyweight for this use case
- A task tile only needs to send one prompt and stream the response into a text view
- The Claude session can be terminated after refinement is done, or kept for follow-ups

**Why structured markdown instead of a custom UI?**
- Keeps it editable as plain text (familiar, flexible)
- Can render checkboxes from `- [ ]` markdown syntax later
- No need for a React UI — native NSTextView handles it

## Open Questions for You

1. **Should the Claude session persist?** After initial refinement, should the user be able to ask Claude to refine further? (Plan assumes yes — small input field at bottom)
2. **Status tracking UI** — Should status (draft/todo/in-progress/done) be a visual indicator on the tile (colored border? badge?) or just text in the markdown?
3. **Should converting a note to a task remove the original note?** Or keep both tiles?
