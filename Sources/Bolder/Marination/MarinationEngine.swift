import Foundation

/// Notification names for marination state changes.
extension Notification.Name {
    static let marinationSuggestionsUpdated = Notification.Name("marinationSuggestionsUpdated")
    static let marinationStatusChanged = Notification.Name("marinationStatusChanged")
    static let marinationPhaseChanged = Notification.Name("marinationPhaseChanged")
}

/// Core engine for background note marination. Runs on a timer, picks notes to process,
/// sends them to Claude, and stores the resulting suggestions.
final class MarinationEngine {
    private let storage: MarinationStorage
    private let projectURL: URL
    private var timer: DispatchSourceTimer?
    private var processingNoteID: UUID?
    private var currentRequest: HeadlessClaudeRequest?
    private(set) var isPaused: Bool = false
    private(set) var isDisabled: Bool = false
    private let sessionProvider: (() -> ClaudeSessionProviding)?

    /// Callback to get current tiles from the model.
    var getTiles: (() -> [TileModel])?

    /// Callback to update a tile's noteStatus.
    var onStatusChanged: ((UUID, NoteStatus) -> Void)?

    /// Callback when phase advances for a note. Provides (noteID, newPhase).
    var onPhaseChanged: ((UUID, MarinationPhase) -> Void)?

    // Configuration
    let pollInterval: TimeInterval
    let idleThreshold: TimeInterval
    let maxConsecutiveMarinations: Int
    let minContentLength: Int

    init(
        storage: MarinationStorage,
        projectURL: URL,
        sessionProvider: (() -> ClaudeSessionProviding)? = nil,
        pollInterval: TimeInterval = 45,
        idleThreshold: TimeInterval = 30,
        maxConsecutiveMarinations: Int = 5,
        minContentLength: Int = 50
    ) {
        self.storage = storage
        self.projectURL = projectURL
        self.sessionProvider = sessionProvider
        self.pollInterval = pollInterval
        self.idleThreshold = idleThreshold
        self.maxConsecutiveMarinations = maxConsecutiveMarinations
        self.minContentLength = minContentLength
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        currentRequest?.cancel()
        currentRequest = nil
        processingNoteID = nil
    }

    // MARK: - Manual control

    /// Activate marination for a specific note. Triggers immediate processing.
    func activateNote(_ noteID: UUID) {
        onStatusChanged?(noteID, .active)
        ensureMarinationState(for: noteID)
        // Trigger immediate processing instead of waiting for next timer tick
        DispatchQueue.main.async { [weak self] in
            self?.tick()
        }
    }

    /// Deactivate marination for a specific note, returning to idle.
    func deactivateNote(_ noteID: UUID) {
        onStatusChanged?(noteID, .idle)
    }

    /// Record that the user edited a note — updates lastUserEditAt.
    /// If the note was in `.waiting` state, transitions back to `.idle` and resets marinationCount.
    func noteDidEdit(_ noteID: UUID) {
        var state = storage.loadMarinationState(for: noteID) ?? MarinationState(noteID: noteID)
        state.lastUserEditAt = Date()
        storage.saveMarinationState(state, for: noteID)

        // Waiting → idle when user edits
        if let tiles = getTiles?(),
           let tile = tiles.first(where: { $0.id == noteID }),
           tile.noteStatus == .waiting {
            state.marinationCount = 0
            storage.saveMarinationState(state, for: noteID)
            onStatusChanged?(noteID, .idle)
        }
    }

    /// Pause processing (e.g., when user is on a Claude tile).
    func pauseForActiveClaude() {
        isPaused = true
    }

    /// Resume processing after Claude tile is no longer focused.
    func resumeFromActiveClaude() {
        isPaused = false
    }

    // MARK: - Suggestion actions

