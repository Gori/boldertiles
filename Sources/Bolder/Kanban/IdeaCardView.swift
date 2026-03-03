import AppKit

/// A card representing an idea in the Kanban board.
/// Displays title, note preview, and phase color. Supports drag-and-drop.
final class IdeaCardView: NSView, NSDraggingSource {
    static let dragType = NSPasteboard.PasteboardType("com.bolder.ideaCard")

    private let titleLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")
    private let phaseIndicator = CALayer()
    private let buildButton = NSButton(frame: .zero)
    private let buildingGlowLayer = CALayer()

    var ideaID: UUID?
    var ideaPhase: IdeaPhase?
    var onClick: ((UUID) -> Void)?
    var onDoubleClick: ((UUID) -> Void)?
    var onBuild: ((UUID) -> Void)?
    private var isSelected = false
    private var isBuilding = false
    private var mouseDownLocation: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        layer?.cornerRadius = 8
        layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.06)
        layer?.borderWidth = 1

        setupLabels()
        setupPhaseIndicator()
        setupBuildButton()
        setupBuildingGlow()
        setupTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupLabels() {
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2
        titleLabel.cell?.wraps = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 3
        previewLabel.cell?.wraps = true
        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(previewLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            previewLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            previewLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            previewLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])
    }

    private func setupPhaseIndicator() {
        phaseIndicator.cornerRadius = 3
        phaseIndicator.frame = CGRect(x: 0, y: 0, width: 6, height: 6)
        layer?.addSublayer(phaseIndicator)
    }

    private func setupBuildButton() {
        buildButton.title = "\u{25B6}" // ▶
        buildButton.bezelStyle = .inline
        buildButton.isBordered = false
        buildButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        buildButton.contentTintColor = NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        buildButton.translatesAutoresizingMaskIntoConstraints = false
        buildButton.target = self
        buildButton.action = #selector(buildButtonClicked)
        buildButton.isHidden = true
        addSubview(buildButton)

        NSLayoutConstraint.activate([
            buildButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            buildButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            buildButton.widthAnchor.constraint(equalToConstant: 22),
            buildButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    @objc private func buildButtonClicked() {
        guard let id = ideaID else { return }
        onBuild?(id)
    }

    private func setupBuildingGlow() {
        buildingGlowLayer.borderColor = CGColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.6)
        buildingGlowLayer.borderWidth = 2
        buildingGlowLayer.cornerRadius = 8
        buildingGlowLayer.isHidden = true
        layer?.addSublayer(buildingGlowLayer)
    }

    private func updateBuildingAnimation() {
        if isBuilding {
            buildingGlowLayer.isHidden = false
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.3
            pulse.duration = 1.2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            buildingGlowLayer.add(pulse, forKey: "buildingPulse")
        } else {
            buildingGlowLayer.isHidden = true
            buildingGlowLayer.removeAnimation(forKey: "buildingPulse")
        }
    }

    private func setupTracking() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func layout() {
        super.layout()
        // Position indicator at top-right (shift left if build button is visible)
        let indicatorX = buildButton.isHidden ? bounds.width - 18 : bounds.width - 36
        phaseIndicator.frame = CGRect(x: indicatorX, y: bounds.height - 18, width: 6, height: 6)

        // Building glow overlay
        buildingGlowLayer.frame = bounds

        // Constrain label wrapping to available width so text doesn't push the card wider
        let trailingPad: CGFloat = buildButton.isHidden ? 14 : 34
        let labelWidth = bounds.width - 14 - trailingPad
        if labelWidth > 0 {
            titleLabel.preferredMaxLayoutWidth = labelWidth
            previewLabel.preferredMaxLayoutWidth = labelWidth
        }
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        if selected {
            layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.4)
            layer?.borderWidth = 2
        } else {
            layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.06)
            layer?.borderWidth = 1
        }
    }

    func configure(idea: IdeaModel, notePreview: String?) {
        ideaID = idea.id
        ideaPhase = idea.phase

        let lines = (notePreview ?? "").split(separator: "\n", omittingEmptySubsequences: true)
        let title = lines.first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "Untitled"
        let cleanTitle = title.hasPrefix("#") ? title.drop(while: { $0 == "#" || $0 == " " }).description : title
        titleLabel.stringValue = cleanTitle.isEmpty ? "Untitled" : cleanTitle

        if lines.count > 1 {
            previewLabel.stringValue = lines.dropFirst().prefix(3).joined(separator: " ")
        } else {
            previewLabel.stringValue = ""
        }

        // Phase color
        let color: CGColor
        switch idea.phase {
        case .note:  color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .plan:  color = CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        case .build: color = CGColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        case .done:  color = CGColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.5)
        }
        phaseIndicator.backgroundColor = color

        // Build button visible only in Build phase when not already building
        buildButton.isHidden = idea.phase != .build || idea.buildStatus == .building
        if idea.phase == .build && idea.buildStatus == .building {
            buildButton.isHidden = true
        }

        // Building state
        isBuilding = idea.buildStatus == .building
        updateBuildingAnimation()

        // Done-phase dimming
        alphaValue = idea.phase == .done ? 0.6 : 1.0
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        guard let id = ideaID else { return }
        let location = convert(event.locationInWindow, from: nil)
        mouseDownLocation = location

        // Don't fire card click when the build button was hit
        if !buildButton.isHidden, buildButton.frame.contains(location) {
            return
        }

        if event.clickCount == 2 {
            onDoubleClick?(id)
        } else {
            onClick?(id)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let id = ideaID else { return }
        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - mouseDownLocation.x
        let dy = current.y - mouseDownLocation.y
        guard dx * dx + dy * dy > 25 else { return } // 5pt threshold

        let item = NSDraggingItem(pasteboardWriter: NSString(string: id.uuidString))
        item.setDraggingFrame(bounds, contents: snapshot())
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isSelected {
            layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.15)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isSelected {
            layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.06)
        }
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }

    // MARK: - Helpers

    private func snapshot() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            layer?.render(in: context)
        }
        image.unlockFocus()
        return image
    }
}
