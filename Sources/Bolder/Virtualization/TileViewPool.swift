import AppKit

/// A bounded pool of reusable tile content views, organized by tile type.
final class TileViewPool {
    private var pools: [TileType: [NSView & TileContentView]] = [:]
    private let maxSizePerType: Int

    init(maxSizePerType: Int) {
        self.maxSizePerType = maxSizePerType
    }

    /// Return a recycled view from the pool for the given type, or nil if empty.
    func dequeue(for type: TileType) -> (NSView & TileContentView)? {
        guard var typePool = pools[type], !typePool.isEmpty else { return nil }
        let view = typePool.removeLast()
        pools[type] = typePool
        return view
    }

    /// Return a view to the pool for reuse.
    func enqueue(_ view: NSView & TileContentView, type: TileType) {
        var typePool = pools[type] ?? []
        if typePool.count < maxSizePerType {
            typePool.append(view)
            pools[type] = typePool
        }
    }

    var count: Int {
        pools.values.reduce(0) { $0 + $1.count }
    }
}
