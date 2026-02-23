import Foundation

/// The category of a suggestion produced by marination.
enum SuggestionType: String, Codable, Sendable {
    case rewrite
    case append
    case insert
    case compression
    case question
    case critique
    case promote
    case advancePhase
}

/// Severity level for critique suggestions.
enum CritiqueSeverity: String, Codable, Sendable {
    case strong
    case weak
    case cut
    case rethink
}

/// The state of a suggestion in its lifecycle.
enum SuggestionState: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
    case expired
}

/// The content payload of a suggestion, varying by type.
enum SuggestionContent: Codable, Equatable, Sendable {
    case rewrite(original: String, replacement: String, contextBefore: String, contextAfter: String)
    case append(text: String)
    case insert(text: String, afterContext: String)
    case compression(original: String, replacement: String, contextBefore: String, contextAfter: String)
    case question(text: String, choices: [String])
    case critique(severity: CritiqueSeverity, targetText: String, critiqueText: String, contextBefore: String, contextAfter: String)
    case promote(title: String, description: String)
    case advancePhase(nextPhase: String, reasoning: String)

    // MARK: - Manual Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case original, replacement, contextBefore, contextAfter
        case text, afterContext
        case choices
        case severity, targetText, critiqueText
        case title, description
        case nextPhase, reasoning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "rewrite":
            self = .rewrite(
                original: try container.decode(String.self, forKey: .original),
                replacement: try container.decode(String.self, forKey: .replacement),
                contextBefore: try container.decode(String.self, forKey: .contextBefore),
                contextAfter: try container.decode(String.self, forKey: .contextAfter)
            )
        case "append":
            self = .append(text: try container.decode(String.self, forKey: .text))
        case "insert":
            self = .insert(
                text: try container.decode(String.self, forKey: .text),
                afterContext: try container.decode(String.self, forKey: .afterContext)
            )
        case "compression":
            self = .compression(
                original: try container.decode(String.self, forKey: .original),
                replacement: try container.decode(String.self, forKey: .replacement),
                contextBefore: try container.decode(String.self, forKey: .contextBefore),
                contextAfter: try container.decode(String.self, forKey: .contextAfter)
            )
        case "question":
            let choices = try container.decodeIfPresent([String].self, forKey: .choices) ?? []
            self = .question(text: try container.decode(String.self, forKey: .text), choices: choices)
        case "critique":
            let severityStr = try container.decode(String.self, forKey: .severity)
            guard let severity = CritiqueSeverity(rawValue: severityStr) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unknown critique severity: \(severityStr)")
                )
            }
            self = .critique(
                severity: severity,
                targetText: try container.decode(String.self, forKey: .targetText),
                critiqueText: try container.decode(String.self, forKey: .critiqueText),
                contextBefore: try container.decodeIfPresent(String.self, forKey: .contextBefore) ?? "",
                contextAfter: try container.decodeIfPresent(String.self, forKey: .contextAfter) ?? ""
            )
        case "promote":
            self = .promote(
                title: try container.decode(String.self, forKey: .title),
                description: try container.decode(String.self, forKey: .description)
            )
        case "advancePhase":
            self = .advancePhase(
                nextPhase: try container.decode(String.self, forKey: .nextPhase),
                reasoning: try container.decodeIfPresent(String.self, forKey: .reasoning) ?? ""
            )
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unknown suggestion content type: \(type)")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .rewrite(let original, let replacement, let contextBefore, let contextAfter):
            try container.encode("rewrite", forKey: .type)
            try container.encode(original, forKey: .original)
            try container.encode(replacement, forKey: .replacement)
            try container.encode(contextBefore, forKey: .contextBefore)
            try container.encode(contextAfter, forKey: .contextAfter)
        case .append(let text):
            try container.encode("append", forKey: .type)
            try container.encode(text, forKey: .text)
        case .insert(let text, let afterContext):
            try container.encode("insert", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(afterContext, forKey: .afterContext)
        case .compression(let original, let replacement, let contextBefore, let contextAfter):
            try container.encode("compression", forKey: .type)
            try container.encode(original, forKey: .original)
            try container.encode(replacement, forKey: .replacement)
            try container.encode(contextBefore, forKey: .contextBefore)
            try container.encode(contextAfter, forKey: .contextAfter)
        case .question(let text, let choices):
            try container.encode("question", forKey: .type)
            try container.encode(text, forKey: .text)
            if !choices.isEmpty {
                try container.encode(choices, forKey: .choices)
            }
        case .critique(let severity, let targetText, let critiqueText, let contextBefore, let contextAfter):
            try container.encode("critique", forKey: .type)
            try container.encode(severity.rawValue, forKey: .severity)
            try container.encode(targetText, forKey: .targetText)
            try container.encode(critiqueText, forKey: .critiqueText)
            try container.encode(contextBefore, forKey: .contextBefore)
            try container.encode(contextAfter, forKey: .contextAfter)
        case .promote(let title, let description):
            try container.encode("promote", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
        case .advancePhase(let nextPhase, let reasoning):
            try container.encode("advancePhase", forKey: .type)
            try container.encode(nextPhase, forKey: .nextPhase)
            try container.encode(reasoning, forKey: .reasoning)
        }
    }
}

/// A single suggestion produced by the marination system.
struct Suggestion: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let type: SuggestionType
    let content: SuggestionContent
    let reasoning: String
    let createdAt: Date
    var state: SuggestionState

    init(
        id: UUID = UUID(),
        type: SuggestionType,
        content: SuggestionContent,
        reasoning: String,
        createdAt: Date = Date(),
        state: SuggestionState = .pending
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.reasoning = reasoning
        self.createdAt = createdAt
        self.state = state
    }
}