    /// Accept a suggestion, recording it in history.
    /// For advancePhase suggestions, advances the phase and resets phaseRoundCount.
    func acceptSuggestion(_ suggestionID: UUID, for noteID: UUID) {
        if var state = storage.loadMarinationState(for: noteID),
           let suggestion = state.suggestions.first(where: { $0.id == suggestionID }) {
            switch suggestion.content {
            case .advancePhase(let nextPhaseStr, _):
                if let nextPhase = MarinationPhase(rawValue: nextPhaseStr) {
                    state.phase = nextPhase
                    state.phaseRoundCount = 0
                    storage.saveMarinationState(state, for: noteID)
                    onPhaseChanged?(noteID, nextPhase)
                }
            default:
                break
            }
        }
        resolveSuggestion(suggestionID, for: noteID, outcome: .accepted)
    }

    /// Reject a suggestion, recording it in history.
    func rejectSuggestion(_ suggestionID: UUID, for noteID: UUID) {
        resolveSuggestion(suggestionID, for: noteID, outcome: .rejected)
    }

    // MARK: - Tick (processing loop)

    func tick() {
        guard !isPaused, !isDisabled, processingNoteID == nil else { return }

        guard let tiles = getTiles?() else { return }

        // Auto-activation: check idle notes that qualify
        autoActivateIdleNotes(tiles: tiles)

        // Find active notes to process
        let activeNotes = tiles.filter { $0.tileType == .notes && $0.noteStatus == .active }
        guard !activeNotes.isEmpty else { return }

        // Pick the note with the oldest lastMarinatedAt (round-robin)
        let noteToProcess = activeNotes.min { a, b in
            let stateA = storage.loadMarinationState(for: a.id)
            let stateB = storage.loadMarinationState(for: b.id)
            let dateA = stateA?.lastMarinatedAt ?? .distantPast
            let dateB = stateB?.lastMarinatedAt ?? .distantPast
            return dateA < dateB
        }

        guard let note = noteToProcess else { return }

        // Check note content exists and meets minimum length
        guard let content = storage.loadNoteContent(for: note.id),
              content.count >= minContentLength else { return }

        processNote(note.id, content: content)
    }

    // MARK: - Private

    private func autoActivateIdleNotes(tiles: [TileModel]) {
        let now = Date()
        for tile in tiles where tile.tileType == .notes && tile.noteStatus == .idle {
            guard let content = storage.loadNoteContent(for: tile.id),
                  content.count >= minContentLength else { continue }

            let state = storage.loadMarinationState(for: tile.id)
            if let lastEdit = state?.lastUserEditAt,
               now.timeIntervalSince(lastEdit) >= idleThreshold {
                // Set status directly without triggering immediate tick (avoids recursion)
                onStatusChanged?(tile.id, .active)
                ensureMarinationState(for: tile.id)
            }
        }
    }

    private func processNote(_ noteID: UUID, content: String) {
        processingNoteID = noteID

        var state = storage.loadMarinationState(for: noteID) ?? MarinationState(noteID: noteID)
        let prompt = buildPrompt(noteContent: content, state: state)

        let request = HeadlessClaudeRequest(projectURL: projectURL, sessionProvider: sessionProvider)
        self.currentRequest = request

        request.send(prompt: prompt, expectJSON: true) { [weak self] result in
            guard let self else { return }

            // Check note still exists
            guard let tiles = self.getTiles?(),
                  tiles.contains(where: { $0.id == noteID }) else {
                self.processingNoteID = nil
                self.currentRequest = nil
                self.storage.deleteMarinationState(for: noteID)
                return
            }

            switch result {
            case .json(let json):
                let newSuggestions = self.parseSuggestions(from: json)
                print("[MarinationEngine] Parsed \(newSuggestions.count) suggestions for note \(noteID)")
                for s in newSuggestions {
                    print("[MarinationEngine]   - \(s.type.rawValue): \(s.reasoning.prefix(80))")
                }
                // Merge: keep existing pending suggestions, add new ones, cap at 8
                let existingPending = state.suggestions.filter { $0.state == .pending }
                var merged = existingPending + newSuggestions
                if merged.count > 8 {
                    // Expire oldest beyond cap
                    let overflow = merged.count - 8
                    for i in 0..<overflow {
                        merged[i].state = .expired
                    }
                    merged = Array(merged.dropFirst(overflow))
                }
                state.suggestions = merged
                state.lastMarinatedAt = Date()
                state.marinationCount += 1
                state.phaseRoundCount += 1
                self.storage.saveMarinationState(state, for: noteID)

                // Pass suggestions directly in notification to avoid race with async disk write
                NotificationCenter.default.post(
                    name: .marinationSuggestionsUpdated,
                    object: nil,
                    userInfo: ["noteID": noteID, "suggestions": merged]
                )

                // Check if we should transition to waiting
                if state.marinationCount >= self.maxConsecutiveMarinations {
                    let hasAccepted = state.history.contains { $0.outcome == .accepted }
                    if !hasAccepted {
                        self.onStatusChanged?(noteID, .waiting)
                    }
                }

            case .text(let text):
                print("[MarinationEngine] Unexpected text response for note \(noteID): \(text.prefix(200))")

            case .error(let msg):
                print("[MarinationEngine] Error for note \(noteID): \(msg)")
                if msg.contains("Failed to start") || msg.contains("not found") {
                    self.isDisabled = true
                    print("[MarinationEngine] Disabling — Claude CLI not available")
                }
            }

            self.processingNoteID = nil
            self.currentRequest = nil
        }
    }

