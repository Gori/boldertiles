import AppKit

/// Kanban board view with four columns (Note, Plan, Build, Done).
/// Ideas can be dragged between columns to change their phase.
final class KanbanView: NSView {
    private let model: WorkspaceModel
    private let projectStore: ProjectStore
    private weak var marinationEngine: MarinationEngine?

    private let columns: [KanbanColumnView]
    private let columnSpacing: CGFloat = 12
    private let edgePadding: CGFloat = 20

    /// Callback for mode-switch requests.
    var onSwitchMode: ((ViewMode) -> Void)?
    /// Callback when user clicks a card to navigate to it in strip mode.
    var onNavigateToIdea: ((UUID) -> Void)?

    init(frame frameRect: NSRect, model: WorkspaceModel, projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.model = model
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine

        self.columns = IdeaPhase.allCases.map { KanbanColumnView(phase: $0) }

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1.0)

        for column in columns {
            column.translatesAutoresizingMaskIntoConstraints = false
            addSubview(column)

            column.onDropIdea = { [weak self] ideaID, targetPhase in
                self?.moveIdea(ideaID, to: targetPhase)
            }
            column.onClickIdea = { [weak self] ideaID in
                self?.navigateToIdea(ideaID)
            }
        }

        setupColumnConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupColumnConstraints() {
        guard columns.count == 4 else { return }

        for (i, column) in columns.enumerated() {
            NSLayoutConstraint.activate([
                column.topAnchor.constraint(equalTo: topAnchor, constant: edgePadding),
                column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -edgePadding),
            ])

            if i == 0 {
                column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edgePadding).isActive = true
            } else {
                column.leadingAnchor.constraint(equalTo: columns[i - 1].trailingAnchor, constant: columnSpacing).isActive = true
            }

            // Equal widths
            if i > 0 {
                column.widthAnchor.constraint(equalTo: columns[0].widthAnchor).isActive = true
            }
        }

        // Last column trails to edge
        columns.last?.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -edgePadding).isActive = true
    }

    // MARK: - Data loading

    func reload() {
        let ideas = model.ideas
        let loader: (UUID) -> String? = { [weak self] id in
            self?.projectStore.loadNoteContent(for: id)
        }

        for column in columns {
            let filtered = ideas.filter { $0.phase == column.phase }
            column.reload(ideas: filtered, noteContentLoader: loader)
        }
    }

    // MARK: - Phase changes via drag-and-drop

    private func moveIdea(_ ideaID: UUID, to targetPhase: IdeaPhase) {
        guard let idea = model.idea(for: ideaID), idea.phase != targetPhase else { return }

        let oldPhase = idea.phase
        model.mutateIdea(ideaID) { $0.phase = targetPhase }
        projectStore.saveWorkspace(model)

        // Activate/deactivate marination as needed
        if targetPhase == .plan && oldPhase != .plan {
            marinationEngine?.activateNote(ideaID)
        } else if oldPhase == .plan && targetPhase != .plan {
            marinationEngine?.deactivateNote(ideaID)
        }

        reload()
    }

    private func navigateToIdea(_ ideaID: UUID) {
        // Find index in model.items
        if let index = model.items.firstIndex(where: { $0.id == ideaID }) {
            model.focusedIndex = index
            onSwitchMode?(.strip)
        }
    }

    // MARK: - Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        for (action, binding) in SettingsManager.shared.shortcuts {
            if binding.matches(event) {
                switch action {
                case .switchToStrip:  onSwitchMode?(.strip); return true
                case .switchToBuild:  onSwitchMode?(.build); return true
                case .switchToKanban: return true // already in kanban
                default: break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
