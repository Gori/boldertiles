import Foundation

/// Marination status for notes tiles.
enum NoteStatus: String, Codable, Sendable {
    case idle
    case active
    case waiting
}

/// Represents a single tile in the strip.
struct TileModel: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var widthSpec: WidthSpec
    var tileType: TileType
    var color: TileColor
    var noteStatus: NoteStatus
    var marinationPhase: MarinationPhase

    init(
        id: UUID = UUID(),
        widthSpec: WidthSpec = .proportional(.oneHalf),
        tileType: TileType = .placeholder,
        color: TileColor = .random(),
        noteStatus: NoteStatus = .idle,
        marinationPhase: MarinationPhase = .ingest
    ) {
        self.id = id
        self.widthSpec = widthSpec
        self.tileType = tileType
        self.color = color
        self.noteStatus = noteStatus
        self.marinationPhase = marinationPhase
    }

    // Custom Codable to handle existing tiles.json files without noteStatus/marinationPhase
    private enum CodingKeys: String, CodingKey {
        case id, widthSpec, tileType, color, noteStatus, marinationPhase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        widthSpec = try container.decode(WidthSpec.self, forKey: .widthSpec)
        tileType = try container.decode(TileType.self, forKey: .tileType)
        color = try container.decode(TileColor.self, forKey: .color)
        noteStatus = try container.decodeIfPresent(NoteStatus.self, forKey: .noteStatus) ?? .idle
        marinationPhase = try container.decodeIfPresent(MarinationPhase.self, forKey: .marinationPhase) ?? .ingest
    }

    static func defaultFontSize(for type: TileType) -> CGFloat {
        switch type {
        case .notes:       return 14
        case .terminal:    return 16
        case .claude:      return 16
        case .features:    return 16
        case .placeholder: return 16
        }
    }
}

enum TileType: String, Codable, Sendable {
    case placeholder
    case notes
    case terminal
    case claude
    case features

    /// Content margins (top, left, bottom, right) for each tile type.
    var contentInsets: NSEdgeInsets {
        switch self {
        case .notes:       return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        case .terminal:    return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        case .claude:      return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        case .features:    return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        case .placeholder: return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        }
    }
}

/// A simple RGB color for placeholder tiles, Codable for persistence.
struct TileColor: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    static func random() -> TileColor {
        // Muted, pleasant colors
        let hue = Double.random(in: 0...1)
        let sat = Double.random(in: 0.3...0.6)
        let bri = Double.random(in: 0.4...0.7)
        let (r, g, b) = hsbToRGB(h: hue, s: sat, b: bri)
        return TileColor(red: r, green: g, blue: b)
    }

    private static func hsbToRGB(h: Double, s: Double, b: Double) -> (Double, Double, Double) {
        let c = b * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        let (r, g, bl): (Double, Double, Double)
        switch Int(h * 6) % 6 {
        case 0: (r, g, bl) = (c, x, 0)
        case 1: (r, g, bl) = (x, c, 0)
        case 2: (r, g, bl) = (0, c, x)
        case 3: (r, g, bl) = (0, x, c)
        case 4: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }
        return (r + m, g + m, bl + m)
    }
}
