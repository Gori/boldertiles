import AppKit

/// Top-level content view for the window. Owns Strip, Build, and Kanban views.
/// Only one view mode is visible at a time. Handles mode-switching keyboard shortcuts.
final class WorkspaceView: NSView {
    private let model: WorkspaceModel
    private let projectStore: ProjectStore
    private weak var marinationEngine: MarinationEngine?

    private let stripView: StripView
    private var buildView: BuildView?
    private var kanbanView: KanbanView?
    private let transitionOverlay = ModeTransitionOverlay()

    init(model: WorkspaceModel, projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.model = model
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine
        self.stripView = StripView(model: model, projectStore: projectStore, marinationEngine: marinationEngine)

        super.init(frame: .zero)
        wantsLayer = true

        stripView.autoresizingMask = [.width, .height]
        addSubview(stripView)

        stripView.onSwitchMode = { [weak self] mode in
            self?.switchMode(to: mode)
        }

        // Apply initial view mode
        switchMode(to: model.viewMode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func layout() {
        super.layout()
        stripView.frame = bounds
        buildView?.frame = bounds
        kanbanView?.frame = bounds
    }

    // MARK: - Mode switching

    func switchMode(to mode: ViewMode) {
        model.viewMode = mode

        stripView.isHidden = mode != .strip
        buildView?.isHidden = mode != .build
        kanbanView?.isHidden = mode != .kanban

        switch mode {
        case .strip:
            stripView.isHidden = false
            window?.makeFirstResponder(stripView)
            stripView.updateFirstResponder()
        case .build:
            ensureBuildView()
            buildView?.isHidden = false
            buildView?.reload()
            buildView?.makeClaudeFirstResponder(in: window)
        case .kanban:
            ensureKanbanView()
            kanbanView?.isHidden = false
            kanbanView?.reload()
        }

        projectStore.saveWorkspace(model)
        transitionOverlay.show(mode: mode, in: self)
    }

    private func ensureBuildView() {
        guard buildView == nil else { return }
        let bv = BuildView(frame: bounds, model: model, projectStore: projectStore)
        bv.autoresizingMask = [.width, .height]
        bv.onSwitchMode = { [weak self] mode in
            self?.switchMode(to: mode)
        }
        addSubview(bv)
        self.buildView = bv
    }

    private func ensureKanbanView() {
        guard kanbanView == nil else { return }
        let kv = KanbanView(frame: bounds, model: model, projectStore: projectStore, marinationEngine: marinationEngine)
        kv.autoresizingMask = [.width, .height]
        kv.onSwitchMode = { [weak self] mode in
            self?.switchMode(to: mode)
        }
        addSubview(kv)
        self.kanbanView = kv
    }

    /// The inner strip view, for menu action routing.
    var innerStripView: StripView { stripView }
}
