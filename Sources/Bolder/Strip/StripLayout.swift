import Foundation

/// The computed frame for a single tile.
struct TileFrame: Equatable {
    let index: Int
    let tileID: UUID
    let frame: CGRect
}

/// Protocol for items that can be laid out in the strip.
protocol Layoutable {
    var id: UUID { get }
    var widthSpec: WidthSpec { get }
}

/// TileModel conforms for backward compatibility.
extension TileModel: Layoutable {}

/// StripItem conforms for the new workspace model.
extension StripItem: Layoutable {}

/// Pure function: given layoutable items, viewport size, and scroll offset, produce pixel-snapped tile frames.
enum StripLayout {
    static let tileGap: CGFloat = 0.0
    static let tileMargin: CGFloat = 4.0

    /// Compute tile frames for the strip.
    static func layout<T: Layoutable>(
        tiles: [T],
        viewportSize: CGSize,
        scrollOffset: CGFloat,
        scale: CGFloat = 2.0
    ) -> [TileFrame] {
        guard !tiles.isEmpty else { return [] }

        var frames: [TileFrame] = []
        var x: CGFloat = -scrollOffset

        for (index, tile) in tiles.enumerated() {
            let rawWidth = tile.widthSpec.resolve(viewportWidth: viewportSize.width)
            let width = max(rawWidth, StripLayout.minimumTileWidth)
            let rect = CGRect(x: x, y: 0, width: width, height: viewportSize.height)
            let inset = rect.insetBy(dx: tileMargin, dy: tileMargin)
            let snapped = pixelSnap(inset, scale: scale)
            frames.append(TileFrame(index: index, tileID: tile.id, frame: snapped))
            x += width + tileGap
        }

        return frames
    }

    /// Total content width for all items.
    static func totalContentWidth<T: Layoutable>(
        tiles: [T],
        viewportWidth: CGFloat
    ) -> CGFloat {
        guard !tiles.isEmpty else { return 0 }
        let widths = tiles.map { max($0.widthSpec.resolve(viewportWidth: viewportWidth), minimumTileWidth) }
        return widths.reduce(0, +) + CGFloat(tiles.count - 1) * tileGap
    }

    /// The scroll offset that left-aligns the item at the given index.
    static func snapOffset<T: Layoutable>(
        forTileAt index: Int,
        tiles: [T],
        viewportWidth: CGFloat
    ) -> CGFloat {
        guard index >= 0, index < tiles.count else { return 0 }
        var offset: CGFloat = 0
        for i in 0..<index {
            let width = max(tiles[i].widthSpec.resolve(viewportWidth: viewportWidth), minimumTileWidth)
            offset += width + tileGap
        }
        return offset
    }

    /// Find the item index whose left edge is closest to the given scroll offset.
    static func nearestSnapIndex<T: Layoutable>(
        scrollOffset: CGFloat,
        tiles: [T],
        viewportWidth: CGFloat
    ) -> Int {
        guard !tiles.isEmpty else { return 0 }

        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var x: CGFloat = 0

        for (index, tile) in tiles.enumerated() {
            let distance = abs(x - scrollOffset)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
            let width = max(tile.widthSpec.resolve(viewportWidth: viewportWidth), minimumTileWidth)
            x += width + tileGap
        }

        return bestIndex
    }

    /// Maximum allowed scroll offset (right-most scroll position).
    static func maxScrollOffset<T: Layoutable>(
        tiles: [T],
        viewportWidth: CGFloat
    ) -> CGFloat {
        let total = totalContentWidth(tiles: tiles, viewportWidth: viewportWidth)
        return max(total - viewportWidth, 0)
    }

    static let minimumTileWidth: CGFloat = 120.0
}
