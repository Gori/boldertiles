import XCTest
@testable import Bolder

final class SuggestionMatcherTests: XCTestCase {

    // MARK: - Single match

    func testSingleOccurrenceFound() {
        let note = "The quick brown fox jumps over the lazy dog."
        let range = SuggestionMatcher.findRange(
            original: "brown fox",
            contextBefore: "quick ",
            contextAfter: " jumps",
            in: note
        )
        XCTAssertNotNil(range)
        XCTAssertEqual(String(note[range!]), "brown fox")
    }

    func testSingleOccurrenceNoContextNeeded() {
        let note = "Hello world"
        let range = SuggestionMatcher.findRange(
            original: "world",
            contextBefore: "",
            contextAfter: "",
            in: note
        )
        XCTAssertNotNil(range)
        XCTAssertEqual(String(note[range!]), "world")
    }

    // MARK: - Duplicates with context disambiguation

    func testDuplicatesDisambiguatedByContextBefore() {
        let note = "AAA foo BBB foo CCC"
        let range = SuggestionMatcher.findRange(
            original: "foo",
            contextBefore: "BBB ",
            contextAfter: " CCC",
            in: note
        )
        XCTAssertNotNil(range)
        // Should match the second "foo"
        let matchStart = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertEqual(matchStart, 12)
    }

    func testDuplicatesDisambiguatedByContextAfter() {
        let note = "foo alpha foo beta"
        let range = SuggestionMatcher.findRange(
            original: "foo",
            contextBefore: "",
            contextAfter: " beta",
            in: note
        )
        XCTAssertNotNil(range)
        let matchStart = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertEqual(matchStart, 10)
    }

    func testThreeOccurrencesPicksMiddle() {
        let note = "X foo Y foo Z foo W"
        let range = SuggestionMatcher.findRange(
            original: "foo",
            contextBefore: "Y ",
            contextAfter: " Z",
            in: note
        )
        XCTAssertNotNil(range)
        let matchStart = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertEqual(matchStart, 8)
    }

    // MARK: - Text not found

    func testTextNotFoundReturnsNil() {
        let note = "Hello world"
        let range = SuggestionMatcher.findRange(
            original: "missing text",
            contextBefore: "",
            contextAfter: "",
            in: note
        )
        XCTAssertNil(range)
    }

    // MARK: - Empty inputs

    func testEmptyOriginalReturnsNil() {
        let range = SuggestionMatcher.findRange(
            original: "",
            contextBefore: "before",
            contextAfter: "after",
            in: "some text"
        )
        XCTAssertNil(range)
    }

    func testEmptyNoteTextReturnsNil() {
        let range = SuggestionMatcher.findRange(
            original: "text",
            contextBefore: "",
            contextAfter: "",
            in: ""
        )
        XCTAssertNil(range)
    }

    func testEmptyContextStillFinds() {
        let note = "only one match here"
        let range = SuggestionMatcher.findRange(
            original: "one match",
            contextBefore: "",
            contextAfter: "",
            in: note
        )
        XCTAssertNotNil(range)
        XCTAssertEqual(String(note[range!]), "one match")
    }

    // MARK: - Unicode

    func testUnicodeTextMatching() {
        let note = "Les fran\u{00E7}ais aiment le caf\u{00E9}. Les fran\u{00E7}ais adorent le vin."
        let range = SuggestionMatcher.findRange(
            original: "fran\u{00E7}ais",
            contextBefore: "",
            contextAfter: " adorent",
            in: note
        )
        XCTAssertNotNil(range)
        XCTAssertEqual(String(note[range!]), "fran\u{00E7}ais")
        // Should be the second occurrence
        let offset = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertGreaterThan(offset, 10)
    }

    func testEmojiContent() {
        let note = "I love \u{1F600} coding and \u{1F600} testing"
        let range = SuggestionMatcher.findRange(
            original: "\u{1F600}",
            contextBefore: "and ",
            contextAfter: " testing",
            in: note
        )
        XCTAssertNotNil(range)
        XCTAssertEqual(String(note[range!]), "\u{1F600}")
    }

    // MARK: - Partial context match

    func testPartialContextBeforeStillDisambiguates() {
        // Context doesn't exactly match (e.g., text was edited slightly) but still helps
        let note = "intro AAA target BBB AAA target CCC"
        let range = SuggestionMatcher.findRange(
            original: "AAA target",
            contextBefore: "BBB ",
            contextAfter: " CCC",
            in: note
        )
        XCTAssertNotNil(range)
        let matchStart = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertEqual(matchStart, 21)
    }

    // MARK: - Context at boundaries

    func testMatchAtStartOfText() {
        let note = "target text follows"
        let range = SuggestionMatcher.findRange(
            original: "target",
            contextBefore: "",
            contextAfter: " text",
            in: note
        )
        XCTAssertNotNil(range)
        let matchStart = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertEqual(matchStart, 0)
    }

    func testMatchAtEndOfText() {
        let note = "prefix target"
        let range = SuggestionMatcher.findRange(
            original: "target",
            contextBefore: "prefix ",
            contextAfter: "",
            in: note
        )
        XCTAssertNotNil(range)
        XCTAssertEqual(String(note[range!]), "target")
    }

    // MARK: - Multiline content

    func testMultilineMatch() {
        let note = "line 1\nthe target phrase\nline 3\nthe target phrase\nline 5"
        let range = SuggestionMatcher.findRange(
            original: "the target phrase",
            contextBefore: "line 3\n",
            contextAfter: "\nline 5",
            in: note
        )
        XCTAssertNotNil(range)
        // Should match the second occurrence
        let matchStart = note.distance(from: note.startIndex, to: range!.lowerBound)
        XCTAssertGreaterThan(matchStart, 20)
    }
}
