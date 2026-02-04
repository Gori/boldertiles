import Foundation

/// Persisted metadata for a Claude tile session.
struct ClaudeMeta: Codable {
    var sessionID: String?
    var autoApprove: Bool

    static func defaultMeta() -> ClaudeMeta {
        ClaudeMeta(sessionID: nil, autoApprove: false)
    }
}
