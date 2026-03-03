import Foundation

/// Represents a single idea — the primary entity in the workspace.
/// An idea starts as a note and gains a Claude Code session when it reaches the Build phase.
struct IdeaModel: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var phase: IdeaPhase
    var widthSpec: WidthSpec
    var color: TileColor
    var createdAt: Date
    var claudeSessionID: String?
    var marinationPhase: MarinationPhase
    var noteStatus: NoteStatus
    var buildStatus: BuildStatus

    init(
        id: UUID = UUID(),
        phase: IdeaPhase = .note,
        widthSpec: WidthSpec = .proportional(.oneHalf),
        color: TileColor = .random(),
        createdAt: Date = Date(),
        claudeSessionID: String? = nil,
        marinationPhase: MarinationPhase = .ingest,
        noteStatus: NoteStatus = .idle,
        buildStatus: BuildStatus = .idle
    ) {
        self.id = id
        self.phase = phase
        self.widthSpec = widthSpec
        self.color = color
        self.createdAt = createdAt
        self.claudeSessionID = claudeSessionID
        self.marinationPhase = marinationPhase
        self.noteStatus = noteStatus
        self.buildStatus = buildStatus
    }

    // MARK: - Codable (buildStatus defaults to .idle for existing data)

    enum CodingKeys: String, CodingKey {
        case id, phase, widthSpec, color, createdAt, claudeSessionID
        case marinationPhase, noteStatus, buildStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        phase = try container.decode(IdeaPhase.self, forKey: .phase)
        widthSpec = try container.decode(WidthSpec.self, forKey: .widthSpec)
        color = try container.decode(TileColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        claudeSessionID = try container.decodeIfPresent(String.self, forKey: .claudeSessionID)
        marinationPhase = try container.decode(MarinationPhase.self, forKey: .marinationPhase)
        noteStatus = try container.decode(NoteStatus.self, forKey: .noteStatus)
        buildStatus = try container.decodeIfPresent(BuildStatus.self, forKey: .buildStatus) ?? .idle
    }

    /// Default font size for idea tiles (same as notes).
    static let defaultFontSize: CGFloat = 14
}
