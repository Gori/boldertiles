import AppKit

/// A simple colored rectangle tile for Phase 1.
final class PlaceholderTileView: NSView, TileContentView {
    private let debugOverlay = TileDebugOverlay()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        debugOverlay.install(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(with tile: TileModel) {
        let c = tile.color
        layer?.backgroundColor = CGColor(
            red: c.red, green: c.green, blue: c.blue, alpha: 1.0
        )
        debugOverlay.setLines(["placeholder"])
    }

    func activate() {}
    func throttle() {}
    func suspend() {}

    func resetForReuse() {
        layer?.backgroundColor = CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    }

    func setFontSize(_ size: CGFloat) {}
}
