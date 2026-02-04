import Foundation
import os.signpost

/// Performance instrumentation using os_signpost for Instruments profiling.
final class FrameMetrics {
    private let log = OSLog(subsystem: "com.bolder", category: "performance")
    private let signposter: OSSignposter

    private var scrollState: OSSignpostIntervalState?
    private var layoutState: OSSignpostIntervalState?

    private var frameDropCount: Int = 0
    private var lastLayoutEnd: Double = 0
    private let frameDropThreshold: Double = 1.0 / 60.0 * 1.5 // 150% of 60fps frame

    init() {
        self.signposter = OSSignposter(logHandle: log)
    }

    func beginScroll() {
        scrollState = signposter.beginInterval("ScrollSession", id: signposter.makeSignpostID())
    }

    func endScroll() {
        if let state = scrollState {
            signposter.endInterval("ScrollSession", state)
            scrollState = nil
        }
    }

    func beginLayout() {
        layoutState = signposter.beginInterval("Layout", id: signposter.makeSignpostID())
    }

    func endLayout() {
        if let state = layoutState {
            signposter.endInterval("Layout", state)
            layoutState = nil
        }

        let now = ProcessInfo.processInfo.systemUptime
        if lastLayoutEnd > 0 {
            let elapsed = now - lastLayoutEnd
            if elapsed > frameDropThreshold {
                frameDropCount += 1
                signposter.emitEvent("FrameDrop", "\(self.frameDropCount) drops total")
            }
        }
        lastLayoutEnd = now
    }

    var totalFrameDrops: Int { frameDropCount }
}
