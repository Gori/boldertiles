import AppKit

final class MainWindow: NSWindow {
    private let stripView: StripView

    init(stripModel: StripModel, projectStore: ProjectStore) {
        guard let screen = NSScreen.main else {
            fatalError("No screen available")
        }

        let stripView = StripView(model: stripModel, projectStore: projectStore)
        self.stripView = stripView

        super.init(
            contentRect: screen.visibleFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentView = stripView
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
