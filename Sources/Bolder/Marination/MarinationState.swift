import Foundation

/// The 5-phase backbone for idea marination.
enum MarinationPhase: String, Codable, Sendable, CaseIterable {
    case ingest    // Extract core intent, reframe the idea
    case expand    // Generate contrast, force elimination
    case shape     // Define product character, non-goals
    case scope     // Apply constraint pressure, filter features
    case commit    // Testable claims, risky bet, forward path

    /// The next phase in the progression, or nil if at commit.
    var next: MarinationPhase? {
        switch self {
        case .ingest:  return .expand
        case .expand:  return .shape
        case .shape:   return .scope
        case .scope:   return .commit
        case .commit:  return nil
        }
    }
}

/// The outcome of a suggestion after user interaction.
enum SuggestionOutcome: String, Codable, Sendable {
    case accepted
    case rejected
    case expired
}

/// A historical record of a suggestion and its outcome.
struct MarinationEntry: Codable, Sendable {
    let id: UUID
    let suggestion: Suggestion
    let outcome: SuggestionOutcome
    let timestamp: Date

    init(
        id: UUID = UUID(),
        suggestion: Suggestion,
        outcome: SuggestionOutcome,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.suggestion = suggestion
        self.outcome = outcome
        self.timestamp = timestamp
    }
}

/// Per-note marination state, persisted to disk.
struct MarinationState: Codable, Sendable {
    let noteID: UUID
    var suggestions: [Suggestion]
    var history: [MarinationEntry]
    var lastMarinatedAt: Date?
    var marinationCount: Int
    var lastUserEditAt: Date?
    var phase: MarinationPhase
    var phaseRoundCount: Int

    /// Maximum number of history entries to keep.
    static let maxHistoryEntries = 10
    /// Number of recent history entries sent to Claude for context.
    static let historyContextCount = 5

    init(
        noteID: UUID,
        suggestions: [Suggestion] = [],
        history: [MarinationEntry] = [],
        lastMarinatedAt: Date? = nil,
        marinationCount: Int = 0,
        lastUserEditAt: Date? = nil,
        phase: MarinationPhase = .ingest,
        phaseRoundCount: Int = 0
    ) {
        self.noteID = noteID
        self.suggestions = suggestions
        self.history = history
        self.lastMarinatedAt = lastMarinatedAt
        self.marinationCount = marinationCount
        self.lastUserEditAt = lastUserEditAt
        self.phase = phase
        self.phaseRoundCount = phaseRoundCount
    }

    // Backward-compatible decoding
    private enum CodingKeys: String, CodingKey {
        case noteID, suggestions, history, lastMarinatedAt, marinationCount, lastUserEditAt, phase, phaseRoundCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        noteID = try container.decode(UUID.self, forKey: .noteID)
        suggestions = try container.decode([Suggestion].self, forKey: .suggestions)
        history = try container.decode([MarinationEntry].self, forKey: .history)
        lastMarinatedAt = try container.decodeIfPresent(Date.self, forKey: .lastMarinatedAt)
        marinationCount = try container.decode(Int.self, forKey: .marinationCount)
        lastUserEditAt = try container.decodeIfPresent(Date.self, forKey: .lastUserEditAt)
        phase = try container.decodeIfPresent(MarinationPhase.self, forKey: .phase) ?? .ingest
        phaseRoundCount = try container.decodeIfPresent(Int.self, forKey: .phaseRoundCount) ?? 0
    }

    /// Add a history entry, capping at `maxHistoryEntries`.
    mutating func addHistoryEntry(_ entry: MarinationEntry) {
        history.append(entry)
        if history.count > Self.maxHistoryEntries {
            history = Array(history.suffix(Self.maxHistoryEntries))
        }
    }

    /// The most recent history entries for Claude context.
    var recentHistory: [MarinationEntry] {
        Array(history.suffix(Self.historyContextCount))
    }
}
