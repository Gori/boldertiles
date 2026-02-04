import Foundation

/// Scroll state machine for trackpad-driven scrolling.
enum ScrollState: Equatable {
    case idle
    case tracking
    case momentum
    case settling
}

/// Manages scroll physics and state transitions.
final class ScrollPhysics {
    private(set) var state: ScrollState = .idle
    var scrollOffset: CGFloat = 0
    var minOffset: CGFloat = 0
    var maxOffset: CGFloat = 0

    /// Called when a scroll wheel event is received.
    /// Returns true if the offset changed.
    @discardableResult
    func handleScrollWheel(deltaX: CGFloat, phase: ScrollPhase, momentumPhase: ScrollPhase) -> Bool {
        let previousOffset = scrollOffset

        switch (phase, momentumPhase) {
        case (.began, _):
            // Finger touched — cancel any settling
            state = .tracking

        case (.changed, _) where state == .tracking:
            // Finger is moving
            scrollOffset -= deltaX

        case (.ended, _) where state == .tracking:
            // Finger lifted — momentum may follow
            state = .momentum

        case (_, .began):
            state = .momentum

        case (_, .changed) where state == .momentum:
            scrollOffset -= deltaX

        case (_, .ended):
            if state == .momentum {
                state = .settling
            }

        default:
            break
        }

        // Clamp
        scrollOffset = clampedOffset(scrollOffset)

        return scrollOffset != previousOffset
    }

    /// Notify that settling animation has completed.
    func settlingDidFinish() {
        if state == .settling {
            state = .idle
        }
    }

    /// Force transition to settling (e.g., when snap animation starts).
    func beginSettling() {
        state = .settling
    }

    /// Cancel current momentum/settling and go idle.
    func cancel() {
        state = .idle
    }

    private func clampedOffset(_ offset: CGFloat) -> CGFloat {
        min(max(offset, minOffset), maxOffset)
    }
}

/// Abstraction over NSEvent scroll phases.
enum ScrollPhase {
    case none
    case began
    case changed
    case ended

    init(eventPhase: UInt) {
        switch eventPhase {
        case 0: self = .none
        case 1: self = .began      // NSEvent.Phase.began.rawValue
        case 2: self = .changed    // NSEvent.Phase.changed.rawValue (stationary)
        case 4: self = .changed    // NSEvent.Phase.changed.rawValue
        case 8: self = .ended      // NSEvent.Phase.ended.rawValue
        case 16: self = .ended     // NSEvent.Phase.cancelled.rawValue
        default: self = .none
        }
    }
}
