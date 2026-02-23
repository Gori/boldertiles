import Foundation

/// A single-turn headless Claude request. Sends a prompt, accumulates the response,
/// and delivers the result on turn completion. Handles JSON fence stripping, error events,
/// and timeout. DRY helper used by FeatureExtractor and MarinationEngine.
final class HeadlessClaudeRequest {
    enum Result {
        case text(String)
        case json([String: Any])
        case error(String)
    }

    private var session: ClaudeSessionProviding?
    private var accumulatedText = ""
    private var completion: ((Result) -> Void)?
    private var expectJSON: Bool = false
    private var timeoutWorkItem: DispatchWorkItem?
    private let projectURL: URL
    private let sessionProvider: (() -> ClaudeSessionProviding)?

    /// - Parameters:
    ///   - projectURL: The project directory for the Claude session.
    ///   - sessionProvider: Optional factory for custom session (for testing). If nil, uses `ClaudeSession`.
    init(projectURL: URL, sessionProvider: (() -> ClaudeSessionProviding)? = nil) {
        self.projectURL = projectURL
        self.sessionProvider = sessionProvider
    }

    deinit {
        cancel()
    }

    /// Send a prompt and receive the result via completion handler.
    /// - Parameters:
    ///   - prompt: The text prompt to send.
    ///   - expectJSON: If true, attempts to parse the response as JSON.
    ///   - timeout: Timeout in seconds (default 120).
    ///   - completion: Called on main thread with the result.
    func send(prompt: String, expectJSON: Bool = false, timeout: TimeInterval = 120, completion: @escaping (Result) -> Void) {
        self.completion = completion
        self.expectJSON = expectJSON
        self.accumulatedText = ""

        let session: ClaudeSessionProviding
        if let provider = sessionProvider {
            session = provider()
        } else {
            // Background headless requests use autoApprove since there's no user to approve permissions
            session = ClaudeSession(sessionID: nil, autoApprove: true, projectURL: projectURL)
        }
        self.session = session

        session.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }

        session.start()

        // Set up timeout
        let timeoutItem = DispatchWorkItem { [weak self] in
            print("[HeadlessClaudeRequest] timed out after \(timeout)s")
            self?.finish(.error("Request timed out"))
        }
        self.timeoutWorkItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

        // Small delay to let the session initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak session] in
            session?.sendPrompt(prompt, images: nil)
        }
    }

    /// Cancel the in-flight request.
    func cancel() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        session?.terminate()
        session = nil
        completion = nil
    }

    // MARK: - Event handling

    private func handleEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "text_delta":
            if let text = event["text"] as? String {
                accumulatedText += text
            }

        case "turn_complete":
            let text = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[HeadlessClaudeRequest] turn_complete, \(text.count) chars: \(text.prefix(300))")
            if expectJSON {
                if let parsed = parseJSON(from: text) {
                    print("[HeadlessClaudeRequest] JSON parsed OK, keys: \(parsed.keys.sorted())")
                    finish(.json(parsed))
                } else {
                    finish(.error("Failed to parse JSON from response: \(text.prefix(300))"))
                }
            } else {
                finish(.text(text))
            }

        case "error":
            let msg = event["message"] as? String ?? "Unknown error"
            print("[HeadlessClaudeRequest] error: \(msg)")
            finish(.error(msg))

        case "init":
            print("[HeadlessClaudeRequest] session initialized")

        default:
            break
        }
    }

    private func finish(_ result: Result) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        session?.terminate()
        session = nil
        let callback = completion
        completion = nil
        callback?(result)
    }

    /// Strip markdown JSON fences and parse as dictionary.
    private func parseJSON(from text: String) -> [String: Any]? {
        var cleaned = text
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}
