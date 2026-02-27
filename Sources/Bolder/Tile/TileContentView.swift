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
    /// Configure with a tile model (legacy).
    func configure(with tile: TileModel)
    /// Configure with a strip item (new).
    func configureWithItem(_ item: StripItem)
    /// Update the font size for this tile's content.
    func setFontSize(_ size: CGFloat)
}

/// Default implementations so existing views don't need to implement both configure methods.
extension TileContentView {
    func configureWithItem(_ item: StripItem) {
        // Default: convert to TileModel for backward compatibility
        switch item {
        case .idea(let idea):
            let tile = TileModel(
                id: idea.id,
                widthSpec: idea.widthSpec,
                tileType: .notes,
                color: idea.color,
                noteStatus: idea.noteStatus,
                marinationPhase: idea.marinationPhase
            )
            configure(with: tile)
        case .terminal(let term):
            let tile = TileModel(
                id: term.id,
                widthSpec: term.widthSpec,
                tileType: .terminal,
                color: term.color
            )
            configure(with: tile)
        }
    }
}
