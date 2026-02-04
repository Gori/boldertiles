import Foundation

/// Persisted metadata for a terminal tile session.
struct TerminalMeta: Codable {
    var command: String?
    var cwd: String?
    var environment: [String: String]?

    static func defaultMeta() -> TerminalMeta {
        TerminalMeta(
            command: nil, // uses default shell
            cwd: nil,     // uses project directory
            environment: nil
        )
    }
}
