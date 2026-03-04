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

    // Center: placeholder shown when Claude hasn't been started
    private let startBuildPlaceholder = NSView()
    private let startBuildButton = NSButton()

    // Right: collapsible note panel
    private var notePanel: NotesTileView?
    private var notePanelVisible = true

    private let sidebarWidth: CGFloat = 250
    private let notePanelWidth: CGFloat = 350
    private let dividerWidth: CGFloat = 1

    /// Callback for mode-switch requests (handled by WorkspaceView).
    var onSwitchMode: ((ViewMode) -> Void)?
    /// Callback to trigger a build for the given idea (loads notes, composes prompt).
    var onBuildIdea: ((UUID) -> Void)?

    init(frame frameRect: NSRect, model: WorkspaceModel, projectStore: ProjectStore) {
        self.model = model
        self.projectStore = projectStore
        self.sidebar = BuildSidebarView(frame: .zero)

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)

        setupSidebar()
        setupDividers()
        setupStartBuildPlaceholder()

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

    private func setupStartBuildPlaceholder() {
        startBuildPlaceholder.wantsLayer = true
        startBuildPlaceholder.isHidden = true
        addSubview(startBuildPlaceholder)

        let label = NSTextField(labelWithString: "Ready to build")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.4)
        label.translatesAutoresizingMaskIntoConstraints = false
        startBuildPlaceholder.addSubview(label)

        let shortcutLabel = NSTextField(labelWithString: "\u{2318}B to start")
        shortcutLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        shortcutLabel.textColor = NSColor.white.withAlphaComponent(0.25)
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        startBuildPlaceholder.addSubview(shortcutLabel)

        let greenColor = NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        startBuildButton.attributedTitle = NSAttributedString(
            string: "\u{25B6}  Start Build",
            attributes: [
                .foregroundColor: greenColor,
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            ]
        )
        startBuildButton.bezelStyle = .rounded
        startBuildButton.isBordered = false
        startBuildButton.wantsLayer = true
        startBuildButton.layer?.cornerRadius = 8
        startBuildButton.layer?.backgroundColor = CGColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.12)
        startBuildButton.translatesAutoresizingMaskIntoConstraints = false
        startBuildButton.target = self
        startBuildButton.action = #selector(startBuildClicked)
        startBuildPlaceholder.addSubview(startBuildButton)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: startBuildPlaceholder.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: startBuildPlaceholder.centerYAnchor, constant: -40),

            startBuildButton.centerXAnchor.constraint(equalTo: startBuildPlaceholder.centerXAnchor),
            startBuildButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            startBuildButton.widthAnchor.constraint(equalToConstant: 160),
            startBuildButton.heightAnchor.constraint(equalToConstant: 40),

            shortcutLabel.centerXAnchor.constraint(equalTo: startBuildPlaceholder.centerXAnchor),
            shortcutLabel.topAnchor.constraint(equalTo: startBuildButton.bottomAnchor, constant: 12),
        ])
    }

    @objc private func startBuildClicked() {
        guard let id = model.selectedBuildIdeaID else { return }
        onBuildIdea?(id)
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
        let centerFrame = CGRect(x: centerX, y: 0, width: centerW, height: h)
        activeClaudeView?.frame = centerFrame
        startBuildPlaceholder.frame = centerFrame

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

    /// Select an idea and pass an initial prompt to Claude Code for new sessions.
    func selectIdeaWithPrompt(_ id: UUID, prompt: String) {
        model.selectedBuildIdeaID = id
        projectStore.saveWorkspace(model)

        showClaudeView(for: id, initialPrompt: prompt)
        showNotePanel(for: id)

        let buildIdeas = model.ideas.filter { $0.phase == .build }
        sidebar.reload(
            ideas: buildIdeas,
            noteContentLoader: { [weak self] id in
                self?.projectStore.loadNoteContent(for: id)
            },
            selectedID: id
        )
    }

    private func showClaudeView(for ideaID: UUID, initialPrompt: String? = nil) {
        // Hide current
        activeClaudeView?.isHidden = true

        // Reuse or create
        let cv: ClaudeTileView
        if let existing = claudeViews[ideaID] {
            cv = existing
            NSLog("[BuildView] showClaudeView: reusing cached view for \(ideaID), isConfigured=\(cv.isConfigured)")
        } else {
            cv = ClaudeTileView(frame: .zero, projectStore: projectStore)
            addSubview(cv)
            claudeViews[ideaID] = cv
            NSLog("[BuildView] showClaudeView: created new view for \(ideaID)")
        }

        // Configure the surface if not yet started and we have a reason to start
        if !cv.isConfigured, let idea = model.idea(for: ideaID) {
            let hasPrompt = initialPrompt != nil
            let isBuilding = idea.buildStatus == .building
            NSLog("[BuildView] showClaudeView: not configured, hasPrompt=\(hasPrompt), isBuilding=\(isBuilding)")
            if hasPrompt || isBuilding {
                if let prompt = initialPrompt {
                    cv.initialPrompt = prompt
                }
                let tile = TileModel(
                    id: idea.id,
                    widthSpec: idea.widthSpec,
                    tileType: .claude,
                    color: idea.color
                )
                cv.configure(with: tile)
            }
        }

        // Show either the running terminal or the "Start Build" placeholder
        if cv.isConfigured {
            cv.isHidden = false
            startBuildPlaceholder.isHidden = true
        } else {
            cv.isHidden = true
            startBuildPlaceholder.isHidden = false
        }

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

        // Cmd+B starts build for the selected idea
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "b" {
            if let id = model.selectedBuildIdeaID {
                onBuildIdea?(id)
            }
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
        if let cv = activeClaudeView, cv.isConfigured {
            window?.makeFirstResponder(cv.innerSurfaceView)
        }
    }

    // MARK: - Cleanup

    func suspendAll() {
        // Don't destroy claude views — sessions must stay alive
        notePanel?.suspend()
    }
}
