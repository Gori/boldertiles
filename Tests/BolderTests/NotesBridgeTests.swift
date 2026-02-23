import XCTest
@testable import Bolder

final class NotesBridgeTests: XCTestCase {

    // MARK: - Encoding tests

    func testEncodeSetContent() {
        let json = NotesBridge.encodeSetContent("Hello, world!")
        XCTAssertTrue(json.contains("\"type\":\"setContent\""))
        XCTAssertTrue(json.contains("\"text\":\"Hello, world!\""))
    }

    func testEncodeSetContentEscapesNewlines() {
        let json = NotesBridge.encodeSetContent("line1\nline2")
        XCTAssertTrue(json.contains("\\n"))
        XCTAssertFalse(json.contains("\n\"")) // actual newline should be escaped
    }

    func testEncodeSetContentEscapesQuotes() {
        let json = NotesBridge.encodeSetContent("He said \"hello\"")
        XCTAssertTrue(json.contains("\\\"hello\\\""))
    }

    func testEncodeSuggestions() {
        let suggestion = Suggestion(
            type: .question,
            content: .question(text: "What is the core user?", choices: ["Developers", "Designers"]),
            reasoning: "Forces a decision"
        )
        let json = NotesBridge.encodeSuggestions([suggestion])
        XCTAssertTrue(json.contains("\"type\":\"setSuggestions\""))
        XCTAssertTrue(json.contains("\"type\":\"question\""))
        XCTAssertTrue(json.contains("Developers"))
        XCTAssertTrue(json.contains("Designers"))
    }

    func testEncodeRewriteSuggestion() {
        let suggestion = Suggestion(
            type: .rewrite,
            content: .rewrite(
                original: "old text",
                replacement: "new text",
                contextBefore: "before ",
                contextAfter: " after"
            ),
            reasoning: "Sharper framing"
        )
        let json = NotesBridge.encodeSuggestions([suggestion])
        XCTAssertTrue(json.contains("\"type\":\"rewrite\""))
        XCTAssertTrue(json.contains("\"original\":\"old text\""))
        XCTAssertTrue(json.contains("\"replacement\":\"new text\""))
    }

    func testEncodeCritiqueSuggestion() {
        let suggestion = Suggestion(
            type: .critique,
            content: .critique(
                severity: .strong,
                targetText: "vague statement",
                critiqueText: "Too broad",
                contextBefore: "abc",
                contextAfter: "xyz"
            ),
            reasoning: "Needs specificity"
        )
        let json = NotesBridge.encodeSuggestions([suggestion])
        XCTAssertTrue(json.contains("\"severity\":\"strong\""))
        XCTAssertTrue(json.contains("\"targetText\":\"vague statement\""))
    }

    func testEncodeRemoveSuggestion() {
        let id = UUID()
        let json = NotesBridge.encodeRemoveSuggestion(id: id)
        XCTAssertTrue(json.contains("\"type\":\"removeSuggestion\""))
        XCTAssertTrue(json.contains(id.uuidString))
    }

    func testEncodeClearSuggestions() {
        let json = NotesBridge.encodeClearSuggestions()
        XCTAssertEqual(json, #"{"type":"clearSuggestions"}"#)
    }

    func testEncodeSetFontSize() {
        let json = NotesBridge.encodeSetFontSize(16)
        XCTAssertTrue(json.contains("\"size\":16"))
    }

    func testEncodeSetEditable() {
        XCTAssertTrue(NotesBridge.encodeSetEditable(true).contains("true"))
        XCTAssertTrue(NotesBridge.encodeSetEditable(false).contains("false"))
    }

    func testEncodeFocus() {
        XCTAssertEqual(NotesBridge.encodeFocus(), #"{"type":"focus"}"#)
    }

    // MARK: - Decoding tests

    func testDecodeReady() {
        let action = NotesBridge.decodeAction(["type": "ready"])
        XCTAssertEqual(action, .ready)
    }

    func testDecodeContentChanged() {
        let action = NotesBridge.decodeAction(["type": "contentChanged", "text": "hello"])
        XCTAssertEqual(action, .contentChanged(text: "hello"))
    }

    func testDecodeSuggestionAccepted() {
        let id = UUID()
        let action = NotesBridge.decodeAction([
            "type": "suggestionAction",
            "id": id.uuidString,
            "action": "accept"
        ])
        XCTAssertEqual(action, .suggestionAccepted(id: id))
    }

    func testDecodeSuggestionRejected() {
        let id = UUID()
        let action = NotesBridge.decodeAction([
            "type": "suggestionAction",
            "id": id.uuidString,
            "action": "reject"
        ])
        XCTAssertEqual(action, .suggestionRejected(id: id))
    }

    func testDecodeChoiceSelected() {
        let id = UUID()
        let action = NotesBridge.decodeAction([
            "type": "suggestionAction",
            "id": id.uuidString,
            "action": "choice",
            "choiceIndex": 2
        ])
        XCTAssertEqual(action, .choiceSelected(id: id, index: 2))
    }

    func testDecodeResponse() {
        let id = UUID()
        let action = NotesBridge.decodeAction([
            "type": "suggestionAction",
            "id": id.uuidString,
            "action": "response",
            "responseText": "My custom answer"
        ])
        XCTAssertEqual(action, .response(id: id, text: "My custom answer"))
    }

    func testDecodeKeyCommand() {
        let action = NotesBridge.decodeAction(["type": "keyCommand", "key": "tab"])
        XCTAssertEqual(action, .keyCommand("tab"))
    }

    func testDecodeDismissAsSuggestionRejected() {
        let id = UUID()
        let action = NotesBridge.decodeAction([
            "type": "suggestionAction",
            "id": id.uuidString,
            "action": "dismiss"
        ])
        XCTAssertEqual(action, .suggestionRejected(id: id))
    }

    func testDecodeInvalidTypeReturnsNil() {
        XCTAssertNil(NotesBridge.decodeAction(["type": "unknown"]))
    }

    func testDecodeMissingTypeReturnsNil() {
        XCTAssertNil(NotesBridge.decodeAction(["text": "hello"]))
    }

    func testDecodeInvalidUUIDReturnsNil() {
        XCTAssertNil(NotesBridge.decodeAction([
            "type": "suggestionAction",
            "id": "not-a-uuid",
            "action": "accept"
        ]))
    }

    // MARK: - Round-trip

    func testEncodedSuggestionContainsAllFields() {
        let suggestion = Suggestion(
            type: .append,
            content: .append(text: "New paragraph"),
            reasoning: "Adds context"
        )
        let json = NotesBridge.encodeSuggestions([suggestion])
        XCTAssertTrue(json.contains(suggestion.id.uuidString))
        XCTAssertTrue(json.contains("\"type\":\"append\""))
        XCTAssertTrue(json.contains("New paragraph"))
        XCTAssertTrue(json.contains("Adds context"))
        XCTAssertTrue(json.contains("\"state\":\"pending\""))
    }
}
