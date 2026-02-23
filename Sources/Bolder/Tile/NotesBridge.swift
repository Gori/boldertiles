import Foundation

/// Pure encoding/decoding layer for the Notes WKWebView bridge.
/// Testable without WebKit — converts between Swift types and JSON.
enum NotesBridge {

    // MARK: - Encoding (Swift → JS)

    /// Encode a setContent event.
    static func encodeSetContent(_ text: String) -> String {
        let escaped = jsonEscape(text)
        return #"{"type":"setContent","text":"\#(escaped)"}"#
    }

    /// Encode suggestions for display.
    static func encodeSuggestions(_ suggestions: [Suggestion]) -> String {
        let items = suggestions.map { encodeSuggestion($0) }
        return #"{"type":"setSuggestions","suggestions":[\#(items.joined(separator: ","))]}"#
    }

    /// Encode a removeSuggestion event.
    static func encodeRemoveSuggestion(id: UUID) -> String {
        #"{"type":"removeSuggestion","id":"\#(id.uuidString)"}"#
    }

    /// Encode a clearSuggestions event.
    static func encodeClearSuggestions() -> String {
        #"{"type":"clearSuggestions"}"#
    }

    /// Encode a setFontSize event.
    static func encodeSetFontSize(_ size: CGFloat) -> String {
        #"{"type":"setFontSize","size":\#(Int(size))}"#
    }

    /// Encode a setEditable event.
    static func encodeSetEditable(_ editable: Bool) -> String {
        #"{"type":"setEditable","editable":\#(editable)}"#
    }

    /// Encode a focus event.
    static func encodeFocus() -> String {
        #"{"type":"focus"}"#
    }

    // MARK: - Decoding (JS → Swift)

    /// Decode an incoming message from JS into a typed action.
    static func decodeAction(_ body: [String: Any]) -> BridgeAction? {
        guard let type = body["type"] as? String else { return nil }

        switch type {
        case "contentChanged":
            guard let text = body["text"] as? String else { return nil }
            return .contentChanged(text: text)

        case "suggestionAction":
            guard let id = body["id"] as? String,
                  let uuid = UUID(uuidString: id),
                  let action = body["action"] as? String else { return nil }

            switch action {
            case "accept":
                return .suggestionAccepted(id: uuid)
            case "reject", "dismiss":
                return .suggestionRejected(id: uuid)
            case "choice":
                guard let index = body["choiceIndex"] as? Int else { return nil }
                return .choiceSelected(id: uuid, index: index)
            case "response":
                guard let text = body["responseText"] as? String else { return nil }
                return .response(id: uuid, text: text)
            default:
                return nil
            }

        case "keyCommand":
            guard let key = body["key"] as? String else { return nil }
            return .keyCommand(key)

        case "ready":
            return .ready

        default:
            return nil
        }
    }

    // MARK: - Types

    /// Actions decoded from JS messages.
    enum BridgeAction: Equatable {
        case contentChanged(text: String)
        case suggestionAccepted(id: UUID)
        case suggestionRejected(id: UUID)
        case choiceSelected(id: UUID, index: Int)
        case response(id: UUID, text: String)
        case keyCommand(String)
        case ready
    }

    // MARK: - Private encoding helpers

    private static func encodeSuggestion(_ s: Suggestion) -> String {
        let contentJSON = encodeSuggestionContent(s.content)
        let iso = ISO8601DateFormatter()
        let dateStr = iso.string(from: s.createdAt)
        let reasonEscaped = jsonEscape(s.reasoning)

        return """
        {"id":"\(s.id.uuidString)","type":"\(s.type.rawValue)","content":\(contentJSON),"reasoning":"\(reasonEscaped)","createdAt":"\(dateStr)","state":"\(s.state.rawValue)"}
        """
    }

    private static func encodeSuggestionContent(_ content: SuggestionContent) -> String {
        switch content {
        case .rewrite(let original, let replacement, let contextBefore, let contextAfter):
            return """
            {"type":"rewrite","original":"\(jsonEscape(original))","replacement":"\(jsonEscape(replacement))","contextBefore":"\(jsonEscape(contextBefore))","contextAfter":"\(jsonEscape(contextAfter))"}
            """
        case .append(let text):
            return #"{"type":"append","text":"\#(jsonEscape(text))"}"#
        case .insert(let text, let afterContext):
            return #"{"type":"insert","text":"\#(jsonEscape(text))","afterContext":"\#(jsonEscape(afterContext))"}"#
        case .compression(let original, let replacement, let contextBefore, let contextAfter):
            return """
            {"type":"compression","original":"\(jsonEscape(original))","replacement":"\(jsonEscape(replacement))","contextBefore":"\(jsonEscape(contextBefore))","contextAfter":"\(jsonEscape(contextAfter))"}
            """
        case .question(let text, let choices):
            let choicesJSON = choices.map { #""\#(jsonEscape($0))""# }.joined(separator: ",")
            return #"{"type":"question","text":"\#(jsonEscape(text))","choices":[\#(choicesJSON)]}"#
        case .critique(let severity, let targetText, let critiqueText, let contextBefore, let contextAfter):
            return """
            {"type":"critique","severity":"\(severity.rawValue)","targetText":"\(jsonEscape(targetText))","critiqueText":"\(jsonEscape(critiqueText))","contextBefore":"\(jsonEscape(contextBefore))","contextAfter":"\(jsonEscape(contextAfter))"}
            """
        case .promote(let title, let description):
            return #"{"type":"promote","title":"\#(jsonEscape(title))","description":"\#(jsonEscape(description))"}"#
        case .advancePhase(let nextPhase, let reasoning):
            return #"{"type":"advancePhase","nextPhase":"\#(jsonEscape(nextPhase))","reasoning":"\#(jsonEscape(reasoning))"}"#
        }
    }

    private static func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
         .replacingOccurrences(of: "\t", with: "\\t")
    }
}
