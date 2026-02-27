import AppKit

final class MainWindow: NSWindow {
    private let workspaceView: WorkspaceView

    init(model: WorkspaceModel, projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        guard let screen = NSScreen.main else {
            fatalError("No screen available")
        }

        let workspaceView = WorkspaceView(model: model, projectStore: projectStore, marinationEngine: marinationEngine)
        self.workspaceView = workspaceView

        super.init(
            contentRect: screen.visibleFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentView = workspaceView
        self.backgroundColor = .black
        self.isMovableByWindowBackground = false
        self.level = .normal
        self.collectionBehavior = [.fullScreenPrimary, .managed]
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.toggleFullScreen(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
