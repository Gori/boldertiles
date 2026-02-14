import AppKit
import QuartzCore

/// The main compositor view that hosts the horizontal strip of tiles.
final class StripView: NSView {
    private let model: StripModel
    private let snapAnimator = SnapAnimator()
    private let resizeController: ResizeController
    private let virtualizationEngine: VirtualizationEngine
    private let projectStore: ProjectStore
    private let frameMetrics = FrameMetrics()

    // Tile container layers keyed by tile ID
    private var tileLayers: [UUID: CALayer] = [:]
    // Focus highlight layer
    private let focusLayer = CALayer()

    private var trackingArea: NSTrackingArea?

    // Swipe gesture state: accumulate deltaX, commit ±1 tile when threshold crossed
    private var swipeAccumulator: CGFloat = 0
    private var swipeCommitted = false

    init(model: StripModel, projectStore: ProjectStore) {
        self.model = model
        self.projectStore = projectStore
        self.resizeController = ResizeController(model: model)
        let factory = DefaultTileViewFactory(projectStore: projectStore)
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
            self.projectStore.save(self.model)
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        if model.needsInitialScroll {
            model.needsInitialScroll = false
            let target = StripLayout.snapOffset(
                forTileAt: model.focusedIndex,
                tiles: model.tiles,
                viewportWidth: bounds.width
            )
            let maxOffset = StripLayout.maxScrollOffset(tiles: model.tiles, viewportWidth: bounds.width)
            model.scrollOffset = min(target, maxOffset)
        }
        updateLayout()
        updateTrackingArea()
    }

