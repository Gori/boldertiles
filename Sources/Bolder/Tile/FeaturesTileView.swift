import AppKit

/// A tile displaying all features from the project's features.json.
final class FeaturesTileView: NSView, TileContentView {
    private static let backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

    private let scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autoresizingMask = [.width, .height]
        sv.drawsBackground = true
        sv.backgroundColor = backgroundColor
        sv.borderType = .noBorder
        return sv
    }()

    private let stackView: NSStackView = {
        let sv = NSStackView()
        sv.orientation = .vertical
        sv.alignment = .leading
        sv.spacing = 12
        sv.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        return sv
    }()

    private let emptyLabel: NSTextField = {
        let label = NSTextField(labelWithString: "No features yet")
        label.font = FontLoader.jetBrainsMono(size: 16)
        label.textColor = NSColor(white: 0.4, alpha: 1.0)
        label.isHidden = true
        return label
    }()

    private let debugOverlay = TileDebugOverlay()
    private let projectStore: ProjectStore

    init(frame frameRect: NSRect, projectStore: ProjectStore) {
        self.projectStore = projectStore
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Self.backgroundColor.cgColor
        setupViews()
        debugOverlay.install(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupViews() {
        // Wrap stackView in a flipped clip view so content flows top-down
        let clipView = FlippedClipView()
        clipView.drawsBackground = false

        let documentView = NSView()
        documentView.autoresizingMask = [.width]
        documentView.addSubview(stackView)

        scrollView.contentView = clipView
        scrollView.documentView = documentView
        scrollView.frame = bounds
        addSubview(scrollView)
        addSubview(emptyLabel)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
        layoutStack()

        // Center empty label
        emptyLabel.sizeToFit()
        emptyLabel.frame.origin = NSPoint(
            x: (bounds.width - emptyLabel.frame.width) / 2,
            y: (bounds.height - emptyLabel.frame.height) / 2
        )
    }

    private func layoutStack() {
        guard let documentView = scrollView.documentView else { return }
        let insets = stackView.edgeInsets
        let availableWidth = bounds.width - insets.left - insets.right
        stackView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 0)

        // Size each card
        var y: CGFloat = insets.top
        for view in stackView.arrangedSubviews {
            guard let card = view as? FeatureCardView else { continue }
            let height = card.preferredHeight(for: availableWidth)
            card.frame = NSRect(x: insets.left, y: y, width: availableWidth, height: height)
            y += height + stackView.spacing
        }
        y += insets.bottom

        stackView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: y)
        documentView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: y)
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        reloadFeatures()
        debugOverlay.setLines(["features"])
    }

    func activate() {}
    func throttle() {}
    func suspend() {}

    func resetForReuse() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func setFontSize(_ size: CGFloat) {}

    // MARK: - Public

    func reloadFeatures() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let store = projectStore.loadFeatures()
        emptyLabel.isHidden = !store.features.isEmpty

        for feature in store.features {
            let card = FeatureCardView(feature: feature)
            stackView.addArrangedSubview(card)
        }

        layoutStack()
    }
}

// MARK: - FlippedClipView

private final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

// MARK: - FeatureCardView

private final class FeatureCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let descLabel = NSTextField(labelWithString: "")
    private let statusBadge = StatusBadgeView()
    private let dateLabel = NSTextField(labelWithString: "")

    init(feature: Feature) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        layer?.cornerRadius = 6

        titleLabel.font = FontLoader.jetBrainsMono(size: 16, weight: .bold)
        titleLabel.textColor = NSColor(white: 0.9, alpha: 1.0)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0
        titleLabel.stringValue = feature.title

        descLabel.font = FontLoader.jetBrainsMono(size: 13)
        descLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 0
        descLabel.stringValue = feature.description

        statusBadge.status = feature.status

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        dateLabel.font = FontLoader.jetBrainsMono(size: 11)
        dateLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        dateLabel.stringValue = formatter.string(from: feature.createdAt)

        addSubview(titleLabel)
        addSubview(descLabel)
        addSubview(statusBadge)
        addSubview(dateLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let innerWidth = width - padding * 2

        titleLabel.preferredMaxLayoutWidth = innerWidth
        descLabel.preferredMaxLayoutWidth = innerWidth

        let titleHeight = titleLabel.sizeThatFits(NSSize(width: innerWidth, height: .greatestFiniteMagnitude)).height
        let descHeight = descLabel.sizeThatFits(NSSize(width: innerWidth, height: .greatestFiniteMagnitude)).height
        let badgeHeight: CGFloat = 22
        let dateHeight: CGFloat = 16

        return padding + titleHeight + 8 + descHeight + 8 + badgeHeight + 4 + dateHeight + padding
    }

    override func layout() {
        super.layout()
        let padding: CGFloat = 16
        let innerWidth = bounds.width - padding * 2
        var y = padding

        titleLabel.preferredMaxLayoutWidth = innerWidth
        let titleSize = titleLabel.sizeThatFits(NSSize(width: innerWidth, height: .greatestFiniteMagnitude))
        titleLabel.frame = NSRect(x: padding, y: y, width: innerWidth, height: titleSize.height)
        y += titleSize.height + 8

        descLabel.preferredMaxLayoutWidth = innerWidth
        let descSize = descLabel.sizeThatFits(NSSize(width: innerWidth, height: .greatestFiniteMagnitude))
        descLabel.frame = NSRect(x: padding, y: y, width: innerWidth, height: descSize.height)
        y += descSize.height + 8

        statusBadge.sizeToFit()
        statusBadge.frame.origin = NSPoint(x: padding, y: y)
        y += 22 + 4

        dateLabel.sizeToFit()
        dateLabel.frame.origin = NSPoint(x: padding, y: y)
    }
}

// MARK: - StatusBadgeView

private final class StatusBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    var status: FeatureStatus = .draft {
        didSet { updateAppearance() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 4

        label.font = FontLoader.jetBrainsMono(size: 11, weight: .medium)
        label.alignment = .center
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func updateAppearance() {
        let (text, bg, fg): (String, NSColor, NSColor) = {
            switch status {
            case .draft:      return ("Draft", NSColor(white: 0.3, alpha: 1.0), NSColor(white: 0.8, alpha: 1.0))
            case .planned:    return ("Planned", NSColor(red: 0.15, green: 0.25, blue: 0.5, alpha: 1.0), NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0))
            case .inProgress: return ("In Progress", NSColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1.0), NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0))
            case .done:       return ("Done", NSColor(red: 0.1, green: 0.3, blue: 0.15, alpha: 1.0), NSColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0))
            case .cancelled:  return ("Cancelled", NSColor(white: 0.25, alpha: 1.0), NSColor(white: 0.5, alpha: 1.0))
            }
        }()

        label.stringValue = text
        label.textColor = fg
        layer?.backgroundColor = bg.cgColor
    }

    func sizeToFit() {
        label.sizeToFit()
        let padding: CGFloat = 8
        frame.size = NSSize(width: label.frame.width + padding * 2, height: 22)
        label.frame = NSRect(x: padding, y: (22 - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)
    }
}
