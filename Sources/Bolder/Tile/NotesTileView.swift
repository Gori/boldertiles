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
    private let scrollView = VerticalScrollView()
    private let textView = NSTextView()
    private let debugOverlay = TileDebugOverlay()
    private let projectStore: ProjectStore
    private var tileID: UUID?
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.3

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
        scrollView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
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
        textView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
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
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        tileID = tile.id
        let content = projectStore.loadNoteContent(for: tile.id)
        textView.string = content ?? ""
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
    }

    func setFontSize(_ size: CGFloat) {
        textView.font = FontLoader.jetBrainsMono(size: size)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
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
        guard let tileID else { return }
        let content = textView.string
        projectStore.saveNoteContent(content, for: tileID)
    }

    /// The inner text view, for first-responder routing.
    var innerTextView: NSTextView { textView }
}
