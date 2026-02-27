import AppKit
import WebKit

/// A composite tile that adapts its content based on the idea's phase.
/// - Note phase: shows notes editor, marination disabled
/// - Plan phase: shows notes editor, marination enabled
/// - Build phase: shows notes or Claude Code (toggled via Cmd+.)
/// - Done phase: shows notes editor, dimmed
final class IdeaTileView: NSView, TileContentView {
    private let notesView: NotesTileView
    private var claudeView: ClaudeTileView?
    private var showingClaude = false
    private var currentIdea: IdeaModel?
    private let projectStore: ProjectStore
    private weak var marinationEngine: MarinationEngine?

    init(frame frameRect: NSRect, projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine
        self.notesView = NotesTileView(frame: CGRect(origin: .zero, size: frameRect.size),
                                        projectStore: projectStore,
                                        marinationEngine: marinationEngine)
        super.init(frame: frameRect)
        wantsLayer = true

        notesView.autoresizingMask = [.width, .height]
        notesView.frame = bounds
        addSubview(notesView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        // Legacy — convert to idea
        let idea = IdeaModel(
            id: tile.id,
            phase: .note,
            widthSpec: tile.widthSpec,
            color: tile.color,
            marinationPhase: tile.marinationPhase,
            noteStatus: tile.noteStatus
        )
        configureWithIdea(idea)
    }

    func configureWithItem(_ item: StripItem) {
        guard case .idea(let idea) = item else { return }
        configureWithIdea(idea)
    }

    private func configureWithIdea(_ idea: IdeaModel) {
        currentIdea = idea
        notesView.configure(with: TileModel(
            id: idea.id,
            widthSpec: idea.widthSpec,
            tileType: .notes,
            color: idea.color,
            noteStatus: idea.noteStatus,
            marinationPhase: idea.marinationPhase
        ))

        updatePhaseDisplay()

        // In Build phase, set up Claude view if we have a session
        if idea.phase == .build && claudeView == nil {
            setupClaudeView(for: idea)
        }

        // Show appropriate view
        if idea.phase == .build && showingClaude {
            showClaudeView()
        } else {
            showNotesView()
        }
    }

    private func updatePhaseDisplay() {
        guard let idea = currentIdea else { return }

        switch idea.phase {
        case .note:
            alphaValue = 1.0
        case .plan:
            alphaValue = 1.0
        case .build:
            alphaValue = 1.0
        case .done:
            alphaValue = 0.6
        }
    }

    private func setupClaudeView(for idea: IdeaModel) {
        guard claudeView == nil else { return }
        let cv = ClaudeTileView(frame: bounds, projectStore: projectStore)
        cv.autoresizingMask = [.width, .height]
        cv.frame = bounds
        cv.isHidden = true
        addSubview(cv)
        self.claudeView = cv

        // Configure with the idea's session
        let tile = TileModel(
            id: idea.id,
            widthSpec: idea.widthSpec,
            tileType: .claude,
            color: idea.color
        )
        cv.configure(with: tile)
    }

    private func showNotesView() {
        showingClaude = false
        notesView.isHidden = false
        claudeView?.isHidden = true
    }

    private func showClaudeView() {
        guard let idea = currentIdea, idea.phase == .build else { return }
        if claudeView == nil {
            setupClaudeView(for: idea)
        }
        showingClaude = true
        notesView.isHidden = true
        claudeView?.isHidden = false
    }

    func activate() {
        if showingClaude {
            claudeView?.activate()
        } else {
            notesView.activate()
        }
    }

    func throttle() {
        notesView.throttle()
        claudeView?.throttle()
    }

    func suspend() {
        notesView.suspend()
        claudeView?.suspend()
    }

    func resetForReuse() {
        notesView.resetForReuse()
        showingClaude = false
        currentIdea = nil
        alphaValue = 1.0
        // Don't reset claude view — it keeps session alive
    }

    func setFontSize(_ size: CGFloat) {
        notesView.setFontSize(size)
        claudeView?.setFontSize(size)
    }

    // MARK: - Toggle note/claude in Build phase

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+. toggles between note and claude in Build phase
        if let idea = currentIdea, idea.phase == .build,
           event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "." {
            if showingClaude {
                showNotesView()
            } else {
                showClaudeView()
            }
            makeInnerFirstResponder(in: window)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - First responder routing

    func makeInnerFirstResponder(in window: NSWindow?) {
        if showingClaude, let cv = claudeView {
            window?.makeFirstResponder(cv.innerSurfaceView)
        } else {
            window?.makeFirstResponder(notesView.innerWebView)
        }
    }

    // MARK: - Marination

    func toggleMarination() {
        notesView.toggleMarination()
    }

    // MARK: - Phase change notification

    func phaseDidChange(_ newPhase: IdeaPhase) {
        currentIdea?.phase = newPhase
        updatePhaseDisplay()

        if newPhase == .build && claudeView == nil, let idea = currentIdea {
            setupClaudeView(for: idea)
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        notesView.frame = bounds
        claudeView?.frame = bounds
    }
}
