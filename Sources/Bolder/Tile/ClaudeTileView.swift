import AppKit
import GhosttyKit

/// A tile that runs the `claude` CLI in a Ghostty terminal surface.
/// Uses `--session-id` on first launch and `--resume` on app restart
/// so the conversation survives across sessions.
final class ClaudeTileView: NSView, TileContentView {
    private let surfaceView = TerminalSurfaceView(frame: .zero)
    private let debugOverlay = TileDebugOverlay()
    private let projectStore: ProjectStore
    private var tileID: UUID?

    init(frame frameRect: NSRect, projectStore: ProjectStore) {
        self.projectStore = projectStore
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = GhosttyBridge.shared.backgroundColor

        surfaceView.frame = insetContentFrame(bounds)
        addSubview(surfaceView)
        debugOverlay.install(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        surfaceView.frame = insetContentFrame(bounds)
    }

    private func insetContentFrame(_ rect: NSRect) -> NSRect {
        let m = TileType.claude.contentInsets
        return NSRect(
            x: m.left,
            y: m.bottom,
            width: max(0, rect.width - m.left - m.right),
            height: max(0, rect.height - m.top - m.bottom)
        )
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        tileID = tile.id

        if surfaceView.surface == nil {
            TerminalSessionManager.shared.markActive(tile.id)

            let sessionId = tile.id.uuidString
            let command: String
            if projectStore.loadTerminalMeta(for: tile.id) != nil {
                // Session was launched before — resume it
                command = "claude --resume \(sessionId)"
            } else {
                // First launch — create session with this specific ID
                command = "claude --session-id \(sessionId)"
                projectStore.saveTerminalMeta(
                    TerminalMeta(command: "claude", cwd: nil, environment: nil),
                    for: tile.id
                )
            }

            surfaceView.createSurface(workingDirectory: nil, command: command)
        }

        debugOverlay.setLines(["claude"])
    }

    func activate() {}
    func throttle() {}
    func suspend() {}

    func resetForReuse() {
        if let id = tileID {
            TerminalSessionManager.shared.markInactive(id)
        }
        surfaceView.destroySurface()
        tileID = nil
    }

    func setFontSize(_ size: CGFloat) {
        guard let surface = surfaceView.surface else { return }
        let action = "set_font_size:\(Int(size))"
        _ = ghostty_surface_binding_action(surface, action, UInt(action.utf8.count))
    }

    /// The inner surface view, for first-responder routing.
    var innerSurfaceView: TerminalSurfaceView { surfaceView }
}
