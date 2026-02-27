import Foundation

/// The view mode for the workspace.
enum ViewMode: String, Codable, Sendable {
    case strip
    case build
    case kanban
}

/// The top-level data model, replacing StripModel.
/// Contains all ideas and terminals, view state, and font sizes.
final class WorkspaceModel: Codable {
    var items: [StripItem]
    var focusedIndex: Int
    var scrollOffset: CGFloat
    var needsInitialScroll: Bool = false
    var viewMode: ViewMode
    var selectedBuildIdeaID: UUID?
    var fontSizes: [String: CGFloat]

    init(
        items: [StripItem] = [],
        focusedIndex: Int = 0,
        scrollOffset: CGFloat = 0,
        viewMode: ViewMode = .strip,
        selectedBuildIdeaID: UUID? = nil,
        fontSizes: [String: CGFloat] = [:]
    ) {
        self.items = items
        self.focusedIndex = focusedIndex
        self.scrollOffset = scrollOffset
        self.viewMode = viewMode
        self.selectedBuildIdeaID = selectedBuildIdeaID
        self.fontSizes = fontSizes
    }

    // MARK: - Codable (scrollOffset not persisted)

    enum CodingKeys: String, CodingKey {
        case items, focusedIndex, viewMode, selectedBuildIdeaID, fontSizes
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([StripItem].self, forKey: .items)
        focusedIndex = try container.decode(Int.self, forKey: .focusedIndex)
        viewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .strip
        selectedBuildIdeaID = try container.decodeIfPresent(UUID.self, forKey: .selectedBuildIdeaID)
        fontSizes = (try? container.decode([String: CGFloat].self, forKey: .fontSizes)) ?? [:]
        scrollOffset = 0
        needsInitialScroll = true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(focusedIndex, forKey: .focusedIndex)
        try container.encode(viewMode, forKey: .viewMode)
        try container.encode(selectedBuildIdeaID, forKey: .selectedBuildIdeaID)
        try container.encode(fontSizes, forKey: .fontSizes)
    }

    // MARK: - Derived accessors

    /// All ideas in the workspace.
    var ideas: [IdeaModel] {
        items.compactMap {
            if case .idea(let idea) = $0 { return idea }
            return nil
        }
    }

    /// Look up an idea by ID.
    func idea(for id: UUID) -> IdeaModel? {
        ideas.first { $0.id == id }
    }

    /// Mutate an idea in-place by ID.
    @discardableResult
    func mutateIdea(_ id: UUID, _ transform: (inout IdeaModel) -> Void) -> Bool {
        guard let index = items.firstIndex(where: {
            if case .idea(let idea) = $0 { return idea.id == id }
            return false
        }) else { return false }

        if case .idea(var idea) = items[index] {
            transform(&idea)
            items[index] = .idea(idea)
            return true
        }
        return false
    }

    /// The currently focused item, if valid.
    var focusedItem: StripItem? {
        guard focusedIndex >= 0, focusedIndex < items.count else { return nil }
        return items[focusedIndex]
    }

    /// Font size for a view category, with defaults.
    func fontSize(for category: ViewCategory) -> CGFloat {
        switch category {
        case .idea:
            return fontSizes["idea"] ?? IdeaModel.defaultFontSize
        case .terminal:
            return fontSizes["terminal"] ?? 16
        }
    }

    /// Default workspace with a single idea.
    static func defaultModel() -> WorkspaceModel {
        let idea = IdeaModel()
        return WorkspaceModel(items: [.idea(idea)], focusedIndex: 0)
    }
}