    private func buildPrompt(noteContent: String, state: MarinationState) -> String {
        let projectName = projectURL.lastPathComponent
        let phase = state.phase

        var prompt = """
        You are a sharp thinking partner embedded in a builder's workspace for "\(projectName)". \
        You have full access to the project codebase via your working directory.

        The user writes rough notes — ideas, plans, design explorations, strategy. \
        Your job is to apply strategic pressure to push the thinking forward.

        Rules:
        - Do NOT fix grammar or polish prose.
        - Do NOT be generic. If the idea is vague, rewrite it narrower and sharper.
        - Do NOT ask open-ended questions. Ask pointed ones that force a decision.
        - When the user is stuck, propose a concrete direction instead of asking what they want.
        - Surface hidden assumptions. Name the riskiest one.
        - Force tradeoffs. If everything is "important", require elimination.
        - Match the user's voice. Be concise. Be occasionally provocative. Never fluffy.

        Current phase: \(phase.rawValue.uppercased()) (round \(state.phaseRoundCount + 1))

        \(phaseInstruction(for: phase))

        Return ONLY valid JSON (no markdown fences) with a "suggestions" array.

        Each suggestion MUST have ALL of:
        - "type": one of "rewrite", "append", "insert", "compression", "question", "critique", "promote", "advancePhase"
        - "reasoning": 1-2 sentences on why this helps (REQUIRED — suggestions without this are dropped)

        Additional fields per type:
        - "rewrite"/"compression": "original" (exact text from the note), "replacement", "contextBefore" (~50 chars before), "contextAfter" (~50 chars after)
        - "append": "text" to add at the end
        - "insert": "text" to insert, "afterContext" (~50 chars of text it follows)
        - "question": "text" — a pointed question, "choices" — array of 2-4 concrete options. Always include choices.
        - "critique": "severity" (strong/weak/cut/rethink), "targetText" (exact text from note), "critiqueText" (your critique), "contextBefore" (~50 chars), "contextAfter" (~50 chars)
        - "promote": "title" and "description" for a concrete, actionable feature
        - "advancePhase": "nextPhase" (the phase to advance to), "reasoning" (why this phase is complete)

        Suggest 2-4 things. Mix types — a rewrite AND a critique is better than two rewrites. Questions must always have concrete choices.
        If you believe this phase's work is done, include an "advancePhase" suggestion alongside your other suggestions.

        --- NOTE ---
        \(noteContent)
        --- END NOTE ---
        """

        let history = state.recentHistory
        if !history.isEmpty {
            prompt += "\n\n--- HISTORY ---\n"
            for entry in history {
                prompt += "- \(entry.suggestion.type.rawValue) (\(entry.outcome.rawValue)): \(entry.suggestion.reasoning)\n"
            }
            prompt += "--- END HISTORY ---\n"
            prompt += "\nUser has seen the above. Don't repeat rejected suggestions. Build on accepted ones. Try a different angle or escalate pressure."
        }

        return prompt
    }

