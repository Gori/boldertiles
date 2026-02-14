import Foundation

/// A headless 1-turn Claude session that extracts a structured Feature from note text.
final class FeatureExtractor {
    var onComplete: ((Feature?) -> Void)?

    private var session: ClaudeSession?
    private var accumulatedText = ""
    private let projectURL: URL

    init(projectURL: URL) {
        self.projectURL = projectURL
    }

    deinit {
        cancel()
    }

    /// Extract a Feature from the given note text.
    func extract(noteText: String, noteID: UUID) {
        accumulatedText = ""
        let session = ClaudeSession(sessionID: nil, autoApprove: false, projectURL: projectURL)
        self.session = session

        session.onEvent = { [weak self] event in
            self?.handleEvent(event, noteID: noteID)
        }

        session.start()

        let prompt = """
        Convert the following note into a structured feature. Return ONLY valid JSON with these fields:
        - "title": a concise title (max ~60 chars)
        - "description": a clear description of the feature
        - "status": one of "draft", "planned", "inProgress", "done", "cancelled"

        Do not wrap the JSON in markdown code fences. Return raw JSON only.

        --- NOTE ---
        \(noteText)
        --- END NOTE ---
        """

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            session.sendPrompt(prompt)
        }
    }

    func cancel() {
        session?.terminate()
        session = nil
    }

    // MARK: - Event handling

    private func handleEvent(_ event: [String: Any], noteID: UUID) {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "text_delta":
            if let text = event["text"] as? String {
                accumulatedText += text
            }

        case "turn_complete":
            let feature = parseFeature(from: accumulatedText, noteID: noteID)
            session?.terminate()
            session = nil
            onComplete?(feature)

        case "error":
            print("[FeatureExtractor] Error: \(event["message"] as? String ?? "unknown")")
            session?.terminate()
            session = nil
            onComplete?(nil)

        default:
            break
        }
    }

    private func parseFeature(from text: String, noteID: UUID) -> Feature? {
        // Strip markdown fences defensively
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let description = json["description"] as? String else {
            print("[FeatureExtractor] Failed to parse JSON from: \(text.prefix(200))")
            return nil
        }

        let statusString = json["status"] as? String ?? "draft"
        let status = FeatureStatus(rawValue: statusString) ?? .draft

        return Feature(
            title: title,
            description: description,
            status: status,
            sourceNoteID: noteID
        )
    }
}
