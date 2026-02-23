import XCTest
@testable import Bolder

// MARK: - Mock ClaudeSession

final class MockClaudeSession: ClaudeSessionProviding {
    var onEvent: (([String: Any]) -> Void)?
    var startCalled = false
    var sentPrompts: [String] = []
    var terminateCalled = false

    /// What to deliver when a prompt is sent.
    var responseJSON: [String: Any]?
    var responseError: String?

    func start() {
        startCalled = true
    }

    func sendPrompt(_ text: String, images: [String]?) {
        sentPrompts.append(text)

        // Simulate response delivery
        if let error = responseError {
            DispatchQueue.main.async {
                self.onEvent?(["type": "error", "message": error])
            }
        } else if let json = responseJSON {
            // Convert JSON to text for accumulation, then send turn_complete
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.onEvent?(["type": "text_delta", "text": text])
                    self.onEvent?(["type": "turn_complete"])
                }
            }
        }
    }

    func terminate() {
        terminateCalled = true
    }
}

// MARK: - Mock MarinationStorage

final class MockMarinationStorage: MarinationStorage {
    var states: [UUID: MarinationState] = [:]
    var noteContents: [UUID: String] = [:]
    var deletedIDs: [UUID] = []

    func loadMarinationState(for tileID: UUID) -> MarinationState? {
        states[tileID]
    }

    func saveMarinationState(_ state: MarinationState, for tileID: UUID) {
        var capped = state
        if capped.history.count > MarinationState.maxHistoryEntries {
            capped.history = Array(capped.history.suffix(MarinationState.maxHistoryEntries))
        }
        states[tileID] = capped
    }

    func deleteMarinationState(for tileID: UUID) {
        states.removeValue(forKey: tileID)
        deletedIDs.append(tileID)
    }

    func loadNoteContent(for tileID: UUID) -> String? {
        noteContents[tileID]
    }
}

// MARK: - Tests

final class MarinationEngineTests: XCTestCase {

    private var storage: MockMarinationStorage!
    private var mockSession: MockClaudeSession!
    private var engine: MarinationEngine!

    override func setUp() {
        super.setUp()
        storage = MockMarinationStorage()
        mockSession = MockClaudeSession()

        let capturedSession = mockSession!
        engine = MarinationEngine(
            storage: storage,
            projectURL: URL(fileURLWithPath: "/tmp/test"),
            sessionProvider: { capturedSession },
            pollInterval: 1,
            idleThreshold: 1,
            maxConsecutiveMarinations: 3,
            minContentLength: 10
        )
    }