    private func phaseInstruction(for phase: MarinationPhase) -> String {
        switch phase {
        case .ingest:
            return """
            PHASE: INGEST — Extract the Core Vector

            Your goal: extract who benefits, what changes, why now, and what assumption is embedded.
            Then rewrite the idea in sharper, more strategic framings.

            Tactics:
            - Use "rewrite" to reframe the idea — cost-reduction tool, leverage multiplier, compounding engine, etc.
            - Use "question" to force clarity: "Who specifically benefits?" "What changes for them tomorrow?"
            - Use "critique" with severity "weak" to call out vague language that hides assumptions.
            - If the idea is scattered, use "compression" to find the core vector.
            - Do NOT expand yet. Sharpen first.

            When the core intent is clear and the idea has been reframed at least once, suggest "advancePhase" with nextPhase "expand".
            """

        case .expand:
            return """
            PHASE: EXPAND — Generate Structured Contrast

            Your goal: expand the idea across strategic axes, then force elimination.

            Axes to explore:
            - Narrow vs Broad audience
            - Manual-first vs Fully automated
            - Workflow tool vs Outcome tool
            - Fast to ship vs Hard to copy

            Tactics:
            - Use "insert" or "append" to add contrasting directions the user hasn't considered.
            - Use "question" to force elimination: "You have two directions here. Kill one."
            - Use "critique" with severity "cut" to mark directions that should be eliminated.
            - Use "rewrite" to sharpen a chosen direction after elimination.
            - Expansion without elimination is drift. Push for cuts.

            When the user has explored alternatives and eliminated at least one direction, suggest "advancePhase" with nextPhase "shape".
            """

        case .shape:
            return """
            PHASE: SHAPE — Define Product Character

            Your goal: extract the product's identity — core loop, signature move, non-goals.

            Tactics:
            - Use "question" to surface character: "What's the one thing this does that nothing else does?"
            - Use "question" to define non-goals: "Name two things this product will NOT optimize."
            - Use "insert" to add missing pieces: dependency surface, core loop definition, signature interaction.
            - Use "critique" with severity "rethink" to challenge assumptions about product identity.
            - Use "compression" to tighten bloated descriptions into product character.
            - This phase is about character, not features. Push away from feature lists.

            When core loop, signature move, and non-goals are defined, suggest "advancePhase" with nextPhase "scope".
            """

        case .scope:
            return """
            PHASE: SCOPE — Apply Constraint Pressure

            Your goal: ruthlessly scope the idea through constraint filters.

            Three pressure filters:
            1. Solo Reality Filter — What can be built in 14 days by one person?
            2. Signal Filter — Which single feature proves this idea works?
            3. Regret Filter — What would you regret excluding?

            Tactics:
            - Use "question" to apply each filter directly.
            - Use "rewrite" to cut scope — rewrite the idea as a 1-feature product.
            - Use "critique" with severity "cut" to mark features that don't survive the filters.
            - Use "compression" to eliminate everything that doesn't survive two filters.
            - Use "insert" to add a concrete MVP definition.
            - Features must survive at least two filters. Be disciplined.

            When the scope is tight and an MVP is defined, suggest "advancePhase" with nextPhase "commit".
            """

        case .commit:
            return """
            PHASE: COMMIT — Define Forward Motion

            Your goal: convert the shaped, scoped idea into testable action.

            The output should include:
            - 3 testable claims about the product
            - 1 risky bet (the thing that might not work)
            - 1 fast validation path (how to test in days, not weeks)
            - 1 thing to manually fake before building
            - 1 thing to ignore for 30 days

            Tactics:
            - Use "insert" or "append" to add testable claims and validation paths.
            - Use "question" to surface the risky bet: "What's the one thing that could kill this?"
            - Use "critique" with severity "strong" to affirm commitments that are solid and testable.
            - Use "rewrite" to sharpen vague commitments into concrete actions.
            - When the idea is sharp, differentiated, scoped, and has a forward path, use "promote" to extract it as a feature.
            - Do NOT suggest "advancePhase" — this is the final phase. Use "promote" when the idea is ready.
            """
        }
    }

