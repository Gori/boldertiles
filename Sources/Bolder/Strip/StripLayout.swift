import Foundation

/// The computed frame for a single tile.
struct TileFrame: Equatable {
    let index: Int
    let tileID: UUID
    let frame: CGRect
}

/// Pure function: given tiles, viewport size, and scroll offset, produce pixel-snapped tile frames.
enum StripLayout {
    static let tileGap: CGFloat = 0.0
    static let tileMargin: CGFloat = 4.0

    /// Compute tile frames for the strip.
    /// - Parameters:
    ///   - tiles: The tile models.
    ///   - viewportSize: The visible viewport size (width x height).
    ///   - scrollOffset: Current horizontal scroll offset (positive = scrolled right).
    ///   - scale: Display scale factor for pixel snapping.
    /// - Returns: Array of TileFrames in order.
    static func layout(
        tiles: [TileModel],
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

    /// Total content width for all tiles.
    static func totalContentWidth(
        tiles: [TileModel],
        viewportWidth: CGFloat
    ) -> CGFloat {
        guard !tiles.isEmpty else { return 0 }
        let widths = tiles.map { max($0.widthSpec.resolve(viewportWidth: viewportWidth), minimumTileWidth) }
        return widths.reduce(0, +) + CGFloat(tiles.count - 1) * tileGap
    }

    /// The scroll offset that left-aligns the tile at the given index.
    static func snapOffset(
        forTileAt index: Int,
        tiles: [TileModel],
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

    /// Find the tile index whose left edge is closest to the given scroll offset.
    static func nearestSnapIndex(
        scrollOffset: CGFloat,
        tiles: [TileModel],
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
    static func maxScrollOffset(
        tiles: [TileModel],
        viewportWidth: CGFloat
    ) -> CGFloat {
        let total = totalContentWidth(tiles: tiles, viewportWidth: viewportWidth)
        return max(total - viewportWidth, 0)
    }

    static let minimumTileWidth: CGFloat = 120.0
}
