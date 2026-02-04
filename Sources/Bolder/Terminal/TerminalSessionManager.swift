import Foundation

/// Tracks which tile IDs have active terminal sessions.
/// The actual ghostty_surface_t is owned by TerminalSurfaceView.
/// This manager exists so we know whether to create a new surface
/// when a view is recycled back to a tile.
final class TerminalSessionManager {
    static let shared = TerminalSessionManager()

    private var activeTileIDs = Set<UUID>()

    private init() {}

    func markActive(_ tileID: UUID) {
        activeTileIDs.insert(tileID)
    }

    func markInactive(_ tileID: UUID) {
        activeTileIDs.remove(tileID)
    }

    func hasSession(for tileID: UUID) -> Bool {
        activeTileIDs.contains(tileID)
    }

    func destroyAll() {
        activeTileIDs.removeAll()
    }
}
