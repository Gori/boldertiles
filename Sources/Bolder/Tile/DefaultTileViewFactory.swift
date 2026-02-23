import AppKit

/// Protocol for creating tile content views by type.
protocol TileViewFactory {
    func makeView(for type: TileType, frame: NSRect) -> NSView & TileContentView
}

/// Default factory creating the appropriate view for each tile type.
final class DefaultTileViewFactory: TileViewFactory {
    private let projectStore: ProjectStore
    private weak var marinationEngine: MarinationEngine?

    init(projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine
    }

    func makeView(for type: TileType, frame: NSRect) -> NSView & TileContentView {
        switch type {
        case .placeholder:
            return PlaceholderTileView(frame: frame)
        case .notes:
            return NotesTileView(frame: frame, projectStore: projectStore, marinationEngine: marinationEngine)
        case .terminal:
            return TerminalTileView(frame: frame)
        case .claude:
            return ClaudeTileView(frame: frame, projectStore: projectStore)
        case .features:
            return FeaturesTileView(frame: frame, projectStore: projectStore)
        }
    }
}
