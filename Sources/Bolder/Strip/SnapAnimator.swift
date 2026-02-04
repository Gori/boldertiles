import AppKit
import QuartzCore

/// Drives a critically damped spring animation using CVDisplayLink to snap scroll position.
final class SnapAnimator {
    // Spring parameters
    private let stiffness: CGFloat = 300.0
    private let damping: CGFloat    // Computed for critical damping

    private var timer: Timer?
    private var currentValue: CGFloat = 0
    private var currentVelocity: CGFloat = 0
    private var targetValue: CGFloat = 0
    private var lastTimestamp: CFTimeInterval = 0

    /// Called each frame with the new scroll offset.
    var onUpdate: ((CGFloat) -> Void)?
    /// Called when the spring has settled.
    var onComplete: (() -> Void)?

    init() {
        // Critical damping: damping = 2 * sqrt(stiffness * mass), mass = 1
        self.damping = 2.0 * sqrt(stiffness)
    }

    /// Start animating from current position to target.
    func animate(from current: CGFloat, to target: CGFloat, initialVelocity: CGFloat = 0) {
        stop()

        self.currentValue = current
        self.targetValue = target
        self.currentVelocity = initialVelocity
        self.lastTimestamp = CACurrentMediaTime()

        if abs(current - target) < 0.5 && abs(initialVelocity) < 1.0 {
            onUpdate?(target)
            onComplete?()
            return
        }

        // Use a high-frequency timer (~120Hz) for smooth animation on ProMotion displays
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    /// Stop the animation immediately.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var isAnimating: Bool {
        timer != nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(CGFloat(now - lastTimestamp), 1.0 / 30.0)
        lastTimestamp = now
        guard dt > 0 else { return }

        // Spring physics: F = -k * displacement - c * velocity
        let displacement = currentValue - targetValue
        let springForce = -stiffness * displacement
        let dampingForce = -damping * currentVelocity
        let acceleration = springForce + dampingForce // mass = 1

        currentVelocity += acceleration * dt
        currentValue += currentVelocity * dt

        // Check if settled
        if abs(currentValue - targetValue) < 0.5 && abs(currentVelocity) < 1.0 {
            currentValue = targetValue
            currentVelocity = 0
            stop()
            onUpdate?(targetValue)
            onComplete?()
        } else {
            onUpdate?(currentValue)
        }
    }
}
