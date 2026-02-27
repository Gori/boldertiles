import AppKit

/// A card representing an idea in the Kanban board.
/// Displays title, note preview, and phase color. Supports drag-and-drop.
final class IdeaCardView: NSView, NSDraggingSource {
    static let dragType = NSPasteboard.PasteboardType("com.bolder.ideaCard")

    private let titleLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")
    private let phaseIndicator = CALayer()

    var ideaID: UUID?
    var onClick: ((UUID) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        layer?.cornerRadius = 8
        layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.06)
        layer?.borderWidth = 1

        setupLabels()
        setupPhaseIndicator()
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
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 3
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
        // Position indicator at top-right
        phaseIndicator.frame = CGRect(x: bounds.width - 18, y: bounds.height - 18, width: 6, height: 6)
    }

    func configure(idea: IdeaModel, notePreview: String?) {
        ideaID = idea.id

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

        // Done-phase dimming
        alphaValue = idea.phase == .done ? 0.6 : 1.0
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        guard let id = ideaID else { return }

        // Start drag
        let item = NSDraggingItem(pasteboardWriter: NSString(string: id.uuidString))
        item.setDraggingFrame(bounds, contents: snapshot())
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard let id = ideaID else { return }
        onClick?(id)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.15)
    }

    override func mouseExited(with event: NSEvent) {
        layer?.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.06)
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
