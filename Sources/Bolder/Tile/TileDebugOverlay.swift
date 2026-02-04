import AppKit

/// A small translucent overlay in the top-right corner of a tile showing debug info.
/// Add lines with `setLines(_:)` — each string becomes a row.
final class TileDebugOverlay: NSView {
    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
        layer?.cornerRadius = 4.0

        stackView.orientation = .vertical
        stackView.alignment = .trailing
        stackView.spacing = 1
        stackView.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    /// Replace all displayed lines.
    func setLines(_ lines: [String]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in lines {
            let label = NSTextField(labelWithString: line)
            label.font = FontLoader.jetBrainsMono(size: 9, weight: .medium)
            label.textColor = NSColor(white: 0.85, alpha: 1.0)
            label.backgroundColor = .clear
            label.isBezeled = false
            label.isEditable = false
            label.isSelectable = false
            stackView.addArrangedSubview(label)
        }
    }

    /// Install this overlay in a parent view, pinned to its top-right corner.
    func install(in parent: NSView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor, constant: 6),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -6),
        ])
    }
}
