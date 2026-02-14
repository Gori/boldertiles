import AppKit

/// NSScrollView subclass that only handles vertical scrolling.
/// Horizontal scroll gestures pass through to the superview (StripView)
/// so strip-level trackpad scrolling works over notes tiles.
private final class VerticalScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // If the gesture is primarily horizontal, forward to the strip
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            nextResponder?.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }
}

/// A tile containing a plain-text/Markdown editor using NSTextView (TextKit 2).
final class NotesTileView: NSView, TileContentView, NSTextViewDelegate {
    private static let backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

    private let scrollView = VerticalScrollView()
    private let textView = NSTextView()
    private let debugOverlay = TileDebugOverlay()
    private let projectStore: ProjectStore
    private var tileID: UUID?
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.3
    private var isDirty = false
    private var refineSession: RefineSession?
    private var refineOverlay: RefineOverlayView?
    private var featureExtractor: FeatureExtractor?

    init(frame frameRect: NSRect, projectStore: ProjectStore) {
        self.projectStore = projectStore
        super.init(frame: frameRect)
        wantsLayer = true
        setupTextView()
        debugOverlay.install(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupTextView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Self.backgroundColor
        scrollView.borderType = .noBorder

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        let insets = TileType.notes.contentInsets
        textView.textContainerInset = NSSize(width: insets.left, height: insets.top)
        textView.backgroundColor = Self.backgroundColor
        textView.insertionPointColor = NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        textView.font = FontLoader.jetBrainsMono(size: 20)
        textView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        textView.delegate = self

        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, // will be set by widthTracksTextView
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        scrollView.frame = bounds
        addSubview(scrollView)

        // Context menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refine with Claude", action: #selector(contextRefine), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Save as Feature", action: #selector(contextSaveAsFeature), keyEquivalent: ""))
        textView.menu = menu
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        tileID = tile.id
        let content = projectStore.loadNoteContent(for: tile.id)
        let scrollPosition = scrollView.contentView.bounds.origin
        textView.string = content ?? ""
        scrollView.contentView.scroll(to: scrollPosition)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        isDirty = false
        debugOverlay.setLines(["notes"])
    }

    func activate() {
        textView.isEditable = true
    }

    func throttle() {
        textView.isEditable = true
    }

    func suspend() {
        flushPendingSave()
        textView.isEditable = false
    }

    func resetForReuse() {
        flushPendingSave()
        textView.string = ""
        textView.undoManager?.removeAllActions()
        tileID = nil
        isDirty = false
    }

    func setFontSize(_ size: CGFloat) {
        textView.font = FontLoader.jetBrainsMono(size: size)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        isDirty = true
        scheduleSave()
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
        let content = textView.string
        projectStore.saveNoteContent(content, for: tileID)
        isDirty = false
    }

    /// The inner text view, for first-responder routing.
    var innerTextView: NSTextView { textView }

    /// Whether a refine overlay is active and needs input focus.
    var isRefineActive: Bool { refineOverlay != nil }

    /// The overlay's answer field, for first-responder routing during refine.
    var refineAnswerField: NSTextView? {
        guard let overlay = refineOverlay, overlay.isWaitingForInput else { return nil }
        return overlay.answerField
    }

    // MARK: - Context menu actions

    @objc private func contextRefine(_ sender: Any?) {
        startRefine(projectURL: projectStore.projectURL)
    }

    @objc private func contextSaveAsFeature(_ sender: Any?) {
        saveAsFeature(projectURL: projectStore.projectURL, completion: nil)
    }

    // MARK: - Refine

    func startRefine(projectURL: URL) {
        guard refineSession == nil else { return }
        let noteText = textView.string
        guard !noteText.isEmpty else { return }

        let session = RefineSession(projectURL: projectURL)
        self.refineSession = session

        let overlay = RefineOverlayView(frame: bounds)
        overlay.autoresizingMask = [.width, .height]
        self.refineOverlay = overlay
        addSubview(overlay)

        overlay.onCancel = { [weak self] in
            self?.dismissRefine()
        }

        overlay.onReject = { [weak self] in
            self?.dismissRefine()
        }

        overlay.onAccept = { [weak self] refinedText in
            self?.textView.string = refinedText
            self?.isDirty = true
            self?.scheduleSave()
            self?.dismissRefine()
        }

        overlay.onSubmitAnswers = { [weak self] answers in
            guard let self else { return }
            self.refineSession?.submitAnswers(answers, originalNoteText: noteText)
        }

        session.onStateChange = { [weak self, weak overlay] state in
            guard let overlay else { return }
            switch state {
            case .idle, .askingQuestions:
                break
            case .waitingForAnswers(let questions):
                overlay.showQuestions(questions)
            case .refining:
                overlay.showRefining(streamingText: self?.refineSession?.streamingText ?? "")
            case .complete(let refinedText):
                overlay.showComplete(refinedText: refinedText)
            case .failed(let msg):
                print("[NotesTileView] Refine failed: \(msg)")
                self?.dismissRefine()
            }
        }

        session.start(noteText: noteText)
    }

    private func dismissRefine() {
        refineSession?.cancel()
        refineSession = nil
        refineOverlay?.removeFromSuperview()
        refineOverlay = nil
        window?.makeFirstResponder(textView)
    }

    // MARK: - Save as Feature

    func saveAsFeature(projectURL: URL, completion: ((Feature?) -> Void)?) {
        guard featureExtractor == nil else { return }
        let noteText = textView.string
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
}
