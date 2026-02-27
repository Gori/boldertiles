import AppKit

/// A bounded pool of reusable tile content views, organized by view category.
final class TileViewPool {
    private var pools: [ViewCategory: [NSView & TileContentView]] = [:]
    private let maxSizePerType: Int

    init(maxSizePerType: Int) {
        self.maxSizePerType = maxSizePerType
    }

    /// Return a recycled view from the pool for the given category, or nil if empty.
    func dequeue(for category: ViewCategory) -> (NSView & TileContentView)? {
        guard var typePool = pools[category], !typePool.isEmpty else { return nil }
        let view = typePool.removeLast()
        pools[category] = typePool
        return view
    }

    /// Return a view to the pool for reuse.
    func enqueue(_ view: NSView & TileContentView, category: ViewCategory) {
        var typePool = pools[category] ?? []
        if typePool.count < maxSizePerType {
            typePool.append(view)
            pools[category] = typePool
        }
    }

    var count: Int {
        pools.values.reduce(0) { $0 + $1.count }
    }
}
