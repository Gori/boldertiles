import XCTest
@testable import Bolder

final class WidthSpecTests: XCTestCase {

    func testProportionalResolve() {
        let spec = WidthSpec.proportional(.oneThird)
        let width = spec.resolve(viewportWidth: 1920)
        XCTAssertEqual(width, 640, accuracy: 0.1)
    }

    func testFixedResolve() {
        let spec = WidthSpec.fixed(500)
        let width = spec.resolve(viewportWidth: 1920)
        XCTAssertEqual(width, 500)
    }

    func testOneHalfResolve() {
        let spec = WidthSpec.proportional(.oneHalf)
        let width = spec.resolve(viewportWidth: 1920)
        XCTAssertEqual(width, 960, accuracy: 0.1)
    }

    func testSnapToPresetWithinTolerance() {
        // 640 is exactly 1/3 of 1920
        let spec = WidthSpec.fixed(645) // within 20pt of 640
        let snapped = spec.snappedToPreset(viewportWidth: 1920)
        if case .proportional(let frac) = snapped {
            XCTAssertEqual(frac, .oneThird)
        } else {
            XCTFail("Expected proportional snap")
        }
    }

    func testSnapToPresetOutsideTolerance() {
        let spec = WidthSpec.fixed(700) // not close to any preset
        let snapped = spec.snappedToPreset(viewportWidth: 1920)
        if case .fixed(let px) = snapped {
            XCTAssertEqual(px, 700)
        } else {
            XCTFail("Expected fixed width to remain")
        }
    }

    func testProportionalDoesNotSnap() {
        let spec = WidthSpec.proportional(.oneQuarter)
        let snapped = spec.snappedToPreset(viewportWidth: 1920)
        XCTAssertEqual(spec, snapped)
    }

    func testFractionEquality() {
        let a = Fraction(2, 6) // reduces to 1/3
        let b = Fraction(1, 3)
        XCTAssertEqual(a, b)
    }

    func testFractionDoubleValue() {
        let f = Fraction(1, 4)
        XCTAssertEqual(f.doubleValue, 0.25, accuracy: 0.001)
    }

    func testWidthSpecCodable() throws {
        let specs: [WidthSpec] = [
            .proportional(.oneThird),
            .fixed(500),
        ]
        let encoder = JSONEncoder()
        let data = try encoder.encode(specs)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([WidthSpec].self, from: data)
        XCTAssertEqual(specs, decoded)
    }
}
