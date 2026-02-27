import AppKit
import QuartzCore

/// The main compositor view that hosts the horizontal strip of tiles.
final class StripView: NSView {
    private let model: WorkspaceModel
    private let snapAnimator = SnapAnimator()
    private let resizeController: ResizeController
    private let virtualizationEngine: VirtualizationEngine
    private let projectStore: ProjectStore
    private let frameMetrics = FrameMetrics()
    private weak var marinationEngine: MarinationEngine?

    // Tile container layers keyed by tile ID
    private var tileLayers: [UUID: CALayer] = [:]
    // Focus highlight layer
    private let focusLayer = CALayer()

    private var trackingArea: NSTrackingArea?

    // Swipe gesture state: accumulate deltaX, commit ±1 tile when threshold crossed
    private var swipeAccumulator: CGFloat = 0
    private var swipeCommitted = false

    /// Callback for mode-switch requests (handled by WorkspaceView).
    var onSwitchMode: ((ViewMode) -> Void)?

    init(model: WorkspaceModel, projectStore: ProjectStore, marinationEngine: MarinationEngine? = nil) {
        self.model = model
        self.projectStore = projectStore
        self.marinationEngine = marinationEngine
        self.resizeController = ResizeController(model: model)
        let factory = DefaultTileViewFactory(projectStore: projectStore, marinationEngine: marinationEngine)
        self.virtualizationEngine = VirtualizationEngine(poolSize: 7, factory: factory)

        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)

        setupFocusLayer()
        setupSnapAnimator()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Setup

