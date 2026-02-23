import XCTest
@testable import Bolder

final class SuggestionCodableTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    // MARK: - SuggestionContent round-trips

    func testRewriteRoundTrip() throws {
        let content = SuggestionContent.rewrite(
            original: "old text",
            replacement: "new text",
            contextBefore: "before ",
            contextAfter: " after"
        )
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testAppendRoundTrip() throws {
        let content = SuggestionContent.append(text: "appended text")
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testInsertRoundTrip() throws {
        let content = SuggestionContent.insert(text: "inserted", afterContext: "section header\n")
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testCompressionRoundTrip() throws {
        let content = SuggestionContent.compression(
            original: "very long verbose text that could be shorter",
            replacement: "concise text",
            contextBefore: "prefix ",
            contextAfter: " suffix"
        )
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testQuestionRoundTrip() throws {
        let content = SuggestionContent.question(text: "Have you considered error handling?", choices: [])
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testQuestionWithChoicesRoundTrip() throws {
        let content = SuggestionContent.question(
            text: "Which approach?",
            choices: ["Option A", "Option B", "Option C"]
        )
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testCritiqueRoundTrip() throws {
        let content = SuggestionContent.critique(
            severity: .weak,
            targetText: "vague language here",
            critiqueText: "This is too vague — what specifically changes?",
            contextBefore: "prefix ",
            contextAfter: " suffix"
        )
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    func testPromoteRoundTrip() throws {
        let content = SuggestionContent.promote(title: "Auth System", description: "Implement OAuth2 flow")
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }

    // MARK: - Full Suggestion round-trip

    func testFullSuggestionRoundTrip() throws {
        let suggestion = Suggestion(
            type: .rewrite,
            content: .rewrite(original: "a", replacement: "b", contextBefore: "x", contextAfter: "y"),
            reasoning: "Clearer wording"
        )
        let data = try encoder.encode(suggestion)
        let decoded = try decoder.decode(Suggestion.self, from: data)
        XCTAssertEqual(suggestion, decoded)
    }

    // MARK: - Decoding from Claude-style JSON

    func testDecodeRewriteFromRawJSON() throws {
        let json = """
        {
            "type": "rewrite",
            "original": "foo bar",
            "replacement": "baz qux",
            "contextBefore": "pre ",
            "contextAfter": " post"
        }
        """
        let data = json.data(using: .utf8)!
        let content = try decoder.decode(SuggestionContent.self, from: data)
        if case .rewrite(let orig, let repl, let before, let after) = content {
            XCTAssertEqual(orig, "foo bar")
            XCTAssertEqual(repl, "baz qux")
            XCTAssertEqual(before, "pre ")
            XCTAssertEqual(after, " post")
        } else {
            XCTFail("Expected rewrite case")
        }
    }

    func testDecodeAppendFromRawJSON() throws {
        let json = """
        {"type": "append", "text": "new paragraph"}
        """
        let data = json.data(using: .utf8)!
        let content = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, .append(text: "new paragraph"))
    }

    func testDecodeUnknownTypeThrows() {
        let json = """
        {"type": "unknown_type", "text": "something"}
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(SuggestionContent.self, from: data))
    }

    // MARK: - SuggestionState round-trip

    func testSuggestionStateRoundTrip() throws {
        for state in [SuggestionState.pending, .accepted, .rejected, .expired] {
            let data = try encoder.encode(state)
            let decoded = try decoder.decode(SuggestionState.self, from: data)
            XCTAssertEqual(state, decoded)
        }
    }

    // MARK: - Unicode content

    func testUnicodeContentRoundTrip() throws {
        let content = SuggestionContent.rewrite(
            original: "les fran\u{00E7}ais",
            replacement: "\u{1F600} emoji text \u{2603}",
            contextBefore: "\u{4E2D}\u{6587}",
            contextAfter: "\u{65E5}\u{672C}\u{8A9E}"
        )
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(SuggestionContent.self, from: data)
        XCTAssertEqual(content, decoded)
    }
}
