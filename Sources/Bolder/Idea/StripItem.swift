import Foundation

/// Metadata for a standalone terminal tile in the strip.
struct TerminalItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var widthSpec: WidthSpec
    var color: TileColor

    init(
        id: UUID = UUID(),
        widthSpec: WidthSpec = .proportional(.oneHalf),
        color: TileColor = .random()
    ) {
        self.id = id
        self.widthSpec = widthSpec
        self.color = color
    }
}

/// A single item in the horizontal strip — either an idea or a standalone terminal.
enum StripItem: Codable, Identifiable, Equatable, Sendable {
    case idea(IdeaModel)
    case terminal(TerminalItem)

    var id: UUID {
        switch self {
        case .idea(let idea): return idea.id
        case .terminal(let term): return term.id
        }
    }

    var widthSpec: WidthSpec {
        get {
            switch self {
            case .idea(let idea): return idea.widthSpec
            case .terminal(let term): return term.widthSpec
            }
        }
        set {
            switch self {
            case .idea(var idea):
                idea.widthSpec = newValue
                self = .idea(idea)
            case .terminal(var term):
                term.widthSpec = newValue
                self = .terminal(term)
            }
        }
    }

    var color: TileColor {
        switch self {
        case .idea(let idea): return idea.color
        case .terminal(let term): return term.color
        }
    }

    /// Whether this item needs its session kept alive when cold (terminals and build-phase ideas).
    var keepAliveWhenCold: Bool {
        switch self {
        case .terminal: return true
        case .idea(let idea): return idea.phase == .build
        }
    }
}

/// Categories for view pooling — replaces TileType-based pool keys.
enum ViewCategory: Hashable {
    case idea
    case terminal
}
