import AppKit
import WebKit

/// A tile containing a Markdown editor using WKWebView (React + CodeMirror 6).
final class NotesTileView: NSView, TileContentView {
    private static let backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

    private let notesWebView: NotesWebView
    private let debugOverlay = TileDebugOverlay()
    private let projectStore: ProjectStore
    private weak var marinationEngine: MarinationEngine?
    private let statusIndicator = NoteStatusIndicator(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    private var tileID: UUID?
    private var currentPhase: MarinationPhase = .ingest
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.3
    private var isDirty = false
    private var featureExtractor: FeatureExtractor?
    private var cachedContent: String = ""
    private var hasPendingSuggestions = false
    private var webViewReady = false
    private var pendingContent: String?
    private var pendingSuggestions: [Suggestion]?

    init(frame frameRect: NSRect, projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine
        self.notesWebView = NotesWebView(frame: CGRect(origin: .zero, size: frameRect.size))
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Self.backgroundColor.cgColor
        setupWebView()
        setupStatusIndicator()
        setupContextMenu()
        setupNotificationObservers()
        debugOverlay.install(in: self)

        notesWebView.loadUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupWebView() {
        notesWebView.autoresizingMask = [.width, .height]
        notesWebView.frame = bounds
        addSubview(notesWebView)

        notesWebView.onAction = { [weak self] action in
            self?.handleBridgeAction(action)
        }
    }

    private func setupStatusIndicator() {
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusIndicator)

        NSLayoutConstraint.activate([
            statusIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            statusIndicator.widthAnchor.constraint(equalToConstant: 80),
            statusIndicator.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    private func setupContextMenu() {
        notesWebView.extraMenuItems = [
            NSMenuItem(title: "Start Marinating", action: #selector(contextToggleMarination), keyEquivalent: ""),
            NSMenuItem(title: "Save as Feature", action: #selector(contextSaveAsFeature), keyEquivalent: ""),
        ]
        // Set targets so the responder chain finds us
        for item in notesWebView.extraMenuItems {
            item.target = self
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStatusChanged(_:)),
            name: .marinationStatusChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSuggestionsUpdated(_:)),
            name: .marinationSuggestionsUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhaseChanged(_:)),
            name: .marinationPhaseChanged,
            object: nil
        )
    }

    // MARK: - Bridge action handling

    private func handleBridgeAction(_ action: NotesBridge.BridgeAction) {
        print("[NotesTileView] handleBridgeAction: \(action)")
        switch action {
        case .contentChanged(let text):
            cachedContent = text
            isDirty = true
            scheduleSave()
            if let tileID {
                marinationEngine?.noteDidEdit(tileID)
            }

        case .suggestionAccepted(let id):
            guard let tileID else { return }
            marinationEngine?.acceptSuggestion(id, for: tileID)
            notesWebView.removeSuggestion(id: id)
            updateHasPendingSuggestions()
            isDirty = true
            scheduleSave()

        case .suggestionRejected(let id):
            guard let tileID else { return }
            marinationEngine?.rejectSuggestion(id, for: tileID)
            notesWebView.removeSuggestion(id: id)
            updateHasPendingSuggestions()

        case .choiceSelected(let id, let index):
            guard let tileID else { return }
            // Insert the chosen text — the bridge will send a contentChanged after
            if let state = projectStore.loadMarinationState(for: tileID),
               let suggestion = state.suggestions.first(where: { $0.id == id }),
               case .question(_, let choices) = suggestion.content,
               index >= 0, index < choices.count {
                marinationEngine?.acceptSuggestion(id, for: tileID)
            }
            notesWebView.removeSuggestion(id: id)
            updateHasPendingSuggestions()

        case .response(let id, _):
            guard let tileID else { return }
            marinationEngine?.acceptSuggestion(id, for: tileID)
            notesWebView.removeSuggestion(id: id)
            updateHasPendingSuggestions()

        case .keyCommand(let key):
            handleKeyCommand(key)

        case .ready:
            print("[NotesTileView] ready! pendingContent=\(pendingContent?.count ?? -1), pendingSuggestions=\(pendingSuggestions?.count ?? -1)")
            webViewReady = true
            // Flush any content/suggestions that arrived before the web view loaded
            if let content = pendingContent {
                print("[NotesTileView] flushing pendingContent (\(content.count) chars)")
                notesWebView.setContent(content)
                pendingContent = nil
            }
            if let suggestions = pendingSuggestions {
                print("[NotesTileView] flushing pendingSuggestions (\(suggestions.count))")
                notesWebView.displaySuggestions(suggestions)
                pendingSuggestions = nil
            }
        }
    }

    private func handleKeyCommand(_ key: String) {
        guard hasPendingSuggestions, let tileID else { return }
        guard let state = projectStore.loadMarinationState(for: tileID) else { return }
        let pending = state.suggestions.filter { $0.state == .pending }
        guard let topSuggestion = pending.first else { return }

        switch key {
        case "tab":
            marinationEngine?.acceptSuggestion(topSuggestion.id, for: tileID)
            notesWebView.removeSuggestion(id: topSuggestion.id)
            updateHasPendingSuggestions()
            isDirty = true
            scheduleSave()
        case "escape":
            marinationEngine?.rejectSuggestion(topSuggestion.id, for: tileID)
            notesWebView.removeSuggestion(id: topSuggestion.id)
            updateHasPendingSuggestions()
        default:
            break
        }
    }

    private func updateHasPendingSuggestions() {
        guard let tileID else {
            hasPendingSuggestions = false
            return
        }
        if let state = projectStore.loadMarinationState(for: tileID) {
            hasPendingSuggestions = state.suggestions.contains { $0.state == .pending }
        } else {
            hasPendingSuggestions = false
        }
    }

    // MARK: - Notification handlers

    @objc private func handleStatusChanged(_ notification: Notification) {
        guard let noteID = notification.userInfo?["noteID"] as? UUID,
              noteID == tileID,
              let statusRaw = notification.userInfo?["status"] as? String,
              let status = NoteStatus(rawValue: statusRaw) else { return }
        let phase = notification.userInfo?["phase"] as? MarinationPhase ?? currentPhase
        currentPhase = phase
        statusIndicator.update(status: status, phase: phase)
    }

    @objc private func handlePhaseChanged(_ notification: Notification) {
        guard let noteID = notification.userInfo?["noteID"] as? UUID,
              noteID == tileID,
              let phaseRaw = notification.userInfo?["phase"] as? String,
              let phase = MarinationPhase(rawValue: phaseRaw) else { return }
        currentPhase = phase
        let status: NoteStatus = statusIndicator.isHidden ? .idle : .active
        statusIndicator.update(status: status, phase: phase)
    }

    @objc private func handleSuggestionsUpdated(_ notification: Notification) {
        guard let noteID = notification.userInfo?["noteID"] as? UUID,
              noteID == tileID else { return }

        let suggestions: [Suggestion]
        if let s = notification.userInfo?["suggestions"] as? [Suggestion] {
            suggestions = s
        } else if let state = projectStore.loadMarinationState(for: noteID) {
            suggestions = state.suggestions
        } else {
            return
        }

        let pending = suggestions.filter { $0.state == .pending }
        hasPendingSuggestions = !pending.isEmpty
        print("[NotesTileView] Received \(suggestions.count) suggestions (\(pending.count) pending) for tile \(noteID)")

        if webViewReady {
            notesWebView.displaySuggestions(suggestions)
        } else {
            pendingSuggestions = suggestions
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        notesWebView.frame = bounds
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        tileID = tile.id
        currentPhase = tile.marinationPhase
        let content = projectStore.loadNoteContent(for: tile.id) ?? ""
        cachedContent = content
        isDirty = false
        statusIndicator.update(status: tile.noteStatus, phase: tile.marinationPhase)
        debugOverlay.setLines(["notes"])
        print("[NotesTileView] configure: tile=\(tile.id), webViewReady=\(webViewReady), content=\(content.count) chars")

        if webViewReady {
            notesWebView.setContent(content)
            notesWebView.clearSuggestions()
        } else {
            pendingContent = content
            print("[NotesTileView] configure: queued pendingContent (\(content.count) chars)")
        }

        // Re-display pending suggestions from marination state
        if let state = projectStore.loadMarinationState(for: tile.id) {
            let pending = state.suggestions.filter { $0.state == .pending }
            hasPendingSuggestions = !pending.isEmpty
            if !pending.isEmpty {
                if webViewReady {
                    notesWebView.displaySuggestions(state.suggestions)
                } else {
                    pendingSuggestions = state.suggestions
                }
            }
        }
    }

    func activate() {
        notesWebView.setEditable(true)
    }

    func throttle() {
        notesWebView.setEditable(true)
    }

    func suspend() {
        flushPendingSave()
        notesWebView.setEditable(false)
    }

    func resetForReuse() {
        flushPendingSave()
        if webViewReady {
            notesWebView.setContent("")
            notesWebView.clearSuggestions()
        }
        tileID = nil
        currentPhase = .ingest
        isDirty = false
        hasPendingSuggestions = false
        cachedContent = ""
        statusIndicator.update(status: .idle, phase: .ingest)
    }

    func setFontSize(_ size: CGFloat) {
        notesWebView.setFontSize(size)
    }

    // MARK: - Debounced save

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounce, execute: item)
    }

    private func flushPendingSave() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        performSave()
    }

    private func performSave() {
        guard isDirty else { return }
        guard let tileID else {
            print("[NotesTileView] Warning: attempted save with no tileID")
            return
        }
        projectStore.saveNoteContent(cachedContent, for: tileID)
        isDirty = false
    }

    /// The inner web view, for first-responder routing.
    var innerWebView: WKWebView { notesWebView.webView }

    // MARK: - Marination

    func toggleMarination() {
        guard let tileID else { return }
        guard let engine = marinationEngine else { return }

        if statusIndicator.isHidden {
            engine.activateNote(tileID)
        } else {
            engine.deactivateNote(tileID)
        }
    }

    // MARK: - Context menu actions

    @objc private func contextToggleMarination(_ sender: Any?) {
        toggleMarination()
    }

    @objc private func contextSaveAsFeature(_ sender: Any?) {
        saveAsFeature(projectURL: projectStore.projectURL, completion: nil)
    }

    // MARK: - Save as Feature

    func saveAsFeature(projectURL: URL, completion: ((Feature?) -> Void)?) {
        guard featureExtractor == nil else { return }
        let noteText = cachedContent
        guard !noteText.isEmpty, let noteID = tileID else {
            completion?(nil)
            return
        }

        let extractor = FeatureExtractor(projectURL: projectURL)
        self.featureExtractor = extractor

        extractor.onComplete = { [weak self] feature in
            self?.featureExtractor = nil
            completion?(feature)
        }

        extractor.extract(noteText: noteText, noteID: noteID)
    }

    // MARK: - Key handling for suggestions

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if hasPendingSuggestions {
            if event.keyCode == KeyBinding.specialKeyCodes["tab"]! {
                handleKeyCommand("tab")
                return true
            }
            if event.keyCode == KeyBinding.specialKeyCodes["escape"]! {
                handleKeyCommand("escape")
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
