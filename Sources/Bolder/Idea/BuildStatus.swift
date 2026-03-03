import Foundation

/// Tracks whether an idea is actively being built by Claude Code.
enum BuildStatus: String, Codable, Sendable {
    case idle
    case building
}
