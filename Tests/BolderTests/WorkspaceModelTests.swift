import XCTest
@testable import Bolder

final class WorkspaceModelTests: XCTestCase {

    func testDefaultModel() {
        let model = WorkspaceModel.defaultModel()
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.focusedIndex, 0)
        XCTAssertEqual(model.viewMode, .strip)
        if case .idea(let idea) = model.items[0] {
            XCTAssertEqual(idea.phase, .note)
        } else {
            XCTFail("Expected idea")
        }
    }

    func testIdeasDerivedAccessor() {
        let model = WorkspaceModel(items: [
            .idea(IdeaModel(phase: .note)),
            .terminal(TerminalItem()),
            .idea(IdeaModel(phase: .build)),
        ])
        XCTAssertEqual(model.ideas.count, 2)
        XCTAssertEqual(model.ideas[0].phase, .note)
        XCTAssertEqual(model.ideas[1].phase, .build)
    }

    func testIdeaLookup() {
        let idea = IdeaModel()
        let model = WorkspaceModel(items: [.idea(idea), .terminal(TerminalItem())])

        XCTAssertEqual(model.idea(for: idea.id)?.id, idea.id)
        XCTAssertNil(model.idea(for: UUID()))
    }

    func testMutateIdea() {
        let idea = IdeaModel(phase: .note)
        let model = WorkspaceModel(items: [.idea(idea)])

        let result = model.mutateIdea(idea.id) { $0.phase = .plan }
        XCTAssertTrue(result)

        if case .idea(let mutated) = model.items[0] {
            XCTAssertEqual(mutated.phase, .plan)
        } else {
            XCTFail("Expected idea")
        }
    }

    func testMutateIdeaNotFound() {
        let model = WorkspaceModel(items: [.terminal(TerminalItem())])
        let result = model.mutateIdea(UUID()) { $0.phase = .done }
        XCTAssertFalse(result)
    }

    func testEncodeDecode() throws {
        let model = WorkspaceModel(
            items: [
                .idea(IdeaModel(phase: .build)),
                .terminal(TerminalItem()),
            ],
            focusedIndex: 1,
            viewMode: .build,
            selectedBuildIdeaID: UUID(),
            fontSizes: ["idea": 16]
        )

        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(WorkspaceModel.self, from: data)

        XCTAssertEqual(decoded.items.count, 2)
        XCTAssertEqual(decoded.focusedIndex, 1)
        XCTAssertEqual(decoded.viewMode, .build)
        XCTAssertEqual(decoded.selectedBuildIdeaID, model.selectedBuildIdeaID)
        XCTAssertEqual(decoded.fontSizes["idea"], 16)
        // scrollOffset not persisted
        XCTAssertEqual(decoded.scrollOffset, 0)
        XCTAssertTrue(decoded.needsInitialScroll)
    }

    func testFontSizeDefaults() {
        let model = WorkspaceModel()
        XCTAssertEqual(model.fontSize(for: .idea), 14)
        XCTAssertEqual(model.fontSize(for: .terminal), 16)

        model.fontSizes["idea"] = 20
        XCTAssertEqual(model.fontSize(for: .idea), 20)
    }

    func testFocusedItem() {
        let idea = IdeaModel()
        let model = WorkspaceModel(items: [.idea(idea)], focusedIndex: 0)
        XCTAssertEqual(model.focusedItem?.id, idea.id)

        model.focusedIndex = 5
        XCTAssertNil(model.focusedItem)
    }
}