    override func tearDown() {
        engine.stop()
        engine = nil
        storage = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Round-robin selection

    func testRoundRobinSelectsOldestMarinated() {
        let noteA = UUID()
        let noteB = UUID()

        storage.noteContents[noteA] = "Long enough content for note A"
        storage.noteContents[noteB] = "Long enough content for note B"

        // noteA was marinated recently, noteB never
        storage.states[noteA] = MarinationState(noteID: noteA, lastMarinatedAt: Date())
        storage.states[noteB] = MarinationState(noteID: noteB, lastMarinatedAt: nil)

        let tileA = TileModel(id: noteA, tileType: .notes, noteStatus: .active)
        let tileB = TileModel(id: noteB, tileType: .notes, noteStatus: .active)
        engine.getTiles = { [tileA, tileB] }

        mockSession.responseJSON = ["suggestions": []]

        engine.tick()

        // Should have sent a prompt (processing noteB since it has no lastMarinatedAt)
        let expectation = XCTestExpectation(description: "Processing completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // noteB should have been processed (it had no lastMarinatedAt → .distantPast)
        XCTAssertNotNil(storage.states[noteB]?.lastMarinatedAt)
    }

    // MARK: - Auto-activation

    func testAutoActivationOnIdle() {
        let noteID = UUID()
        storage.noteContents[noteID] = "Some note content that is long enough"
        storage.states[noteID] = MarinationState(
            noteID: noteID,
            lastUserEditAt: Date(timeIntervalSinceNow: -5) // edited 5 seconds ago (> 1s threshold)
        )

        let tile = TileModel(id: noteID, tileType: .notes, noteStatus: .idle)
        var currentTile = tile
        engine.getTiles = { [currentTile] }
        engine.onStatusChanged = { id, status in
            if id == noteID && status == .active {
                currentTile.noteStatus = .active
            }
        }

        mockSession.responseJSON = ["suggestions": []]
        engine.tick()

        // Should have been activated
        // The onStatusChanged callback should have been called
        let expectation = XCTestExpectation(description: "Auto-activation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Max marinations → waiting

    func testMaxMarinationsTransitionsToWaiting() {
        let noteID = UUID()
        storage.noteContents[noteID] = "Some note content that is long enough"
        storage.states[noteID] = MarinationState(
            noteID: noteID,
            marinationCount: 2 // will become 3 after tick
        )

        let tile = TileModel(id: noteID, tileType: .notes, noteStatus: .active)
        engine.getTiles = { [tile] }

        var statusChanges: [(UUID, NoteStatus)] = []
        engine.onStatusChanged = { id, status in
            statusChanges.append((id, status))
        }

        mockSession.responseJSON = ["suggestions": []]

        engine.tick()

        let expectation = XCTestExpectation(description: "Processing completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Should have changed to waiting (marinationCount reached 3, no accepted history)
        XCTAssertTrue(statusChanges.contains { $0.0 == noteID && $0.1 == .waiting })
    }

    // MARK: - Pause/resume

    func testPausePreventsProcessing() {
        let noteID = UUID()
        storage.noteContents[noteID] = "Long enough note content here"
        let tile = TileModel(id: noteID, tileType: .notes, noteStatus: .active)
        engine.getTiles = { [tile] }

        engine.pauseForActiveClaude()
        engine.tick()

        // No request should be made
        XCTAssertFalse(mockSession.startCalled)
    }

    func testResumeAllowsProcessing() {
        engine.pauseForActiveClaude()
        XCTAssertTrue(engine.isPaused)

        engine.resumeFromActiveClaude()
        XCTAssertFalse(engine.isPaused)
    }

    // MARK: - Non-notes tile ignored

    func testNonNotesTileIgnored() {
        let tileID = UUID()
        let tile = TileModel(id: tileID, tileType: .terminal, noteStatus: .active)
        engine.getTiles = { [tile] }

        engine.tick()
        XCTAssertFalse(mockSession.startCalled)
    }

    // MARK: - Empty note rejected

    func testShortNoteRejectedForProcessing() {
        let noteID = UUID()
        storage.noteContents[noteID] = "Short" // < minContentLength (10)
        let tile = TileModel(id: noteID, tileType: .notes, noteStatus: .active)
        engine.getTiles = { [tile] }

        engine.tick()
        XCTAssertFalse(mockSession.startCalled)
    }

    // MARK: - Accept/reject suggestion

    func testAcceptSuggestionRecordsHistory() {
        let noteID = UUID()
        let suggestion = Suggestion(
            type: .rewrite,
            content: .rewrite(original: "a", replacement: "b", contextBefore: "", contextAfter: ""),
            reasoning: "test"
        )
        storage.states[noteID] = MarinationState(
            noteID: noteID,
            suggestions: [suggestion]
        )

        engine.acceptSuggestion(suggestion.id, for: noteID)

        let state = storage.states[noteID]!
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history[0].outcome, .accepted)
        XCTAssertEqual(state.suggestions[0].state, .accepted)
    }

    func testRejectSuggestionRecordsHistory() {
        let noteID = UUID()
        let suggestion = Suggestion(
            type: .question,
            content: .question(text: "Why?", choices: []),
            reasoning: "test"
        )
        storage.states[noteID] = MarinationState(
            noteID: noteID,
            suggestions: [suggestion]
        )

        engine.rejectSuggestion(suggestion.id, for: noteID)

        let state = storage.states[noteID]!
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history[0].outcome, .rejected)
        XCTAssertEqual(state.suggestions[0].state, .rejected)
    }

    // MARK: - Error handling

    func testCLINotFoundDisablesEngine() {
        let noteID = UUID()
        storage.noteContents[noteID] = "Long enough content here!!"
        let tile = TileModel(id: noteID, tileType: .notes, noteStatus: .active)
        engine.getTiles = { [tile] }

        mockSession.responseError = "Failed to start claude: not found"

        engine.tick()

        let expectation = XCTestExpectation(description: "Error processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(engine.isDisabled)
    }

    // MARK: - Note deleted during processing

    func testNoteDeletedDuringProcessingCleansUp() {
        let noteID = UUID()
        storage.noteContents[noteID] = "Long enough note content here"
        storage.states[noteID] = MarinationState(noteID: noteID)

        var tiles = [TileModel(id: noteID, tileType: .notes, noteStatus: .active)]
        engine.getTiles = { tiles }

        // Remove the tile after the request starts
        mockSession.responseJSON = ["suggestions": []]
        let originalSend = mockSession.sendPrompt
        mockSession.sendPrompt("", images: nil) // trigger to get things moving

        engine.tick()

        // Simulate note being deleted
        tiles = []

        let expectation = XCTestExpectation(description: "Cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(storage.deletedIDs.contains(noteID))
    }
}
