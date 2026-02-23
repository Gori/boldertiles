import XCTest
@testable import Bolder

final class MarinationStateTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    // MARK: - Round-trip persistence

    func testMarinationStateRoundTrip() throws {
        let noteID = UUID()
        let suggestion = Suggestion(
            type: .rewrite,
            content: .rewrite(original: "old", replacement: "new", contextBefore: "a", contextAfter: "b"),
            reasoning: "Better clarity"
        )
        let entry = MarinationEntry(
            suggestion: suggestion,
            outcome: .accepted
        )
        let state = MarinationState(
            noteID: noteID,
            suggestions: [suggestion],
            history: [entry],
            lastMarinatedAt: Date(),
            marinationCount: 3,
            lastUserEditAt: Date()
        )

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(MarinationState.self, from: data)

        XCTAssertEqual(decoded.noteID, noteID)
        XCTAssertEqual(decoded.suggestions.count, 1)
        XCTAssertEqual(decoded.history.count, 1)
        XCTAssertEqual(decoded.marinationCount, 3)
        XCTAssertEqual(decoded.suggestions[0].type, .rewrite)
        XCTAssertEqual(decoded.history[0].outcome, .accepted)
    }

    // MARK: - History cap

    func testHistoryCapOnAddEntry() {
        var state = MarinationState(noteID: UUID())

        // Add 15 entries
        for i in 0..<15 {
            let suggestion = Suggestion(
                type: .question,
                content: .question(text: "Question \(i)", choices: []),
                reasoning: "Reason \(i)"
            )
            let entry = MarinationEntry(suggestion: suggestion, outcome: .rejected)
            state.addHistoryEntry(entry)
        }

        XCTAssertEqual(state.history.count, MarinationState.maxHistoryEntries)
        // The first 5 should have been dropped, so the oldest remaining is "Question 5"
        if case .question(let text, _) = state.history[0].suggestion.content {
            XCTAssertEqual(text, "Question 5")
        } else {
            XCTFail("Expected question content")
        }
    }

    func testHistoryCapPreservesRecentEntries() {
        var state = MarinationState(noteID: UUID())

        for i in 0..<12 {
            let suggestion = Suggestion(
                type: .append,
                content: .append(text: "text \(i)"),
                reasoning: "r"
            )
            state.addHistoryEntry(MarinationEntry(suggestion: suggestion, outcome: .accepted))
        }

        XCTAssertEqual(state.history.count, MarinationState.maxHistoryEntries)
        // Last entry should be "text 11"
        if case .append(let text) = state.history.last!.suggestion.content {
            XCTAssertEqual(text, "text 11")
        } else {
            XCTFail("Expected append content")
        }
    }

    // MARK: - Recent history for context

    func testRecentHistoryReturnsLast5() {
        var state = MarinationState(noteID: UUID())

        for i in 0..<8 {
            let suggestion = Suggestion(
                type: .question,
                content: .question(text: "Q\(i)", choices: []),
                reasoning: ""
            )
            state.addHistoryEntry(MarinationEntry(suggestion: suggestion, outcome: .expired))
        }

        let recent = state.recentHistory
        XCTAssertEqual(recent.count, MarinationState.historyContextCount)
        if case .question(let text, _) = recent[0].suggestion.content {
            XCTAssertEqual(text, "Q3")
        } else {
            XCTFail("Expected question content")
        }
    }

    func testRecentHistoryWithFewerThan5() {
        var state = MarinationState(noteID: UUID())

        for i in 0..<3 {
            let suggestion = Suggestion(
                type: .question,
                content: .question(text: "Q\(i)", choices: []),
                reasoning: ""
            )
            state.addHistoryEntry(MarinationEntry(suggestion: suggestion, outcome: .accepted))
        }

        XCTAssertEqual(state.recentHistory.count, 3)
    }

    // MARK: - Empty state

    func testEmptyStateRoundTrip() throws {
        let state = MarinationState(noteID: UUID())
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(MarinationState.self, from: data)

        XCTAssertEqual(decoded.noteID, state.noteID)
        XCTAssertTrue(decoded.suggestions.isEmpty)
        XCTAssertTrue(decoded.history.isEmpty)
        XCTAssertNil(decoded.lastMarinatedAt)
        XCTAssertEqual(decoded.marinationCount, 0)
        XCTAssertNil(decoded.lastUserEditAt)
    }

    // MARK: - NoteStatus round-trip

    func testNoteStatusRoundTrip() throws {
        for status in [NoteStatus.idle, .active, .waiting] {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(NoteStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }

    // MARK: - MarinationEntry round-trip

    func testMarinationEntryRoundTrip() throws {
        let suggestion = Suggestion(
            type: .promote,
            content: .promote(title: "Feature X", description: "Do the thing"),
            reasoning: "Ready for promotion"
        )
        let entry = MarinationEntry(
            suggestion: suggestion,
            outcome: .accepted
        )
        let data = try encoder.encode(entry)
        let decoded = try decoder.decode(MarinationEntry.self, from: data)

        XCTAssertEqual(decoded.suggestion.type, .promote)
        XCTAssertEqual(decoded.outcome, .accepted)
    }
}