    private func updateLayout() {
        let frames = StripLayout.layout(
            tiles: model.tiles,
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
            tiles: model.tiles,
            containerView: self,
            fontSizeForType: { [weak self] type in
                self?.model.fontSize(for: type) ?? TileModel.defaultFontSize(for: type)
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

        swipeAccumulator -= event.scrollingDeltaX

        if swipeAccumulator > swipeThreshold {
            swipeCommitted = true
            if model.focusedIndex >= model.tiles.count - 1 {
                addTile(type: .notes)
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
            tiles: model.tiles,
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
            tiles: model.tiles,
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
            projectStore.save(model)
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
        case .addNotesTile:    addTile(type: .notes)
        case .addTerminalTile: addTile(type: .terminal)
        case .addClaudeTile:   addTile(type: .claude)
        case .addFeaturesTile: openOrCreateFeaturesTile()
        case .removeTile:      removeFocusedTile()
        case .toggleFullscreen: window?.toggleFullScreen(nil)
        case .fontSizeUp:      changeFontSize(delta: fontSizeStep)
        case .fontSizeDown:    changeFontSize(delta: -fontSizeStep)
        case .refineNote:      refineCurrentNote()
        case .saveAsFeature:   saveCurrentNoteAsFeature()
        }
    }

    private func resizeFocused(delta: CGFloat) {
        resizeController.resizeFocused(delta: delta, viewportWidth: bounds.width)
        updateLayout()
        projectStore.save(model)
    }

    private func changeFontSize(delta: CGFloat) {
        let minSize: CGFloat = 8
        let maxSize: CGFloat = 72

        let index = model.focusedIndex
        guard index >= 0, index < model.tiles.count else { return }
        let tileType = model.tiles[index].tileType
        let current = model.fontSize(for: tileType)
        let newSize = max(minSize, min(maxSize, current + delta))
        model.fontSizes[tileType.rawValue] = newSize

        // Apply to all visible tiles of this type
        for tile in model.tiles {
            guard tile.tileType == tileType else { continue }
            if let view = virtualizationEngine.view(for: tile.id) {
                view.setFontSize(newSize)
            }
        }

        projectStore.save(model)
    }

    // MARK: - Menu actions

    @objc func menuFocusLeft(_ sender: Any?)       { perform(.focusLeft) }
    @objc func menuFocusRight(_ sender: Any?)      { perform(.focusRight) }
    @objc func menuMoveTileLeft(_ sender: Any?)     { perform(.moveTileLeft) }
    @objc func menuMoveTileRight(_ sender: Any?)    { perform(.moveTileRight) }
    @objc func menuShrinkTile(_ sender: Any?)       { perform(.shrinkTile) }
    @objc func menuGrowTile(_ sender: Any?)         { perform(.growTile) }
    @objc func menuToggleFullWidth(_ sender: Any?)  { perform(.toggleFullWidth) }
    @objc func menuAddNotesTile(_ sender: Any?)     { perform(.addNotesTile) }
    @objc func menuAddTerminalTile(_ sender: Any?)  { perform(.addTerminalTile) }
    @objc func menuAddClaudeTile(_ sender: Any?)    { perform(.addClaudeTile) }
    @objc func menuRemoveTile(_ sender: Any?)       { perform(.removeTile) }
    @objc func menuToggleFullscreen(_ sender: Any?) { perform(.toggleFullscreen) }
    @objc func menuFontSizeUp(_ sender: Any?)       { perform(.fontSizeUp) }
    @objc func menuFontSizeDown(_ sender: Any?)     { perform(.fontSizeDown) }
    @objc func menuAddFeaturesTile(_ sender: Any?)   { perform(.addFeaturesTile) }
    @objc func menuRefineNote(_ sender: Any?)        { perform(.refineNote) }
    @objc func menuSaveAsFeature(_ sender: Any?)     { perform(.saveAsFeature) }

    private func navigateFocus(delta: Int) {
        let newIndex = model.focusedIndex + delta
        guard newIndex >= 0, newIndex < model.tiles.count else { return }

        model.focusedIndex = newIndex
        scrollToFocused()
        updateFirstResponder()
    }

    private func moveTile(delta: Int) {
        let src = model.focusedIndex
        let dst = src + delta
        guard dst >= 0, dst < model.tiles.count else { return }

        model.tiles.swapAt(src, dst)
        model.focusedIndex = dst
        scrollToFocused()
        projectStore.save(model)
    }

    private func toggleFullWidth() {
        let index = model.focusedIndex
        guard index >= 0, index < model.tiles.count else { return }

        let tile = model.tiles[index]
        if case .proportional(let f) = tile.widthSpec, f == .one {
            model.tiles[index].widthSpec = .proportional(.oneHalf)
        } else {
            model.tiles[index].widthSpec = .proportional(.one)
        }

        updateLayout()
        projectStore.save(model)
    }

    private func scrollToFocused() {
        let target = StripLayout.snapOffset(
            forTileAt: model.focusedIndex,
            tiles: model.tiles,
            viewportWidth: bounds.width
        )
        let maxOffset = StripLayout.maxScrollOffset(tiles: model.tiles, viewportWidth: bounds.width)
        let clamped = min(target, maxOffset)

        snapAnimator.animate(from: model.scrollOffset, to: clamped)
    }

    // MARK: - Tile management

    /// Add a new tile of the given type after the focused tile.
    private func addTile(type: TileType) {
        let newTile = TileModel(
            widthSpec: .proportional(.oneHalf),
            tileType: type,
            color: .random()
        )
        let insertIndex = min(model.focusedIndex + 1, model.tiles.count)
        model.tiles.insert(newTile, at: insertIndex)
        model.focusedIndex = insertIndex

        // Snap scroll offset immediately so the new tile is in the viewport
        // before updateLayout, ensuring the virtualization engine creates its view.
        let target = StripLayout.snapOffset(
            forTileAt: model.focusedIndex,
            tiles: model.tiles,
            viewportWidth: bounds.width
        )
        let maxOffset = StripLayout.maxScrollOffset(tiles: model.tiles, viewportWidth: bounds.width)
        model.scrollOffset = min(target, maxOffset)

        updateLayout()
        projectStore.save(model)
        updateFirstResponder()
    }

    /// Remove the focused tile (minimum 1 tile remains).
    private func removeFocusedTile() {
        guard model.tiles.count > 1 else { return }
        let index = model.focusedIndex
        guard index >= 0, index < model.tiles.count else { return }

        let tile = model.tiles[index]

        // Clean up tile-specific data
        virtualizationEngine.removeView(for: tile.id)
        switch tile.tileType {
        case .notes:
            projectStore.deleteNoteContent(for: tile.id)
        case .terminal:
            TerminalSessionManager.shared.markInactive(tile.id)
            projectStore.deleteTerminalMeta(for: tile.id)
        case .claude:
            if let claudeView = virtualizationEngine.view(for: tile.id) as? ClaudeTileView {
                claudeView.terminateSession()
            }
            projectStore.deleteClaudeMeta(for: tile.id)
        case .features, .placeholder:
            break
        }

        model.tiles.remove(at: index)
        model.focusedIndex = min(index, model.tiles.count - 1)


        updateLayout()
        scrollToFocused()
        projectStore.save(model)
        updateFirstResponder()
    }

    // MARK: - First responder routing

    /// The tile ID of the currently focused tile.
    private var focusedTileID: UUID? {
        guard model.focusedIndex >= 0, model.focusedIndex < model.tiles.count else { return nil }
        return model.tiles[model.focusedIndex].id
    }

    /// Update the first responder based on the focused tile type.
    func updateFirstResponder() {
        guard let tileID = focusedTileID else {
            window?.makeFirstResponder(self)
            return
        }

        let tile = model.tiles[model.focusedIndex]
        guard let view = virtualizationEngine.view(for: tileID) else {
            window?.makeFirstResponder(self)
            return
        }

        switch tile.tileType {
        case .notes:
            if let notesView = view as? NotesTileView {
                if notesView.isRefineActive, let answerField = notesView.refineAnswerField {
                    window?.makeFirstResponder(answerField)
                } else {
                    window?.makeFirstResponder(notesView.innerTextView)
                }
            }
        case .terminal:
            if let terminalView = view as? TerminalTileView {
                window?.makeFirstResponder(terminalView.innerSurfaceView)
            }
        case .claude:
            if let claudeView = view as? ClaudeTileView {
                window?.makeFirstResponder(claudeView.innerWebView)
            }
        case .features, .placeholder:
            window?.makeFirstResponder(self)
        }
    }

    // MARK: - Feature actions

    private func refineCurrentNote() {
        let index = model.focusedIndex
        guard index >= 0, index < model.tiles.count,
              model.tiles[index].tileType == .notes else { return }
        guard let notesView = virtualizationEngine.view(for: model.tiles[index].id) as? NotesTileView else { return }
        notesView.startRefine(projectURL: projectStore.projectURL)
    }

    private func saveCurrentNoteAsFeature() {
        let index = model.focusedIndex
        guard index >= 0, index < model.tiles.count,
              model.tiles[index].tileType == .notes else { return }
        guard let notesView = virtualizationEngine.view(for: model.tiles[index].id) as? NotesTileView else { return }

        notesView.saveAsFeature(projectURL: projectStore.projectURL) { [weak self] feature in
            guard let self, let feature else { return }
            var store = self.projectStore.loadFeatures()
            store.features.append(feature)
            self.projectStore.saveFeatures(store)
            self.openOrCreateFeaturesTile()
        }
    }

    private func openOrCreateFeaturesTile() {
        // Navigate to existing features tile if one exists
        if let existingIndex = model.tiles.firstIndex(where: { $0.tileType == .features }) {
            model.focusedIndex = existingIndex
            // Reload the features view
            if let featuresView = virtualizationEngine.view(for: model.tiles[existingIndex].id) as? FeaturesTileView {
                featuresView.reloadFeatures()
            }
            scrollToFocused()
            updateFirstResponder()
            return
        }

        // Create a new features tile
        addTile(type: .features)
    }
}
