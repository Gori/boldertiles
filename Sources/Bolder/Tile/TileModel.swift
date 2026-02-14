import Foundation

/// Represents a single tile in the strip.
struct TileModel: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var widthSpec: WidthSpec
    var tileType: TileType
    var color: TileColor

    init(
        id: UUID = UUID(),
        widthSpec: WidthSpec = .proportional(.oneHalf),
        tileType: TileType = .placeholder,
        color: TileColor = .random()
    ) {
        self.id = id
        self.widthSpec = widthSpec
        self.tileType = tileType
        self.color = color
    }

    static func defaultFontSize(for type: TileType) -> CGFloat {
        switch type {
        case .notes:       return 20
        case .terminal:    return 16
        case .features:    return 16
        case .placeholder: return 16
        }
    }
}

enum TileType: String, Codable, Sendable {
    case placeholder
    case notes
    case terminal
    case features

    /// Content margins (top, left, bottom, right) for each tile type.
    var contentInsets: NSEdgeInsets {
        switch self {
        case .notes:       return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        case .terminal:    return NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
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
