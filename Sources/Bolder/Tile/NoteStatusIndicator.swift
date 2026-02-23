import AppKit
import QuartzCore

/// A small indicator pill showing the marination status and phase of a notes tile.
/// - idle: hidden
/// - active: phase label with amber background, pulsing
/// - waiting: phase label with blue background, static
final class NoteStatusIndicator: NSView {
    private let pillLayer = CALayer()
    private let textLayer = CATextLayer()
    private let pillHeight: CGFloat = 18
    private let horizontalPadding: CGFloat = 6

    private static let amberColor = CGColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 1.0)
    private static let blueColor = CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
    private static let textColor = CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.zPosition = 200

        pillLayer.cornerRadius = pillHeight / 2
        pillLayer.masksToBounds = true
        layer?.addSublayer(pillLayer)

        textLayer.fontSize = 8
        textLayer.font = NSFont.systemFont(ofSize: 8, weight: .bold) as CTFont
        textLayer.foregroundColor = Self.textColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.truncationMode = .none
        pillLayer.addSublayer(textLayer)

        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func layout() {
        super.layout()
        layoutPill()
    }

    func update(status: NoteStatus, phase: MarinationPhase = .ingest) {
        switch status {
        case .idle:
            isHidden = true
            pillLayer.removeAllAnimations()

        case .active:
            isHidden = false
            textLayer.string = phase.rawValue.uppercased()
            pillLayer.backgroundColor = Self.amberColor
            layoutPill()
            addPulseAnimation()

        case .waiting:
            isHidden = false
            textLayer.string = phase.rawValue.uppercased()
            pillLayer.backgroundColor = Self.blueColor
            pillLayer.removeAllAnimations()
            pillLayer.opacity = 1.0
            layoutPill()
        }
    }

    private func layoutPill() {
        let text = (textLayer.string as? String) ?? ""
        let font = NSFont.systemFont(ofSize: 8, weight: .bold)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width

        let pillWidth = textWidth + horizontalPadding * 2
        let pillFrame = CGRect(
            x: (bounds.width - pillWidth) / 2,
            y: (bounds.height - pillHeight) / 2,
            width: pillWidth,
            height: pillHeight
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pillLayer.frame = pillFrame
        textLayer.frame = CGRect(x: 0, y: 3, width: pillWidth, height: pillHeight - 3)
        CATransaction.commit()
    }

    private func addPulseAnimation() {
        pillLayer.removeAllAnimations()
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.4
        pulse.toValue = 1.0
        pulse.duration = 2.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pillLayer.add(pulse, forKey: "pulse")
    }
}
