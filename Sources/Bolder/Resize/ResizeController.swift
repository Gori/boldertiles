import Foundation

/// Identifies a resize handle as the right edge of a tile.
struct ResizeHandle: Equatable {
    /// The index of the tile whose right edge is being dragged.
    let tileIndex: Int
}

/// Manages drag-to-resize logic. Dragging a handle resizes only the tile to its left;
/// everything to the right shifts naturally.
final class ResizeController {
    private let model: StripModel
    private let handleHitZone: CGFloat = 8.0

    private var activeHandle: ResizeHandle?
    private var dragStartX: CGFloat = 0
    private var startWidth: CGFloat = 0

    init(model: StripModel) {
        self.model = model
    }

    /// Hit-test for a resize handle at the given point.
    /// Checks the right edge of every tile (gaps between tiles and the trailing edge of the last tile).
    func hitTestHandle(at point: CGPoint, frames: [TileFrame]) -> ResizeHandle? {
        for i in 0..<frames.count {
            let rightEdge: CGFloat
            if i < frames.count - 1 {
                rightEdge = frames[i].frame.maxX + StripLayout.tileGap / 2.0
            } else {
                rightEdge = frames[i].frame.maxX
            }
            if abs(point.x - rightEdge) <= handleHitZone {
                return ResizeHandle(tileIndex: i)
            }
        }
        return nil
    }

    /// Begin a resize operation. Returns true if a handle was hit.
    func beginResize(at point: CGPoint, frames: [TileFrame], viewportWidth: CGFloat) -> Bool {
        guard let handle = hitTestHandle(at: point, frames: frames) else {
            return false
        }
        activeHandle = handle
        dragStartX = point.x
        startWidth = model.tiles[handle.tileIndex].widthSpec.resolve(viewportWidth: viewportWidth)
        return true
    }

    /// Continue an active resize drag. Returns true if width changed.
    func continueResize(at point: CGPoint, viewportWidth: CGFloat) -> Bool {
        guard let handle = activeHandle else { return false }

        let delta = point.x - dragStartX
        let newWidth = max(startWidth + delta, StripLayout.minimumTileWidth)
        model.tiles[handle.tileIndex].widthSpec = .fixed(newWidth)
        return true
    }

    /// End the resize operation. Returns true if a resize was active.
    func endResize(viewportWidth: CGFloat) -> Bool {
        guard let handle = activeHandle else { return false }

        // Snap to nearest proportional preset if within tolerance
        model.tiles[handle.tileIndex].widthSpec =
            model.tiles[handle.tileIndex].widthSpec.snappedToPreset(viewportWidth: viewportWidth)

        activeHandle = nil
        return true
    }

    /// Resize the focused tile by a delta amount. Used for keyboard resize.
    func resizeFocused(delta: CGFloat, viewportWidth: CGFloat) {
        let index = model.focusedIndex
        guard index >= 0, index < model.tiles.count else { return }

        let currentWidth = model.tiles[index].widthSpec.resolve(viewportWidth: viewportWidth)
        let newWidth = max(currentWidth + delta, StripLayout.minimumTileWidth)
        model.tiles[index].widthSpec = .fixed(newWidth)
    }

    var isResizing: Bool {
        activeHandle != nil
    }
}
