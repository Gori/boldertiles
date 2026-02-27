import Foundation

/// The lifecycle phase of an idea.
enum IdeaPhase: String, Codable, Sendable, CaseIterable {
    case note    // Free writing, no AI
    case plan    // Structured suggestions via marination
    case build   // Claude Code session active
    case done    // Complete, read-only appearance
}
