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
        items: [StripItem],
        containerView: NSView,
        fontSizeForCategory: (ViewCategory) -> CGFloat
    ) {
        let viewport = CGRect(x: 0, y: 0, width: viewportWidth, height: 1)
        var newActiveIDs = Set<UUID>()

        // Determine zone for each item
        for tf in frames {
            let zone = classify(frame: tf.frame, viewport: viewport, frames: frames, index: tf.index)
            let item = items[tf.index]
            let category = item.viewCategory

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
                    let view = pool.dequeue(for: category) ?? factory.makeView(for: item, frame: tf.frame)
                    view.resetForReuse()
                    view.configureWithItem(items[tf.index])
                    view.setFontSize(fontSizeForCategory(category))
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

        // Recycle views for items that are now cold
        for (id, view) in activeViews where !newActiveIDs.contains(id) {
            let item = items.first { $0.id == id }
            let keepAlive = item?.keepAliveWhenCold ?? false
            let category = item?.viewCategory ?? .idea

            if keepAlive {
                // Terminal and Build-phase idea views keep their state alive — just detach
                view.removeFromSuperview()
            } else {
                view.suspend()
                view.removeFromSuperview()
                pool.enqueue(view, category: category)
                activeViews.removeValue(forKey: id)
            }
        }
    }

    /// Remove a specific item's view (e.g. when item is deleted).
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

// MARK: - StripItem helpers

extension StripItem {
    var viewCategory: ViewCategory {
        switch self {
        case .idea: return .idea
        case .terminal: return .terminal
        }
    }
}
