import Foundation

/// Specifies how a tile's width is determined.
enum WidthSpec: Codable, Equatable, Sendable {
    /// Width as a fraction of the viewport width.
    case proportional(Fraction)
    /// Width as a fixed pixel value.
    case fixed(CGFloat)

    /// Resolve to a pixel width given the viewport width.
    func resolve(viewportWidth: CGFloat) -> CGFloat {
        switch self {
        case .proportional(let fraction):
            return viewportWidth * CGFloat(fraction.doubleValue)
        case .fixed(let px):
            return px
        }
    }

    /// Try to snap a fixed pixel width to a proportional preset if within tolerance.
    func snappedToPreset(viewportWidth: CGFloat, tolerance: CGFloat = 20.0) -> WidthSpec {
        guard case .fixed(let px) = self else { return self }
        for preset in Fraction.presets {
            let presetPx = viewportWidth * CGFloat(preset.doubleValue)
            if abs(px - presetPx) <= tolerance {
                return .proportional(preset)
            }
        }
        return self
    }
}
