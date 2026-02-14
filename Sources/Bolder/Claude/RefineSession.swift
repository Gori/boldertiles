import Foundation

/// A headless 2-turn Claude session that refines note text.
/// Turn 1: Asks clarifying questions about the note.
/// Turn 2: Rewrites the note based on user answers.
final class RefineSession {
    enum State {
        case idle
        case askingQuestions
        case waitingForAnswers(questions: String)
        case refining
        case complete(refinedText: String)
        case failed(String)
    }

    private(set) var state: State = .idle
    var onStateChange: ((State) -> Void)?

    private var session: ClaudeSession?
    private var accumulatedText = ""
    private let projectURL: URL

    init(projectURL: URL) {
        self.projectURL = projectURL
    }

    deinit {
        cancel()
    }

    /// Start refining: sends the note text to Claude to get clarifying questions.
    func start(noteText: String) {
        accumulatedText = ""
        let session = ClaudeSession(sessionID: nil, autoApprove: false, projectURL: projectURL)
        self.session = session

        session.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }

        session.start()

        let prompt = """
        I have the following feature idea written as a note. Please read it and the codebase context, then ask me 2-4 clarifying questions that would help refine this into a better, more complete feature description. Only output the questions, numbered.

        --- NOTE ---
        \(noteText)
        --- END NOTE ---
        """

        state = .askingQuestions
        onStateChange?(state)

        // Small delay to let the session initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            session.sendPrompt(prompt)
        }
    }

    /// Submit user answers to get the refined text.
    func submitAnswers(_ answers: String, originalNoteText: String) {
        accumulatedText = ""

        let prompt = """
        Here are my answers to your questions:

        \(answers)

        Now rewrite the original note as a clear, well-structured feature description. Return ONLY the refined text, no preamble or explanation.

        --- ORIGINAL NOTE ---
        \(originalNoteText)
        --- END ORIGINAL NOTE ---
        """

        state = .refining
        onStateChange?(state)
        session?.sendPrompt(prompt)
    }

    func cancel() {
        session?.terminate()
        session = nil
    }

    // MARK: - Event handling

    private func handleEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "text_delta":
            if let text = event["text"] as? String {
                accumulatedText += text
                // Notify for streaming preview during refine phase
                if case .refining = state {
                    onStateChange?(.refining)
                }
            }

        case "turn_complete":
            switch state {
            case .askingQuestions:
                let questions = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                state = .waitingForAnswers(questions: questions)
                onStateChange?(state)

            case .refining:
                let refined = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                state = .complete(refinedText: refined)
                onStateChange?(state)

            default:
                break
            }

        case "error":
            let msg = event["message"] as? String ?? "Unknown error"
            state = .failed(msg)
            onStateChange?(state)

        default:
            break
        }
    }

    /// Access the accumulated text during streaming for preview.
    var streamingText: String { accumulatedText }
}
