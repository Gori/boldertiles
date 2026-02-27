import AppKit

/// A single row in the Build sidebar showing an idea's title and note preview.
final class BuildSidebarItem: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")
    private let selectionIndicator = CALayer()

    var ideaID: UUID?
    var onClick: ((UUID) -> Void)?

    private(set) var isSelected = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6

        setupLabels()
        setupTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupLabels() {
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 2
        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(previewLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            previewLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            previewLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            previewLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
        ])
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

    func configure(idea: IdeaModel, notePreview: String?) {
        ideaID = idea.id

        // Use first line of note as title, or "Untitled"
        let lines = (notePreview ?? "").split(separator: "\n", omittingEmptySubsequences: true)
        let title = lines.first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "Untitled"
        // Strip leading markdown heading markers
        let cleanTitle = title.hasPrefix("#") ? title.drop(while: { $0 == "#" || $0 == " " }).description : title
        titleLabel.stringValue = cleanTitle.isEmpty ? "Untitled" : cleanTitle

        // Preview is second+ lines
        if lines.count > 1 {
            previewLabel.stringValue = lines.dropFirst().prefix(2).joined(separator: " ")
        } else {
            previewLabel.stringValue = "No content"
        }
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        layer?.backgroundColor = selected
            ? CGColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 0.4)
            : CGColor.clear
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        guard let id = ideaID else { return }
        onClick?(id)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isSelected {
            layer?.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.05)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isSelected {
            layer?.backgroundColor = CGColor.clear
        }
    }
}
