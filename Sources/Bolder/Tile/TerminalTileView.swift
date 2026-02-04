import AppKit
import GhosttyKit

/// A tile wrapping a TerminalSurfaceView for the virtualization engine.
final class TerminalTileView: NSView, TileContentView {
    private let surfaceView = TerminalSurfaceView(frame: .zero)
    private let debugOverlay = TileDebugOverlay()
    private var tileID: UUID?

    override init(frame frameRect: NSRect) {
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
        let m = TileType.terminal.contentInsets
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

        // Create surface if one doesn't exist yet
        if surfaceView.surface == nil {
            TerminalSessionManager.shared.markActive(tile.id)
            surfaceView.createSurface(workingDirectory: nil)
        }

        debugOverlay.setLines(["terminal"])
    }

    func activate() {
        // Terminal is fully active — rendering via Metal
    }

    func throttle() {
        // Could reduce frame rate, but for now keep active
    }

    func suspend() {
        // Keep the surface alive so the PTY session survives scrolling offscreen
    }

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
