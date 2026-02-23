import Foundation

/// A headless 1-turn Claude session that extracts a structured Feature from note text.
/// Uses HeadlessClaudeRequest for the heavy lifting.
final class FeatureExtractor {
    var onComplete: ((Feature?) -> Void)?

    private var request: HeadlessClaudeRequest?
    private let projectURL: URL

    init(projectURL: URL) {
        self.projectURL = projectURL
    }

    deinit {
        cancel()
    }

    /// Extract a Feature from the given note text.
    func extract(noteText: String, noteID: UUID) {
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

        let request = HeadlessClaudeRequest(projectURL: projectURL)
        self.request = request

        request.send(prompt: prompt, expectJSON: true) { [weak self] result in
            guard let self else { return }
            self.request = nil

            switch result {
            case .json(let json):
                let feature = self.parseFeature(from: json, noteID: noteID)
                self.onComplete?(feature)
            case .text, .error:
                self.onComplete?(nil)
            }
        }
    }

    func cancel() {
        request?.cancel()
        request = nil
    }

    private func parseFeature(from json: [String: Any], noteID: UUID) -> Feature? {
        guard let title = json["title"] as? String,
              let description = json["description"] as? String else {
            print("[FeatureExtractor] Missing required fields in JSON")
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
