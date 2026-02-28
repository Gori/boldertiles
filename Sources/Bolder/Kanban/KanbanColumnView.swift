import AppKit

/// A single column in the Kanban board representing one IdeaPhase.
/// Contains a header and a scrollable vertical stack of IdeaCardViews.
final class KanbanColumnView: NSView {
    let phase: IdeaPhase
    private let headerLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "0")
    private let scrollView = NSScrollView()
    private let containerView = FlippedView()
    private let stackView = NSStackView()

    var onDropIdea: ((UUID, IdeaPhase) -> Void)?
    var onClickIdea: ((UUID) -> Void)?
    private var cardViews: [IdeaCardView] = []

    init(phase: IdeaPhase) {
        self.phase = phase
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)
        layer?.cornerRadius = 10

        setupHeader()
        setupScrollView()
        registerForDraggedTypes([IdeaCardView.dragType, .string])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupHeader() {
        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        headerLabel.textColor = phaseColor.withAlphaComponent(0.8)
        headerLabel.stringValue = phase.rawValue.uppercased()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        countLabel.textColor = NSColor.white.withAlphaComponent(0.3)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            countLabel.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            countLabel.leadingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 8),
        ])
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Use a flipped container so content starts at the top
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        scrollView.documentView = containerView

        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        // Pin the stack view inside the flipped container
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor),
        ])
    }

    override func layout() {
        super.layout()
        // Keep the container view's width matched to the clip view to prevent horizontal overflow
        let clipWidth = scrollView.contentView.bounds.width
        if containerView.frame.width != clipWidth {
            containerView.frame.size.width = clipWidth
        }
    }

    func reload(ideas: [IdeaModel], noteContentLoader: (UUID) -> String?) {
        for card in cardViews {
            stackView.removeArrangedSubview(card)
            card.removeFromSuperview()
        }
        cardViews.removeAll()

        countLabel.stringValue = "\(ideas.count)"

        for idea in ideas {
            let card = IdeaCardView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
            card.translatesAutoresizingMaskIntoConstraints = false
            card.configure(idea: idea, notePreview: noteContentLoader(idea.id))
            card.onClick = { [weak self] id in
                self?.onClickIdea?(id)
            }

            stackView.addArrangedSubview(card)
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalTo: stackView.widthAnchor),
                card.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            ])
            cardViews.append(card)
        }
    }

    private var phaseColor: NSColor {
        switch phase {
        case .note:  return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .plan:  return NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        case .build: return NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        case .done:  return NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        }
    }

    // MARK: - Drop destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = phaseColor.withAlphaComponent(0.5).cgColor
        layer?.borderWidth = 2
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = CGColor.clear
        layer?.borderWidth = 0
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = CGColor.clear
        layer?.borderWidth = 0

        guard let items = sender.draggingPasteboard.pasteboardItems,
              let first = items.first,
              let idString = first.string(forType: .string),
              let uuid = UUID(uuidString: idString) else {
            return false
        }

        onDropIdea?(uuid, phase)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        layer?.borderColor = CGColor.clear
        layer?.borderWidth = 0
    }
}

// MARK: - Flipped container

/// An NSView with flipped coordinates so content starts at the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
