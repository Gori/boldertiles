import XCTest
@testable import Bolder

final class ScrollPhysicsTests: XCTestCase {

    func testInitialStateIsIdle() {
        let physics = ScrollPhysics()
        XCTAssertEqual(physics.state, .idle)
    }

    func testBeganTransitionsToTracking() {
        let physics = ScrollPhysics()
        physics.maxOffset = 1000
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        XCTAssertEqual(physics.state, .tracking)
    }

    func testTrackingUpdatesOffset() {
        let physics = ScrollPhysics()
        physics.maxOffset = 1000
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: -50, phase: .changed, momentumPhase: .none)
        XCTAssertEqual(physics.scrollOffset, 50, accuracy: 0.1)
    }

    func testEndedTransitionsToMomentum() {
        let physics = ScrollPhysics()
        physics.maxOffset = 1000
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: -50, phase: .changed, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: 0, phase: .ended, momentumPhase: .none)
        XCTAssertEqual(physics.state, .momentum)
    }

    func testMomentumEndTransitionsToSettling() {
        let physics = ScrollPhysics()
        physics.maxOffset = 1000
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: 0, phase: .ended, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: -10, phase: .none, momentumPhase: .changed)
        physics.handleScrollWheel(deltaX: 0, phase: .none, momentumPhase: .ended)
        XCTAssertEqual(physics.state, .settling)
    }

    func testOffsetClampedToMax() {
        let physics = ScrollPhysics()
        physics.maxOffset = 100
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: -500, phase: .changed, momentumPhase: .none)
        XCTAssertEqual(physics.scrollOffset, 100, accuracy: 0.1)
    }

    func testOffsetClampedToMin() {
        let physics = ScrollPhysics()
        physics.maxOffset = 1000
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        physics.handleScrollWheel(deltaX: 500, phase: .changed, momentumPhase: .none)
        XCTAssertEqual(physics.scrollOffset, 0, accuracy: 0.1)
    }

    func testSettlingDidFinishGoesIdle() {
        let physics = ScrollPhysics()
        physics.beginSettling()
        XCTAssertEqual(physics.state, .settling)
        physics.settlingDidFinish()
        XCTAssertEqual(physics.state, .idle)
    }

    func testCancelGoesIdle() {
        let physics = ScrollPhysics()
        physics.maxOffset = 1000
        physics.handleScrollWheel(deltaX: 0, phase: .began, momentumPhase: .none)
        XCTAssertEqual(physics.state, .tracking)
        physics.cancel()
        XCTAssertEqual(physics.state, .idle)
    }
}
