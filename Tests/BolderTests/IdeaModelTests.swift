import XCTest
@testable import Bolder

final class IdeaModelTests: XCTestCase {

    func testDefaultIdeaIsNotePhase() {
        let idea = IdeaModel()
        XCTAssertEqual(idea.phase, .note)
        XCTAssertEqual(idea.noteStatus, .idle)
        XCTAssertEqual(idea.marinationPhase, .ingest)
        XCTAssertNil(idea.claudeSessionID)
    }

    func testIdeaEncodeDecode() throws {
        let idea = IdeaModel(
            phase: .build,
            widthSpec: .proportional(.oneThird),
            claudeSessionID: "test-session"
        )
        let data = try JSONEncoder().encode(idea)
        let decoded = try JSONDecoder().decode(IdeaModel.self, from: data)

        XCTAssertEqual(decoded.id, idea.id)
        XCTAssertEqual(decoded.phase, .build)
        XCTAssertEqual(decoded.widthSpec, .proportional(.oneThird))
        XCTAssertEqual(decoded.claudeSessionID, "test-session")
    }

    func testStripItemIdeaAccessors() {
        let idea = IdeaModel(widthSpec: .proportional(.oneHalf))
        let item = StripItem.idea(idea)

        XCTAssertEqual(item.id, idea.id)
        XCTAssertEqual(item.widthSpec, .proportional(.oneHalf))
        XCTAssertFalse(item.keepAliveWhenCold) // note phase
    }

    func testStripItemTerminalAccessors() {
        let term = TerminalItem(widthSpec: .fixed(500))
        let item = StripItem.terminal(term)

        XCTAssertEqual(item.id, term.id)
        XCTAssertEqual(item.widthSpec, .fixed(500))
        XCTAssertTrue(item.keepAliveWhenCold) // always true for terminals
    }

    func testStripItemBuildPhaseKeepsAlive() {
        let idea = IdeaModel(phase: .build)
        let item = StripItem.idea(idea)
        XCTAssertTrue(item.keepAliveWhenCold)
    }

    func testStripItemWidthSpecSetter() {
        var item = StripItem.idea(IdeaModel(widthSpec: .proportional(.oneHalf)))
        item.widthSpec = .fixed(600)
        XCTAssertEqual(item.widthSpec, .fixed(600))

        var termItem = StripItem.terminal(TerminalItem(widthSpec: .proportional(.oneThird)))
        termItem.widthSpec = .proportional(.one)
        XCTAssertEqual(termItem.widthSpec, .proportional(.one))
    }

    func testStripItemEncodeDecode() throws {
        let items: [StripItem] = [
            .idea(IdeaModel(phase: .plan)),
            .terminal(TerminalItem()),
        ]
        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([StripItem].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        if case .idea(let idea) = decoded[0] {
            XCTAssertEqual(idea.phase, .plan)
        } else {
            XCTFail("Expected idea")
        }
        if case .terminal = decoded[1] {
            // OK
        } else {
            XCTFail("Expected terminal")
        }
    }

    func testIdeaPhaseAllCases() {
        XCTAssertEqual(IdeaPhase.allCases, [.note, .plan, .build, .done])
    }
}
