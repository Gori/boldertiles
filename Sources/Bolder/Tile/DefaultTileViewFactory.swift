import AppKit

/// Protocol for creating tile content views by type.
protocol TileViewFactory {
    func makeView(for type: TileType, frame: NSRect) -> NSView & TileContentView
}

/// Default factory creating the appropriate view for each tile type.
final class DefaultTileViewFactory: TileViewFactory {
    private let projectStore: ProjectStore

    init(projectStore: ProjectStore) {
        self.projectStore = projectStore
    }

    func makeView(for type: TileType, frame: NSRect) -> NSView & TileContentView {
        switch type {
        case .placeholder:
            return PlaceholderTileView(frame: frame)
        case .notes:
            return NotesTileView(frame: frame, projectStore: projectStore)
        case .terminal:
            return TerminalTileView(frame: frame)
        case .features:
            return FeaturesTileView(frame: frame, projectStore: projectStore)
        }
    }
}
