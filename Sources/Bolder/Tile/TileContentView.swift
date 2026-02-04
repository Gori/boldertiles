import AppKit

/// Lifecycle protocol for tile content views managed by the virtualization engine.
protocol TileContentView: NSView {
    /// The tile is now visible in the viewport.
    func activate()
    /// The tile is in the warm zone — reduce work.
    func throttle()
    /// The tile is being recycled — stop all work.
    func suspend()
    /// Reset state for reuse with a new tile model.
    func resetForReuse()
    /// Configure with a tile model.
    func configure(with tile: TileModel)
    /// Update the font size for this tile's content.
    func setFontSize(_ size: CGFloat)
}
