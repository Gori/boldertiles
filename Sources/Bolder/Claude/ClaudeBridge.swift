import Foundation
import WebKit

/// Bridges JS ↔ Swift communication for the Claude tile.
/// JS sends messages via webkit.messageHandlers.claude.postMessage(...)
/// Swift sends events via window.__bolder__.onEvent(json)
final class ClaudeBridge: NSObject, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private let session: ClaudeSession
    private let onMetaUpdate: (ClaudeMeta) -> Void
    private var meta: ClaudeMeta

    init(webView: WKWebView, session: ClaudeSession, onMetaUpdate: @escaping (ClaudeMeta) -> Void) {
        self.webView = webView
        self.session = session
        self.onMetaUpdate = onMetaUpdate
        self.meta = ClaudeMeta(sessionID: nil, autoApprove: false)
        super.init()

        webView.configuration.userContentController.add(self, name: "claude")
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            // Web UI loaded, start session and send initial state
            session.start()

        case "prompt":
            guard let text = body["text"] as? String else { return }
            let images = body["images"] as? [String]
            session.sendPrompt(text, images: images)

        case "cancel":
            session.cancel()

        case "set_auto_approve":
            guard let enabled = body["enabled"] as? Bool else { return }
            meta.autoApprove = enabled
            onMetaUpdate(meta)
            session.setAutoApprove(enabled)

        default:
            break
        }
    }

    // MARK: - Swift → JS

    /// Send an event to the web UI.
    func sendEvent(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        // Track session ID and auto-approve in meta
        if let type = json["type"] as? String, type == "init" {
            if let sid = json["sessionId"] as? String, !sid.isEmpty {
                meta.sessionID = sid
            }
            if let auto = json["autoApprove"] as? Bool {
                meta.autoApprove = auto
            }
            onMetaUpdate(meta)
        }

        let escaped = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let js = "window.__bolder__ && window.__bolder__.onEvent(JSON.parse('\(escaped)'))"
        webView?.evaluateJavaScript(js) { _, error in
            if let error {
                print("[ClaudeBridge] JS eval error: \(error)")
            }
        }
    }
}
