import AppKit

/// Protocol for creating tile content views.
protocol TileViewFactory {
    func makeView(for item: StripItem, frame: NSRect) -> NSView & TileContentView
}

/// Default factory creating the appropriate view for each strip item type.
final class DefaultTileViewFactory: TileViewFactory {
    private let projectStore: ProjectStore
    private weak var marinationEngine: MarinationEngine?

    init(projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine
    }

    func makeView(for item: StripItem, frame: NSRect) -> NSView & TileContentView {
        switch item {
        case .idea:
            return IdeaTileView(frame: frame, projectStore: projectStore, marinationEngine: marinationEngine)
        case .terminal:
            return TerminalTileView(frame: frame)
        }
    }
}
