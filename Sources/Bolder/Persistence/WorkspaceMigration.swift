import Foundation

/// Migrates legacy tiles.json (StripModel) to workspace.json (WorkspaceModel).
enum WorkspaceMigration {

    /// Migrate a StripModel to a WorkspaceModel.
    /// - `.notes` tiles become ideas in `.note` phase
    /// - `.terminal` tiles become standalone terminals
    /// - `.claude` tiles become ideas in `.build` phase with session attached
    /// - `.placeholder` and `.features` tiles are discarded
    static func migrate(from strip: StripModel) -> WorkspaceModel {
        var items: [StripItem] = []
        var newFocusedIndex = 0
        var focusFound = false

        for (index, tile) in strip.tiles.enumerated() {
            let item: StripItem?

            switch tile.tileType {
            case .notes:
                var idea = IdeaModel(
                    id: tile.id,
                    phase: .note,
                    widthSpec: tile.widthSpec,
                    color: tile.color,
                    marinationPhase: tile.marinationPhase,
                    noteStatus: tile.noteStatus
                )
                // If marination was active, put in plan phase
                if tile.noteStatus == .active || tile.noteStatus == .waiting {
                    idea.phase = .plan
                }
                item = .idea(idea)

            case .terminal:
                item = .terminal(TerminalItem(
                    id: tile.id,
                    widthSpec: tile.widthSpec,
                    color: tile.color
                ))

            case .claude:
                let idea = IdeaModel(
                    id: tile.id,
                    phase: .build,
                    widthSpec: tile.widthSpec,
                    color: tile.color,
                    claudeSessionID: tile.id.uuidString
                )
                item = .idea(idea)

            case .placeholder, .features:
                item = nil
            }

            if let item {
                if index == strip.focusedIndex && !focusFound {
                    newFocusedIndex = items.count
                    focusFound = true
                }
                items.append(item)
            }
        }

        // Ensure at least one item
        if items.isEmpty {
            items = [.idea(IdeaModel())]
            newFocusedIndex = 0
        }

        // Clamp focused index
        newFocusedIndex = min(newFocusedIndex, items.count - 1)

        // Migrate font sizes: map old tile type keys to new category keys
        var fontSizes: [String: CGFloat] = [:]
        if let noteSize = strip.fontSizes["notes"] {
            fontSizes["idea"] = noteSize
        }
        if let termSize = strip.fontSizes["terminal"] {
            fontSizes["terminal"] = termSize
        }

        return WorkspaceModel(
            items: items,
            focusedIndex: newFocusedIndex,
            fontSizes: fontSizes
        )
    }
}
