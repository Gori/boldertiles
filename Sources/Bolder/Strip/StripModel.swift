import Foundation

/// The data model for the horizontal strip of tiles.
final class StripModel: Codable {
    var tiles: [TileModel]
    var focusedIndex: Int
    var scrollOffset: CGFloat
    var needsInitialScroll: Bool = false
    /// Per-tile-type font sizes (keyed by TileType raw value).
    var fontSizes: [String: CGFloat]

    init(tiles: [TileModel], focusedIndex: Int = 0, scrollOffset: CGFloat = 0) {
        self.tiles = tiles
        self.focusedIndex = focusedIndex
        self.scrollOffset = scrollOffset
        self.fontSizes = [:]
    }

    /// Returns the font size for a tile type, falling back to the default.
    func fontSize(for type: TileType) -> CGFloat {
        fontSizes[type.rawValue] ?? TileModel.defaultFontSize(for: type)
    }

    /// Default set of tiles for first launch.
    static func defaultModel() -> StripModel {
        let tiles = [TileModel(widthSpec: .proportional(.oneHalf))]
        return StripModel(tiles: tiles, focusedIndex: 0, scrollOffset: 0)
    }

    // Codable — scrollOffset is not persisted (always starts at snap position)
    enum CodingKeys: String, CodingKey {
        case tiles, focusedIndex, fontSizes
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tiles = try container.decode([TileModel].self, forKey: .tiles)
        focusedIndex = try container.decode(Int.self, forKey: .focusedIndex)
        fontSizes = (try? container.decode([String: CGFloat].self, forKey: .fontSizes)) ?? [:]
        scrollOffset = 0
        needsInitialScroll = true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tiles, forKey: .tiles)
        try container.encode(focusedIndex, forKey: .focusedIndex)
        try container.encode(fontSizes, forKey: .fontSizes)
    }
}
