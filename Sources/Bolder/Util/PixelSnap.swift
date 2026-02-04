import Foundation

/// Snaps a CGFloat value to the nearest pixel boundary for the given scale factor.
func pixelSnap(_ value: CGFloat, scale: CGFloat = 2.0) -> CGFloat {
    (value * scale).rounded() / scale
}

/// Snaps a CGRect to pixel boundaries, ensuring integer pixel dimensions.
func pixelSnap(_ rect: CGRect, scale: CGFloat = 2.0) -> CGRect {
    let x = pixelSnap(rect.origin.x, scale: scale)
    let y = pixelSnap(rect.origin.y, scale: scale)
    let maxX = pixelSnap(rect.origin.x + rect.size.width, scale: scale)
    let maxY = pixelSnap(rect.origin.y + rect.size.height, scale: scale)
    return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
}