    private func setupFocusLayer() {
        focusLayer.borderColor = CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8)
        focusLayer.borderWidth = 2.0
        focusLayer.cornerRadius = 4.0
        focusLayer.zPosition = 100
        focusLayer.isHidden = true
    }

    private func setupSnapAnimator() {
        snapAnimator.onUpdate = { [weak self] offset in
            guard let self else { return }
            self.model.scrollOffset = offset
            self.updateLayout()
        }
        snapAnimator.onComplete = { [weak self] in
            guard let self else { return }
            self.projectStore.saveWorkspace(self.model)
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        if model.needsInitialScroll {
            model.needsInitialScroll = false
            let target = StripLayout.snapOffset(
                forTileAt: model.focusedIndex,
                tiles: model.items,
                viewportWidth: bounds.width
            )
            let maxOffset = StripLayout.maxScrollOffset(tiles: model.items, viewportWidth: bounds.width)
            model.scrollOffset = min(target, maxOffset)
        }
        updateLayout()
        updateTrackingArea()
    }

    private func updateLayout() {
        let frames = StripLayout.layout(
            tiles: model.items,
            viewportSize: bounds.size,
            scrollOffset: model.scrollOffset,
            scale: window?.backingScaleFactor ?? 2.0
        )

        frameMetrics.beginLayout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        syncTileLayers(with: frames)
        virtualizationEngine.update(
            frames: frames,
            viewportWidth: bounds.width,
            items: model.items,
            containerView: self,
            fontSizeForCategory: { [weak self] category in
                self?.model.fontSize(for: category) ?? (category == .idea ? 14 : 16)
            }
        )
        updateFocusHighlight(frames: frames)

        CATransaction.commit()

        frameMetrics.endLayout()
    }

    private func syncTileLayers(with frames: [TileFrame]) {
        let currentIDs = Set(frames.map { $0.tileID })

        // Remove layers for tiles no longer present
        for (id, layer) in tileLayers where !currentIDs.contains(id) {
            layer.removeFromSuperlayer()
            tileLayers.removeValue(forKey: id)
        }

        // Add/update layers
        for tf in frames {
            let layer: CALayer
            if let existing = tileLayers[tf.tileID] {
                layer = existing
            } else {
                layer = CALayer()
                layer.cornerRadius = 4.0
                layer.masksToBounds = true
                self.layer?.addSublayer(layer)
                tileLayers[tf.tileID] = layer
            }

            // During animation, use position instead of frame to avoid layout churn
            if snapAnimator.isAnimating {
                if layer.bounds.size != tf.frame.size {
                    layer.bounds = CGRect(origin: .zero, size: tf.frame.size)
                }
                layer.position = CGPoint(
                    x: tf.frame.midX,
                    y: tf.frame.midY
                )
            } else {
                layer.frame = tf.frame
            }
        }
    }

    private func updateFocusHighlight(frames: [TileFrame]) {
        guard model.focusedIndex >= 0, model.focusedIndex < frames.count else {
            focusLayer.isHidden = true
            return
        }

        let focusFrame = frames[model.focusedIndex].frame.insetBy(dx: -1, dy: -1)
        focusLayer.frame = focusFrame
        focusLayer.isHidden = false

        if focusLayer.superlayer == nil {
            layer?.addSublayer(focusLayer)
        }
    }

    // MARK: - Scrolling (discrete swipe gesture)

    /// Threshold in points of accumulated horizontal delta to trigger a swipe.
    private let swipeThreshold: CGFloat = 50.0

    override func scrollWheel(with event: NSEvent) {
        // Ignore momentum entirely
        guard event.momentumPhase == [] else { return }

        if event.phase == .began {
            swipeAccumulator = 0
            swipeCommitted = false
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            swipeAccumulator = 0
            swipeCommitted = false
            return
        }

        guard event.phase == .changed, !swipeCommitted else { return }

        // Horizontal swipe
        swipeAccumulator -= event.scrollingDeltaX

        if swipeAccumulator > swipeThreshold {
            swipeCommitted = true
            if model.focusedIndex >= model.items.count - 1 {
                addIdea()
            } else {
                navigateFocus(delta: 1)
            }
        } else if swipeAccumulator < -swipeThreshold {
            swipeCommitted = true
            navigateFocus(delta: -1)
        }
    }

    // MARK: - Mouse handling for resize

    private func updateTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let frames = StripLayout.layout(
            tiles: model.items,
            viewportSize: bounds.size,
            scrollOffset: model.scrollOffset,
            scale: window?.backingScaleFactor ?? 2.0
        )
        if resizeController.hitTestHandle(at: location, frames: frames) != nil {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let frames = StripLayout.layout(
            tiles: model.items,
            viewportSize: bounds.size,
            scrollOffset: model.scrollOffset,
            scale: window?.backingScaleFactor ?? 2.0
        )
        if resizeController.beginResize(at: location, frames: frames, viewportWidth: bounds.width) {
            // Resize mode — handle in mouseDragged/mouseUp
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if resizeController.continueResize(at: location, viewportWidth: bounds.width) {
            updateLayout()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if resizeController.endResize(viewportWidth: bounds.width) {
            updateLayout()
            projectStore.saveWorkspace(model)
        }
    }

    // MARK: - Keyboard (shortcuts via SettingsManager)

    override var acceptsFirstResponder: Bool { true }

    private let resizeStep: CGFloat = 80.0

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        for (action, binding) in SettingsManager.shared.shortcuts {
            if binding.matches(event) {
                perform(action)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    private let fontSizeStep: CGFloat = 2.0

    private func perform(_ action: ShortcutAction) {
        switch action {
        case .focusLeft:       navigateFocus(delta: -1)
        case .focusRight:      navigateFocus(delta: 1)
        case .moveTileLeft:    moveTile(delta: -1)
        case .moveTileRight:   moveTile(delta: 1)
        case .shrinkTile:      resizeFocused(delta: -resizeStep)
        case .growTile:        resizeFocused(delta: resizeStep)
        case .toggleFullWidth: toggleFullWidth()
        case .addIdea:         addIdea()
        case .addTerminalTile: addTerminal()
        case .removeTile:      removeFocusedItem()
        case .toggleFullscreen: window?.toggleFullScreen(nil)
        case .fontSizeUp:      changeFontSize(delta: fontSizeStep)
        case .fontSizeDown:    changeFontSize(delta: -fontSizeStep)
        case .toggleMarination: toggleCurrentNoteMarination()
        case .switchToStrip:   onSwitchMode?(.strip)
        case .switchToBuild:   onSwitchMode?(.build)
        case .switchToKanban:  onSwitchMode?(.kanban)
        case .advancePhase:    advanceFocusedPhase()
        }
    }

    private func resizeFocused(delta: CGFloat) {
        resizeController.resizeFocused(delta: delta, viewportWidth: bounds.width)
        updateLayout()
        projectStore.saveWorkspace(model)
    }

    private func changeFontSize(delta: CGFloat) {
        let minSize: CGFloat = 8
        let maxSize: CGFloat = 72

        let index = model.focusedIndex
        guard index >= 0, index < model.items.count else { return }

        let category: ViewCategory
        switch model.items[index] {
        case .idea: category = .idea
        case .terminal: category = .terminal
        }

        let current = model.fontSize(for: category)
        let newSize = max(minSize, min(maxSize, current + delta))

        switch category {
        case .idea: model.fontSizes["idea"] = newSize
        case .terminal: model.fontSizes["terminal"] = newSize
        }

        // Apply to all visible items of this category
        for item in model.items {
            let itemCategory: ViewCategory
            switch item {
            case .idea: itemCategory = .idea
            case .terminal: itemCategory = .terminal
            }
            guard itemCategory == category else { continue }
            if let view = virtualizationEngine.view(for: item.id) {
                view.setFontSize(newSize)
            }
        }

        projectStore.saveWorkspace(model)
    }

    // MARK: - Menu actions

    @objc func menuFocusLeft(_ sender: Any?)       { perform(.focusLeft) }
    @objc func menuFocusRight(_ sender: Any?)      { perform(.focusRight) }
    @objc func menuMoveTileLeft(_ sender: Any?)     { perform(.moveTileLeft) }
    @objc func menuMoveTileRight(_ sender: Any?)    { perform(.moveTileRight) }
    @objc func menuShrinkTile(_ sender: Any?)       { perform(.shrinkTile) }
    @objc func menuGrowTile(_ sender: Any?)         { perform(.growTile) }
    @objc func menuToggleFullWidth(_ sender: Any?)  { perform(.toggleFullWidth) }
    @objc func menuAddIdea(_ sender: Any?)          { perform(.addIdea) }
    @objc func menuAddTerminalTile(_ sender: Any?)  { perform(.addTerminalTile) }
    @objc func menuRemoveTile(_ sender: Any?)       { perform(.removeTile) }
    @objc func menuToggleFullscreen(_ sender: Any?) { perform(.toggleFullscreen) }
    @objc func menuFontSizeUp(_ sender: Any?)       { perform(.fontSizeUp) }
    @objc func menuFontSizeDown(_ sender: Any?)     { perform(.fontSizeDown) }
    @objc func menuToggleMarination(_ sender: Any?) { perform(.toggleMarination) }

    private func navigateFocus(delta: Int) {
        let newIndex = model.focusedIndex + delta
        guard newIndex >= 0, newIndex < model.items.count else { return }

        model.focusedIndex = newIndex
        scrollToFocused()
        updateFirstResponder()
    }

    private func moveTile(delta: Int) {
        let src = model.focusedIndex
        let dst = src + delta
        guard dst >= 0, dst < model.items.count else { return }

        model.items.swapAt(src, dst)
        model.focusedIndex = dst
        scrollToFocused()
        projectStore.saveWorkspace(model)
    }

    private func toggleFullWidth() {
        let index = model.focusedIndex
        guard index >= 0, index < model.items.count else { return }

        if case .proportional(let f) = model.items[index].widthSpec, f == .one {
            model.items[index].widthSpec = .proportional(.oneHalf)
        } else {
            model.items[index].widthSpec = .proportional(.one)
        }

        updateLayout()
        projectStore.saveWorkspace(model)
    }

    private func scrollToFocused() {
        let target = StripLayout.snapOffset(
            forTileAt: model.focusedIndex,
            tiles: model.items,
            viewportWidth: bounds.width
        )
        let maxOffset = StripLayout.maxScrollOffset(tiles: model.items, viewportWidth: bounds.width)
        let clamped = min(target, maxOffset)

        snapAnimator.animate(from: model.scrollOffset, to: clamped)
    }

    // MARK: - Item management

    /// Add a new idea after the focused item.
    private func addIdea() {
        let newItem = StripItem.idea(IdeaModel())
        insertItem(newItem)
    }

    /// Add a new standalone terminal after the focused item.
    private func addTerminal() {
        let newItem = StripItem.terminal(TerminalItem())
        insertItem(newItem)
    }

    private func insertItem(_ item: StripItem) {
        let insertIndex = min(model.focusedIndex + 1, model.items.count)
        model.items.insert(item, at: insertIndex)
        model.focusedIndex = insertIndex

        // Snap scroll offset immediately so the new item is in the viewport
        let target = StripLayout.snapOffset(
            forTileAt: model.focusedIndex,
            tiles: model.items,
            viewportWidth: bounds.width
        )
        let maxOffset = StripLayout.maxScrollOffset(tiles: model.items, viewportWidth: bounds.width)
        model.scrollOffset = min(target, maxOffset)

        updateLayout()
        projectStore.saveWorkspace(model)
        updateFirstResponder()
    }

    /// Remove the focused item (minimum 1 item remains).
    private func removeFocusedItem() {
        guard model.items.count > 1 else { return }
        let index = model.focusedIndex
        guard index >= 0, index < model.items.count else { return }

        let item = model.items[index]

        // Clean up item-specific data
        virtualizationEngine.removeView(for: item.id)
        switch item {
        case .idea:
            projectStore.deleteNoteContent(for: item.id)
            projectStore.deleteMarinationState(for: item.id)
        case .terminal:
            TerminalSessionManager.shared.markInactive(item.id)
            projectStore.deleteTerminalMeta(for: item.id)
        }

        model.items.remove(at: index)
        model.focusedIndex = min(index, model.items.count - 1)

        updateLayout()
        scrollToFocused()
        projectStore.saveWorkspace(model)
        updateFirstResponder()
    }

    // MARK: - First responder routing

    /// The item ID of the currently focused item.
    private var focusedItemID: UUID? {
        guard model.focusedIndex >= 0, model.focusedIndex < model.items.count else { return nil }
        return model.items[model.focusedIndex].id
    }

    /// Update the first responder based on the focused item type.
    func updateFirstResponder() {
        guard let itemID = focusedItemID else {
            window?.makeFirstResponder(self)
            return
        }

        let item = model.items[model.focusedIndex]
        guard let view = virtualizationEngine.view(for: itemID) else {
            window?.makeFirstResponder(self)
            return
        }

        switch item {
        case .idea:
            if let ideaView = view as? IdeaTileView {
                ideaView.makeInnerFirstResponder(in: window)
            } else if let notesView = view as? NotesTileView {
                window?.makeFirstResponder(notesView.innerWebView)
            }
        case .terminal:
            if let terminalView = view as? TerminalTileView {
                window?.makeFirstResponder(terminalView.innerSurfaceView)
            }
        }
    }

    // MARK: - Idea actions

    private func toggleCurrentNoteMarination() {
        let index = model.focusedIndex
        guard index >= 0, index < model.items.count else { return }
        guard case .idea = model.items[index] else { return }
        guard let view = virtualizationEngine.view(for: model.items[index].id) else { return }

        if let ideaView = view as? IdeaTileView {
            ideaView.toggleMarination()
        } else if let notesView = view as? NotesTileView {
            notesView.toggleMarination()
        }
    }

    private func advanceFocusedPhase() {
        let index = model.focusedIndex
        guard index >= 0, index < model.items.count else { return }
        guard case .idea(var idea) = model.items[index] else { return }

        switch idea.phase {
        case .note:  idea.phase = .plan
        case .plan:  idea.phase = .build
        case .build: idea.phase = .done
        case .done:  return
        }

        model.items[index] = .idea(idea)
        projectStore.saveWorkspace(model)

        // Notify the view of the phase change
        if let ideaView = virtualizationEngine.view(for: idea.id) as? IdeaTileView {
            ideaView.phaseDidChange(idea.phase)
        }
    }
}
