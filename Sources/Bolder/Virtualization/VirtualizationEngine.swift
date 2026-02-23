import AppKit

/// The visibility zone for a tile.
enum TileZone {
    case live   // Intersects viewport
    case warm   // Within 2 tiles of viewport
    case cold   // Everything else
}

/// Manages tile content view lifecycle based on visibility.
final class VirtualizationEngine {
    private let pool: TileViewPool
    private let factory: TileViewFactory
    private let warmBuffer: Int = 2

    /// Maps tile ID → active content view
    private(set) var activeViews: [UUID: NSView & TileContentView] = [:]

    init(poolSize: Int, factory: TileViewFactory) {
        self.pool = TileViewPool(maxSizePerType: poolSize)
        self.factory = factory
    }

    /// Look up the active view for a given tile ID.
    func view(for tileID: UUID) -> (NSView & TileContentView)? {
        activeViews[tileID]
    }

    /// Update virtualization state based on current tile frames.
    func update(
        frames: [TileFrame],
        viewportWidth: CGFloat,
        tiles: [TileModel],
        containerView: NSView,
        fontSizeForType: (TileType) -> CGFloat
    ) {
        let viewport = CGRect(x: 0, y: 0, width: viewportWidth, height: 1)
        var newActiveIDs = Set<UUID>()

        // Determine zone for each tile
        for tf in frames {
            let zone = classify(frame: tf.frame, viewport: viewport, frames: frames, index: tf.index)
            let tileType = tiles[tf.index].tileType

            switch zone {
            case .live, .warm:
                newActiveIDs.insert(tf.tileID)

                if let existing = activeViews[tf.tileID] {
                    if existing.superview == nil {
                        containerView.addSubview(existing)
                    }
                    existing.frame = tf.frame
                    if zone == .live {
                        existing.activate()
                    } else {
                        existing.throttle()
                    }
                } else {
                    // Get or create a view
                    let view = pool.dequeue(for: tileType) ?? factory.makeView(for: tileType, frame: tf.frame)
                    view.resetForReuse()
                    view.configure(with: tiles[tf.index])
                    view.setFontSize(fontSizeForType(tileType))
                    view.frame = tf.frame
                    containerView.addSubview(view)
                    activeViews[tf.tileID] = view

                    if zone == .live {
                        view.activate()
                    } else {
                        view.throttle()
                    }
                }

            case .cold:
                break
            }
        }

        // Recycle views for tiles that are now cold
        for (id, view) in activeViews where !newActiveIDs.contains(id) {
            // Determine tile type for pool routing
            let tileType: TileType
            if let tile = tiles.first(where: { $0.id == id }) {
                tileType = tile.tileType
            } else {
                tileType = .placeholder
            }

            // Terminal and Claude views keep their state alive — just detach from superview
            if tileType == .terminal || tileType == .claude {
                view.removeFromSuperview()
            } else {
                view.suspend()
                view.removeFromSuperview()
                pool.enqueue(view, type: tileType)
                activeViews.removeValue(forKey: id)
            }
        }
    }

    /// Remove a specific tile's view (e.g. when tile is deleted).
    func removeView(for tileID: UUID) {
        guard let view = activeViews.removeValue(forKey: tileID) else { return }
        view.suspend()
        view.removeFromSuperview()
    }

    private func classify(
        frame: CGRect,
        viewport: CGRect,
        frames: [TileFrame],
        index: Int
    ) -> TileZone {
        // Check if frame intersects viewport (full height check not needed, just x-axis)
        let viewportX = CGRect(x: 0, y: frame.minY, width: viewport.width, height: frame.height)
        if frame.intersects(viewportX) {
            return .live
        }

        // Find indices of live tiles
        let liveIndices = frames.filter { tf in
            let vp = CGRect(x: 0, y: tf.frame.minY, width: viewport.width, height: tf.frame.height)
            return tf.frame.intersects(vp)
        }.map { $0.index }

        guard let minLive = liveIndices.min(), let maxLive = liveIndices.max() else {
            return .cold
        }

        if index >= minLive - warmBuffer && index <= maxLive + warmBuffer {
            return .warm
        }

        return .cold
    }
}
