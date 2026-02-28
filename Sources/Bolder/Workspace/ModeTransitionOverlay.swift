import AppKit
import QuartzCore

/// A fullscreen overlay that briefly shows the mode name when switching views.
/// Fades in quickly, holds, then fades out with a subtle scale effect.
final class ModeTransitionOverlay: NSView {
    private let backdropLayer = CALayer()
    private let labelLayer = CATextLayer()
    private let subtitleLayer = CATextLayer()
    private var dismissWorkItem: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.zPosition = 9999

        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupLayers() {
        // Semi-transparent backdrop
        backdropLayer.backgroundColor = CGColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 0.85)
        layer?.addSublayer(backdropLayer)

        // Mode name
        labelLayer.fontSize = 42
        labelLayer.font = NSFont.systemFont(ofSize: 42, weight: .bold)
        labelLayer.foregroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.9)
        labelLayer.alignmentMode = .center
        labelLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        labelLayer.isWrapped = false
        labelLayer.truncationMode = .none
        layer?.addSublayer(labelLayer)

        // Keyboard shortcut hint
        subtitleLayer.fontSize = 14
        subtitleLayer.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLayer.foregroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.3)
        subtitleLayer.alignmentMode = .center
        subtitleLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        subtitleLayer.isWrapped = false
        subtitleLayer.truncationMode = .none
        layer?.addSublayer(subtitleLayer)
    }

    override func layout() {
        super.layout()
        backdropLayer.frame = bounds

        let labelHeight: CGFloat = 52
        let subtitleHeight: CGFloat = 20
        let gap: CGFloat = 8
        let totalHeight = labelHeight + gap + subtitleHeight
        let centerY = bounds.midY - totalHeight / 2

        labelLayer.frame = CGRect(
            x: 0,
            y: centerY + gap + subtitleHeight,
            width: bounds.width,
            height: labelHeight
        )
        subtitleLayer.frame = CGRect(
            x: 0,
            y: centerY,
            width: bounds.width,
            height: subtitleHeight
        )
    }

    /// Show the overlay for a given mode, then auto-dismiss.
    func show(mode: ViewMode, in parentView: NSView) {
        dismissWorkItem?.cancel()

        let (title, shortcut) = modeInfo(mode)
        labelLayer.string = title
        subtitleLayer.string = shortcut

        frame = parentView.bounds
        autoresizingMask = [.width, .height]

        if superview == nil {
            parentView.addSubview(self)
        }

        // Reset state
        alphaValue = 0
        layer?.transform = CATransform3DMakeScale(1.08, 1.08, 1.0)

        // Animate in
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
            self.layer?.transform = CATransform3DIdentity
        })

        // Schedule dismiss
        let item = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: item)
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.removeFromSuperview()
        })
    }

    private func modeInfo(_ mode: ViewMode) -> (title: String, shortcut: String) {
        switch mode {
        case .strip:
            return ("STRIP", "⌘1")
        case .build:
            return ("BUILD", "⌘2")
        case .kanban:
            return ("KANBAN", "⌘3")
        }
    }
}
