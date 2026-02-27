import AppKit

/// Build mode view: left sidebar (idea list) + center Claude Code + right note panel.
final class BuildView: NSView {
    private let model: WorkspaceModel
    private let projectStore: ProjectStore

    private let sidebar: BuildSidebarView
    private let dividerLeft = CALayer()
    private let dividerRight = CALayer()

    // Center: Claude Code terminal per idea
    private var claudeViews: [UUID: ClaudeTileView] = [:]
    private var activeClaudeView: ClaudeTileView?

    // Right: collapsible note panel
    private var notePanel: NotesTileView?
    private var notePanelVisible = true

    private let sidebarWidth: CGFloat = 250
    private let notePanelWidth: CGFloat = 350
    private let dividerWidth: CGFloat = 1

    /// Callback for mode-switch requests (handled by WorkspaceView).
    var onSwitchMode: ((ViewMode) -> Void)?

    init(frame frameRect: NSRect, model: WorkspaceModel, projectStore: ProjectStore) {
        self.model = model
        self.projectStore = projectStore
        self.sidebar = BuildSidebarView(frame: .zero)

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)

        setupSidebar()
        setupDividers()

        sidebar.onSelectIdea = { [weak self] id in
            self?.selectIdea(id)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupSidebar() {
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebar)

        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: sidebarWidth),
        ])
    }

    private func setupDividers() {
        dividerLeft.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        dividerRight.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        layer?.addSublayer(dividerLeft)
        layer?.addSublayer(dividerRight)
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        let h = bounds.height
        let notePanelW = notePanelVisible ? notePanelWidth : 0

        // Divider left of center
        dividerLeft.frame = CGRect(x: sidebarWidth, y: 0, width: dividerWidth, height: h)

        // Center area
        let centerX = sidebarWidth + dividerWidth
        let centerW = max(0, bounds.width - sidebarWidth - dividerWidth - notePanelW - (notePanelVisible ? dividerWidth : 0))
        activeClaudeView?.frame = CGRect(x: centerX, y: 0, width: centerW, height: h)

        // Divider right of center (before note panel)
        if notePanelVisible {
            dividerRight.isHidden = false
            dividerRight.frame = CGRect(x: centerX + centerW, y: 0, width: dividerWidth, height: h)
            notePanel?.frame = CGRect(x: centerX + centerW + dividerWidth, y: 0, width: notePanelW, height: h)
        } else {
            dividerRight.isHidden = true
        }
    }

    // MARK: - Data loading

    /// Called when entering Build mode. Loads the sidebar and selects an idea.
    func reload() {
        let buildIdeas = model.ideas.filter { $0.phase == .build }

        sidebar.reload(
            ideas: buildIdeas,
            noteContentLoader: { [weak self] id in
                self?.projectStore.loadNoteContent(for: id)
            },
            selectedID: model.selectedBuildIdeaID
        )

        // Auto-select first build idea if none selected
        if model.selectedBuildIdeaID == nil || !buildIdeas.contains(where: { $0.id == model.selectedBuildIdeaID }) {
            if let first = buildIdeas.first {
                selectIdea(first.id)
            }
        } else if let selectedID = model.selectedBuildIdeaID {
            selectIdea(selectedID)
        }
    }

    // MARK: - Idea selection

    private func selectIdea(_ id: UUID) {
        model.selectedBuildIdeaID = id
        projectStore.saveWorkspace(model)

        showClaudeView(for: id)
        showNotePanel(for: id)

        // Reload sidebar to update selection
        let buildIdeas = model.ideas.filter { $0.phase == .build }
        sidebar.reload(
            ideas: buildIdeas,
            noteContentLoader: { [weak self] id in
                self?.projectStore.loadNoteContent(for: id)
            },
            selectedID: id
        )
    }

    private func showClaudeView(for ideaID: UUID) {
        // Hide current
        activeClaudeView?.isHidden = true

        // Reuse or create
        let cv: ClaudeTileView
        if let existing = claudeViews[ideaID] {
            cv = existing
        } else {
            cv = ClaudeTileView(frame: .zero, projectStore: projectStore)
            addSubview(cv)
            claudeViews[ideaID] = cv

            // Configure with a TileModel matching the idea
            if let idea = model.idea(for: ideaID) {
                let tile = TileModel(
                    id: idea.id,
                    widthSpec: idea.widthSpec,
                    tileType: .claude,
                    color: idea.color
                )
                cv.configure(with: tile)
            }
        }

        cv.isHidden = false
        activeClaudeView = cv
        needsLayout = true
    }

    private func showNotePanel(for ideaID: UUID) {
        if notePanel == nil {
            let np = NotesTileView(
                frame: .zero,
                projectStore: projectStore,
                marinationEngine: nil
            )
            addSubview(np)
            self.notePanel = np
        }

        guard let idea = model.idea(for: ideaID) else { return }
        notePanel?.configure(with: TileModel(
            id: idea.id,
            widthSpec: idea.widthSpec,
            tileType: .notes,
            color: idea.color,
            noteStatus: idea.noteStatus,
            marinationPhase: idea.marinationPhase
        ))
        notePanel?.activate()
        notePanel?.isHidden = !notePanelVisible
        needsLayout = true
    }

    // MARK: - Toggle note panel

    func toggleNotePanel() {
        notePanelVisible.toggle()
        notePanel?.isHidden = !notePanelVisible
        needsLayout = true
    }

    // MARK: - Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+. toggles note panel
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "." {
            toggleNotePanel()
            return true
        }

        // Mode switching shortcuts
        for (action, binding) in SettingsManager.shared.shortcuts {
            if binding.matches(event) {
                switch action {
                case .switchToStrip:  onSwitchMode?(.strip); return true
                case .switchToBuild:  return true // already in build
                case .switchToKanban: onSwitchMode?(.kanban); return true
                default: break
                }
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - First responder

    func makeClaudeFirstResponder(in window: NSWindow?) {
        if let cv = activeClaudeView {
            window?.makeFirstResponder(cv.innerSurfaceView)
        }
    }

    // MARK: - Cleanup

    func suspendAll() {
        // Don't destroy claude views — sessions must stay alive
        notePanel?.suspend()
    }
}
