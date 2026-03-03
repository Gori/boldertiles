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
    /// Callback to trigger a build with note context for an idea.
    var onBuildIdea: ((UUID) -> Void)?

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
                self?.selectCard(byID: ideaID)
            }
            column.onDoubleClickIdea = { [weak self] ideaID in
                self?.selectCard(byID: ideaID)
                self?.enterSelectedCard()
            }
            column.onBuildIdea = { [weak self] ideaID in
                self?.buildIdea(ideaID)
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
        // Remember which idea was selected so we can restore after rebuild
        let previousID: UUID? = selectedRow >= 0 ? columns[selectedColumn].cardID(at: selectedRow) : nil

        let ideas = model.ideas
        let loader: (UUID) -> String? = { [weak self] id in
            self?.projectStore.loadNoteContent(for: id)
        }

        for column in columns {
            let filtered = ideas.filter { $0.phase == column.phase }
            column.reload(ideas: filtered, noteContentLoader: loader)
        }

        // Restore selection by ID (card may have moved columns)
        if let id = previousID {
            restoreSelection(for: id)
        }
        updateSelectionVisuals()
    }

    /// Find a card by ID across all columns and select it.
    private func restoreSelection(for ideaID: UUID) {
        for (colIdx, column) in columns.enumerated() {
            for row in 0..<column.cardCount {
                if column.cardID(at: row) == ideaID {
                    selectedColumn = colIdx
                    selectedRow = row
                    return
                }
            }
        }
        // Card was deleted — clamp selection
        selectedRow = min(selectedRow, max(0, columns[selectedColumn].cardCount - 1))
        if columns[selectedColumn].cardCount == 0 { selectedRow = -1 }
    }

    /// Select a card by its idea ID (used by click handler).
    private func selectCard(byID ideaID: UUID) {
        for (colIdx, column) in columns.enumerated() {
            for row in 0..<column.cardCount {
                if column.cardID(at: row) == ideaID {
                    selectedColumn = colIdx
                    selectedRow = row
                    updateSelectionVisuals()
                    return
                }
            }
        }
    }

    // MARK: - Selection state

    private var selectedColumn: Int = 0
    private var selectedRow: Int = -1 // -1 = no selection

    /// Update visual selection highlight across all columns.
    private func updateSelectionVisuals() {
        for (colIdx, column) in columns.enumerated() {
            column.setSelectedCard(at: colIdx == selectedColumn ? selectedRow : nil)
        }
    }

    /// Select first card when entering kanban or after reload if nothing is selected.
    func selectInitialCardIfNeeded() {
        guard selectedRow < 0 else { return }
        // Find first non-empty column
        for (colIdx, column) in columns.enumerated() {
            if column.cardCount > 0 {
                selectedColumn = colIdx
                selectedRow = 0
                updateSelectionVisuals()
                column.scrollToCard(at: 0)
                return
            }
        }
    }

    // MARK: - Phase changes via drag-and-drop

    private func moveIdea(_ ideaID: UUID, to targetPhase: IdeaPhase) {
        guard let idea = model.idea(for: ideaID), idea.phase != targetPhase else { return }

        let oldPhase = idea.phase
        model.mutateIdea(ideaID) {
            $0.phase = targetPhase
            if oldPhase == .build && targetPhase != .build {
                $0.buildStatus = .idle
            }
        }
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

    private func buildIdea(_ ideaID: UUID) {
        guard let idea = model.idea(for: ideaID), idea.phase == .build else { return }
        model.mutateIdea(ideaID) { $0.buildStatus = .building }
        projectStore.saveWorkspace(model)
        reload()
        onBuildIdea?(ideaID)
    }

    private func addNewIdea() {
        let newItem = StripItem.idea(IdeaModel())
        model.items.append(newItem)
        model.focusedIndex = model.items.count - 1
        projectStore.saveWorkspace(model)
        onSwitchMode?(.strip)
    }

    private func enterSelectedCard() {
        guard selectedRow >= 0,
              let ideaID = columns[selectedColumn].cardID(at: selectedRow),
              let idea = model.idea(for: ideaID) else { return }

        switch idea.phase {
        case .note, .plan:
            navigateToIdea(ideaID)
        case .build:
            if let index = model.items.firstIndex(where: { $0.id == ideaID }) {
                model.focusedIndex = index
                model.selectedBuildIdeaID = ideaID
            }
            onSwitchMode?(.build)
        case .done:
            break
        }
    }

    private func moveSelectedCard(direction: Int) {
        guard selectedRow >= 0,
              let ideaID = columns[selectedColumn].cardID(at: selectedRow) else { return }

        let phases = IdeaPhase.allCases
        let currentPhaseIndex = selectedColumn
        let targetPhaseIndex = currentPhaseIndex + direction
        guard targetPhaseIndex >= 0, targetPhaseIndex < phases.count else { return }

        let targetPhase = phases[targetPhaseIndex]
        let targetColumn = columns[targetPhaseIndex]

        moveIdea(ideaID, to: targetPhase)

        // After reload, select the moved card in its new column
        selectedColumn = targetPhaseIndex
        // Card lands at end of target column
        selectedRow = max(0, targetColumn.cardCount - 1)
        updateSelectionVisuals()
        columns[selectedColumn].scrollToCard(at: selectedRow)
    }

    // MARK: - Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Configurable shortcuts
        for (action, binding) in SettingsManager.shared.shortcuts {
            if binding.matches(event) {
                switch action {
                case .switchToStrip:  onSwitchMode?(.strip); return true
                case .switchToBuild:  onSwitchMode?(.build); return true
                case .switchToKanban: return true // already in kanban
                case .addIdea:        addNewIdea(); return true
                default: break
                }
            }
        }

        // Cmd+B — build selected card
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "b" {
            if selectedRow >= 0,
               let ideaID = columns[selectedColumn].cardID(at: selectedRow),
               let idea = model.idea(for: ideaID),
               idea.phase == .build {
                buildIdea(ideaID)
                return true
            }
        }

        // Strip .function and .numericPad — arrow keys always carry these implicitly
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])
        let noModifiers = flags.isEmpty
        let optionOnly = flags == .option

        switch event.keyCode {
        // Up arrow
        case 126 where noModifiers:
            if selectedRow < 0 {
                selectInitialCardIfNeeded()
            } else if selectedRow > 0 {
                selectedRow -= 1
                updateSelectionVisuals()
                columns[selectedColumn].scrollToCard(at: selectedRow)
            }
            return true

        // Down arrow
        case 125 where noModifiers:
            if selectedRow < 0 {
                selectInitialCardIfNeeded()
            } else if selectedRow < columns[selectedColumn].cardCount - 1 {
                selectedRow += 1
                updateSelectionVisuals()
                columns[selectedColumn].scrollToCard(at: selectedRow)
            }
            return true

        // Left arrow (navigate columns)
        case 123 where noModifiers:
            if selectedRow < 0 {
                selectInitialCardIfNeeded()
            } else if selectedColumn > 0 {
                selectedColumn -= 1
                selectedRow = min(selectedRow, max(0, columns[selectedColumn].cardCount - 1))
                if columns[selectedColumn].cardCount == 0 { selectedRow = -1 }
                updateSelectionVisuals()
                if selectedRow >= 0 { columns[selectedColumn].scrollToCard(at: selectedRow) }
            }
            return true

        // Right arrow (navigate columns)
        case 124 where noModifiers:
            if selectedRow < 0 {
                selectInitialCardIfNeeded()
            } else if selectedColumn < columns.count - 1 {
                selectedColumn += 1
                selectedRow = min(selectedRow, max(0, columns[selectedColumn].cardCount - 1))
                if columns[selectedColumn].cardCount == 0 { selectedRow = -1 }
                updateSelectionVisuals()
                if selectedRow >= 0 { columns[selectedColumn].scrollToCard(at: selectedRow) }
            }
            return true

        // Option+Left — move card one phase left
        case 123 where optionOnly:
            moveSelectedCard(direction: -1)
            return true

        // Option+Right — move card one phase right
        case 124 where optionOnly:
            moveSelectedCard(direction: 1)
            return true

        // Return/Enter — open selected card
        case 36 where noModifiers:
            enterSelectedCard()
            return true

        default:
            break
        }

        return super.performKeyEquivalent(with: event)
    }
}
