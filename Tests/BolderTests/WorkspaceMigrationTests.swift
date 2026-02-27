import XCTest
@testable import Bolder

final class WorkspaceMigrationTests: XCTestCase {

    func testNotesTileMigratesAsIdea() {
        let tile = TileModel(tileType: .notes)
        let strip = StripModel(tiles: [tile], focusedIndex: 0)
        let workspace = WorkspaceMigration.migrate(from: strip)

        XCTAssertEqual(workspace.items.count, 1)
        if case .idea(let idea) = workspace.items[0] {
            XCTAssertEqual(idea.id, tile.id)
            XCTAssertEqual(idea.phase, .note)
            XCTAssertEqual(idea.widthSpec, tile.widthSpec)
        } else {
            XCTFail("Expected idea")
        }
    }

    func testActiveNoteMigratesToPlanPhase() {
        let tile = TileModel(tileType: .notes, noteStatus: .active)
        let strip = StripModel(tiles: [tile])
        let workspace = WorkspaceMigration.migrate(from: strip)

        if case .idea(let idea) = workspace.items[0] {
            XCTAssertEqual(idea.phase, .plan)
        } else {
            XCTFail("Expected idea")
        }
    }

    func testTerminalMigratesAsTerminalItem() {
        let tile = TileModel(tileType: .terminal)
        let strip = StripModel(tiles: [tile])
        let workspace = WorkspaceMigration.migrate(from: strip)

        XCTAssertEqual(workspace.items.count, 1)
        if case .terminal(let term) = workspace.items[0] {
            XCTAssertEqual(term.id, tile.id)
        } else {
            XCTFail("Expected terminal")
        }
    }

    func testClaudeMigratesAsBuildIdea() {
        let tile = TileModel(tileType: .claude)
        let strip = StripModel(tiles: [tile])
        let workspace = WorkspaceMigration.migrate(from: strip)

        if case .idea(let idea) = workspace.items[0] {
            XCTAssertEqual(idea.phase, .build)
            XCTAssertEqual(idea.claudeSessionID, tile.id.uuidString)
        } else {
            XCTFail("Expected idea")
        }
    }

    func testPlaceholderAndFeaturesDiscarded() {
        let tiles = [
            TileModel(tileType: .placeholder),
            TileModel(tileType: .notes),
            TileModel(tileType: .features),
        ]
        let strip = StripModel(tiles: tiles, focusedIndex: 1)
        let workspace = WorkspaceMigration.migrate(from: strip)

        // Only the notes tile should survive
        XCTAssertEqual(workspace.items.count, 1)
        if case .idea = workspace.items[0] {} else {
            XCTFail("Expected idea")
        }
    }

    func testFocusedIndexAdjustedAfterDiscards() {
        let tiles = [
            TileModel(tileType: .placeholder),
            TileModel(tileType: .notes),
        ]
        let strip = StripModel(tiles: tiles, focusedIndex: 1)
        let workspace = WorkspaceMigration.migrate(from: strip)

        // Placeholder discarded, notes tile at index 0
        XCTAssertEqual(workspace.focusedIndex, 0)
    }

    func testEmptyStripCreatesDefaultIdea() {
        let strip = StripModel(tiles: [TileModel(tileType: .placeholder)])
        let workspace = WorkspaceMigration.migrate(from: strip)

        XCTAssertEqual(workspace.items.count, 1)
        XCTAssertEqual(workspace.focusedIndex, 0)
        if case .idea(let idea) = workspace.items[0] {
            XCTAssertEqual(idea.phase, .note)
        } else {
            XCTFail("Expected default idea")
        }
    }

    func testFontSizeMigration() {
        let strip = StripModel(tiles: [TileModel(tileType: .notes)])
        strip.fontSizes = ["notes": 18, "terminal": 20, "claude": 16]
        let workspace = WorkspaceMigration.migrate(from: strip)

        XCTAssertEqual(workspace.fontSizes["idea"], 18)
        XCTAssertEqual(workspace.fontSizes["terminal"], 20)
    }

    func testMixedStripMigration() {
        let tiles = [
            TileModel(tileType: .notes),
            TileModel(tileType: .terminal),
            TileModel(tileType: .claude),
            TileModel(tileType: .notes, noteStatus: .waiting),
        ]
        let strip = StripModel(tiles: tiles, focusedIndex: 2)
        let workspace = WorkspaceMigration.migrate(from: strip)

        XCTAssertEqual(workspace.items.count, 4)
        XCTAssertEqual(workspace.focusedIndex, 2) // claude tile → build idea at same position

        // Verify types
        if case .idea(let i0) = workspace.items[0] { XCTAssertEqual(i0.phase, .note) }
        if case .terminal = workspace.items[1] {} else { XCTFail("Expected terminal") }
        if case .idea(let i2) = workspace.items[2] { XCTAssertEqual(i2.phase, .build) }
        if case .idea(let i3) = workspace.items[3] { XCTAssertEqual(i3.phase, .plan) } // waiting → plan
    }
}
