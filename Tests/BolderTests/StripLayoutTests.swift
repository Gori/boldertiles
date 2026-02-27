import XCTest
@testable import Bolder

final class StripLayoutTests: XCTestCase {

    private let m = StripLayout.tileMargin

    func testEmptyTilesProducesNoFrames() {
        let frames = StripLayout.layout(
            tiles: [TileModel](),
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 0
        )
        XCTAssertTrue(frames.isEmpty)
    }

    func testSingleTileAtOrigin() {
        let tile = TileModel(widthSpec: .proportional(.oneThird))
        let frames = StripLayout.layout(
            tiles: [tile],
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 0
        )
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].frame.origin.x, m, accuracy: 1)
        XCTAssertEqual(frames[0].frame.origin.y, m, accuracy: 1)
        XCTAssertEqual(frames[0].frame.width, 640 - 2 * m, accuracy: 1)
        XCTAssertEqual(frames[0].frame.height, 1080 - 2 * m, accuracy: 1)
    }

    func testMultipleTilesAreContiguous() {
        let tiles = [
            TileModel(widthSpec: .proportional(.oneThird)),
            TileModel(widthSpec: .proportional(.oneThird)),
            TileModel(widthSpec: .proportional(.oneThird)),
        ]
        let frames = StripLayout.layout(
            tiles: tiles,
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 0
        )
        XCTAssertEqual(frames.count, 3)
        // Tiles have margin on each side, so gap between visual frames = tileGap + 2*margin
        let visualGap = StripLayout.tileGap + 2 * m
        XCTAssertEqual(frames[1].frame.origin.x, frames[0].frame.maxX + visualGap, accuracy: 1)
        XCTAssertEqual(frames[2].frame.origin.x, frames[1].frame.maxX + visualGap, accuracy: 1)
    }

    func testScrollOffsetShiftsFrames() {
        let tile = TileModel(widthSpec: .proportional(.oneHalf))
        let noScroll = StripLayout.layout(
            tiles: [tile],
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 0
        )
        let withScroll = StripLayout.layout(
            tiles: [tile],
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 100
        )
        XCTAssertEqual(noScroll[0].frame.origin.x - withScroll[0].frame.origin.x, 100, accuracy: 1)
    }

    func testFixedWidthTile() {
        let tile = TileModel(widthSpec: .fixed(500))
        let frames = StripLayout.layout(
            tiles: [tile],
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 0
        )
        XCTAssertEqual(frames[0].frame.width, 500 - 2 * m, accuracy: 1)
    }

    func testMinimumWidthEnforced() {
        let tile = TileModel(widthSpec: .fixed(50)) // below minimum
        let frames = StripLayout.layout(
            tiles: [tile],
            viewportSize: CGSize(width: 1920, height: 1080),
            scrollOffset: 0
        )
        XCTAssertGreaterThanOrEqual(frames[0].frame.width, StripLayout.minimumTileWidth - 2 * m)
    }

    func testSnapOffsetForFirstTileIsZero() {
        let tiles = [
            TileModel(widthSpec: .proportional(.oneThird)),
            TileModel(widthSpec: .proportional(.oneThird)),
        ]
        let offset = StripLayout.snapOffset(forTileAt: 0, tiles: tiles, viewportWidth: 1920)
        XCTAssertEqual(offset, 0)
    }

    func testSnapOffsetForSecondTile() {
        let tiles = [
            TileModel(widthSpec: .proportional(.oneThird)),
            TileModel(widthSpec: .proportional(.oneThird)),
        ]
        let offset = StripLayout.snapOffset(forTileAt: 1, tiles: tiles, viewportWidth: 1920)
        let expectedWidth = 1920.0 / 3.0
        XCTAssertEqual(offset, expectedWidth + StripLayout.tileGap, accuracy: 1)
    }

    func testNearestSnapIndex() {
        let tiles = [
            TileModel(widthSpec: .proportional(.oneThird)),
            TileModel(widthSpec: .proportional(.oneThird)),
            TileModel(widthSpec: .proportional(.oneThird)),
        ]
        // Offset 0 should snap to tile 0
        XCTAssertEqual(
            StripLayout.nearestSnapIndex(scrollOffset: 0, tiles: tiles, viewportWidth: 1920),
            0
        )
        // Offset near second tile should snap to tile 1
        let secondOffset = StripLayout.snapOffset(forTileAt: 1, tiles: tiles, viewportWidth: 1920)
        XCTAssertEqual(
            StripLayout.nearestSnapIndex(scrollOffset: secondOffset + 10, tiles: tiles, viewportWidth: 1920),
            1
        )
    }

    func testTotalContentWidth() {
        let tiles = [
            TileModel(widthSpec: .fixed(400)),
            TileModel(widthSpec: .fixed(400)),
            TileModel(widthSpec: .fixed(400)),
        ]
        let total = StripLayout.totalContentWidth(tiles: tiles, viewportWidth: 1920)
        // 3 * 400 + 2 * gap
        XCTAssertEqual(total, 1200 + 2 * StripLayout.tileGap, accuracy: 1)
    }

    func testMaxScrollOffset() {
        let tiles = [
            TileModel(widthSpec: .fixed(400)),
            TileModel(widthSpec: .fixed(400)),
            TileModel(widthSpec: .fixed(400)),
        ]
        let maxOffset = StripLayout.maxScrollOffset(tiles: tiles, viewportWidth: 1920)
        // Content fits in viewport, so no scrolling
        XCTAssertEqual(maxOffset, 0, accuracy: 1)

        // Now with wider tiles
        let wideTiles = (0..<10).map { _ in TileModel(widthSpec: .fixed(400)) }
        let wideMax = StripLayout.maxScrollOffset(tiles: wideTiles, viewportWidth: 1920)
        XCTAssertGreaterThan(wideMax, 0)
    }
}