    private func parseSuggestions(from json: [String: Any]) -> [Suggestion] {
        guard let suggestionsArray = json["suggestions"] as? [[String: Any]] else { return [] }

        return suggestionsArray.compactMap { dict -> Suggestion? in
            guard let typeStr = dict["type"] as? String,
                  let type = SuggestionType(rawValue: typeStr),
                  let reasoning = dict["reasoning"] as? String else { return nil }

            let content: SuggestionContent?
            switch type {
            case .rewrite:
                guard let original = dict["original"] as? String,
                      let replacement = dict["replacement"] as? String else { return nil }
                content = .rewrite(
                    original: original,
                    replacement: replacement,
                    contextBefore: dict["contextBefore"] as? String ?? "",
                    contextAfter: dict["contextAfter"] as? String ?? ""
                )
            case .append:
                guard let text = dict["text"] as? String else { return nil }
                content = .append(text: text)
            case .insert:
                guard let text = dict["text"] as? String else { return nil }
                content = .insert(text: text, afterContext: dict["afterContext"] as? String ?? "")
            case .compression:
                guard let original = dict["original"] as? String,
                      let replacement = dict["replacement"] as? String else { return nil }
                content = .compression(
                    original: original,
                    replacement: replacement,
                    contextBefore: dict["contextBefore"] as? String ?? "",
                    contextAfter: dict["contextAfter"] as? String ?? ""
                )
            case .question:
                guard let text = dict["text"] as? String else { return nil }
                let choices = dict["choices"] as? [String] ?? []
                content = .question(text: text, choices: choices)
            case .critique:
                guard let severityStr = dict["severity"] as? String,
                      let severity = CritiqueSeverity(rawValue: severityStr),
                      let targetText = dict["targetText"] as? String,
                      let critiqueText = dict["critiqueText"] as? String else { return nil }
                content = .critique(
                    severity: severity,
                    targetText: targetText,
                    critiqueText: critiqueText,
                    contextBefore: dict["contextBefore"] as? String ?? "",
                    contextAfter: dict["contextAfter"] as? String ?? ""
                )
            case .promote:
                guard let title = dict["title"] as? String,
                      let description = dict["description"] as? String else { return nil }
                content = .promote(title: title, description: description)
            case .advancePhase:
                guard let nextPhase = dict["nextPhase"] as? String else { return nil }
                content = .advancePhase(nextPhase: nextPhase, reasoning: dict["reasoning"] as? String ?? "")
            }

            guard let c = content else { return nil }
            return Suggestion(type: type, content: c, reasoning: reasoning)
        }
    }

    private func resolveSuggestion(_ suggestionID: UUID, for noteID: UUID, outcome: SuggestionOutcome) {
        guard var state = storage.loadMarinationState(for: noteID) else { return }

        guard let index = state.suggestions.firstIndex(where: { $0.id == suggestionID }) else { return }
        let suggestion = state.suggestions[index]

        state.suggestions[index].state = outcome == .accepted ? .accepted : .rejected
        state.addHistoryEntry(MarinationEntry(suggestion: suggestion, outcome: outcome, timestamp: Date()))

        storage.saveMarinationState(state, for: noteID)

        NotificationCenter.default.post(
            name: .marinationSuggestionsUpdated,
            object: nil,
            userInfo: ["noteID": noteID]
        )
    }

    private func ensureMarinationState(for noteID: UUID) {
        if storage.loadMarinationState(for: noteID) == nil {
            let state = MarinationState(noteID: noteID)
            storage.saveMarinationState(state, for: noteID)
        }
    }
}
