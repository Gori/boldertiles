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

    init(
        id: UUID = UUID(),
        phase: IdeaPhase = .note,
        widthSpec: WidthSpec = .proportional(.oneHalf),
        color: TileColor = .random(),
        createdAt: Date = Date(),
        claudeSessionID: String? = nil,
        marinationPhase: MarinationPhase = .ingest,
        noteStatus: NoteStatus = .idle
    ) {
        self.id = id
        self.phase = phase
        self.widthSpec = widthSpec
        self.color = color
        self.createdAt = createdAt
        self.claudeSessionID = claudeSessionID
        self.marinationPhase = marinationPhase
        self.noteStatus = noteStatus
    }

    /// Default font size for idea tiles (same as notes).
    static let defaultFontSize: CGFloat = 14
}
