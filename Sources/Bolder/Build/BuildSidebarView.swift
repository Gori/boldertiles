import AppKit

/// Scrollable sidebar listing all Build-phase ideas.
final class BuildSidebarView: NSView {
    private let scrollView = NSScrollView()
    private let containerView = FlippedView()
    private let stackView = NSStackView()
    private let headerLabel = NSTextField(labelWithString: "BUILD")

    var onSelectIdea: ((UUID) -> Void)?
    private var itemViews: [BuildSidebarItem] = []
    private var selectedIdeaID: UUID?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)

        setupHeader()
        setupScrollView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupHeader() {
        headerLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        headerLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
        ])
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        scrollView.documentView = containerView

        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor),
        ])
    }

    override func layout() {
        super.layout()
        let clipWidth = scrollView.contentView.bounds.width
        if containerView.frame.width != clipWidth {
            containerView.frame.size.width = clipWidth
        }
    }

    /// Reload the sidebar with the given ideas.
    func reload(ideas: [IdeaModel], noteContentLoader: (UUID) -> String?, selectedID: UUID?) {
        for item in itemViews {
            stackView.removeArrangedSubview(item)
            item.removeFromSuperview()
        }
        itemViews.removeAll()

        self.selectedIdeaID = selectedID

        for idea in ideas {
            let item = BuildSidebarItem(frame: NSRect(x: 0, y: 0, width: 234, height: 52))
            item.translatesAutoresizingMaskIntoConstraints = false
            item.configure(idea: idea, notePreview: noteContentLoader(idea.id))
            item.setSelected(idea.id == selectedID)
            item.onClick = { [weak self] id in
                self?.selectIdea(id)
            }

            stackView.addArrangedSubview(item)
            NSLayoutConstraint.activate([
                item.widthAnchor.constraint(equalTo: stackView.widthAnchor),
                item.heightAnchor.constraint(equalToConstant: 52),
            ])
            itemViews.append(item)
        }
    }

    private func selectIdea(_ id: UUID) {
        selectedIdeaID = id
        for item in itemViews {
            item.setSelected(item.ideaID == id)
        }
        onSelectIdea?(id)
    }
}

/// An NSView with flipped coordinates so content starts at the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
