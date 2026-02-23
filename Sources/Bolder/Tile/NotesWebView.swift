import AppKit
import WebKit

/// WKWebView subclass that forwards horizontal scroll gestures to the superview (StripView)
/// so strip-level trackpad swiping works over notes tiles.
private final class StripPassthroughWebView: WKWebView {
    /// Extra menu items appended to WebKit's default context menu.
    var extraMenuItems: [NSMenuItem] = []

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            nextResponder?.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if !extraMenuItems.isEmpty {
            menu.addItem(.separator())
            for item in extraMenuItems {
                menu.addItem(item.copy() as! NSMenuItem)
            }
        }
        super.willOpenMenu(menu, with: event)
    }
}

/// WKWebView wrapper for the Notes editor. Loads the React + CodeMirror UI
/// and bridges messages between Swift and JavaScript.
final class NotesWebView: NSView, WKNavigationDelegate {
    private let _webView: StripPassthroughWebView

    /// The underlying WKWebView, for first-responder routing.
    var webView: WKWebView { _webView }
    private var isLoaded = false
    private var pendingCalls: [String] = []

    /// Called when the web UI sends a message to Swift.
    var onAction: ((NotesBridge.BridgeAction) -> Void)?

    /// Extra items appended to the WebKit context menu.
    var extraMenuItems: [NSMenuItem] {
        get { _webView.extraMenuItems }
        set { _webView.extraMenuItems = newValue }
    }

    override init(frame frameRect: NSRect) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let wv = StripPassthroughWebView(frame: CGRect(origin: .zero, size: frameRect.size), configuration: config)
        self._webView = wv

        super.init(frame: frameRect)
        wantsLayer = true

        wv.setValue(false, forKey: "drawsBackground")
        wv.navigationDelegate = self
        wv.autoresizingMask = [.width, .height]

        // Set up message handler via a forwarding delegate
        let handler = MessageHandler { [weak self] body in
            self?.handleMessage(body)
        }
        wv.configuration.userContentController.add(handler, name: "bolder")

        // Disable magnification
        wv.allowsMagnification = false

        addSubview(wv)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        _webView.frame = bounds
    }

    // MARK: - Load

    func loadUI() {
        guard let resourceURL = Bundle.module.resourceURL else {
            print("[NotesWebView] No Bundle.module.resourceURL")
            return
        }
        let notesUIDir = resourceURL.appendingPathComponent("NotesUI")
        let indexURL = notesUIDir.appendingPathComponent("index.html")
        print("[NotesWebView] loadUI: \(indexURL.path)")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            print("[NotesWebView] NotesUI/index.html not found at \(indexURL.path)")
            return
        }
        // List assets dir for debugging
        let assetsDir = notesUIDir.appendingPathComponent("assets")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: assetsDir.path) {
            print("[NotesWebView] Assets: \(files.prefix(5))... (\(files.count) total)")
        }
        _webView.loadFileURL(indexURL, allowingReadAccessTo: notesUIDir)
        print("[NotesWebView] loadFileURL called")
    }

    // MARK: - Swift → JS

    func setContent(_ text: String) {
        evaluateBridgeEvent(NotesBridge.encodeSetContent(text))
    }

    func displaySuggestions(_ suggestions: [Suggestion]) {
        evaluateBridgeEvent(NotesBridge.encodeSuggestions(suggestions))
    }

    func removeSuggestion(id: UUID) {
        evaluateBridgeEvent(NotesBridge.encodeRemoveSuggestion(id: id))
    }

    func clearSuggestions() {
        evaluateBridgeEvent(NotesBridge.encodeClearSuggestions())
    }

    func setFontSize(_ size: CGFloat) {
        evaluateBridgeEvent(NotesBridge.encodeSetFontSize(size))
    }

    func setEditable(_ editable: Bool) {
        evaluateBridgeEvent(NotesBridge.encodeSetEditable(editable))
    }

    func focusEditor() {
        evaluateBridgeEvent(NotesBridge.encodeFocus())
    }

    // MARK: - JS evaluation

    private func evaluateBridgeEvent(_ json: String) {
        guard isLoaded else {
            print("[NotesWebView] queuing (not loaded): \(json.prefix(80))...")
            pendingCalls.append(json)
            return
        }
        sendToJS(json)
    }

    private func sendToJS(_ json: String) {
        let escaped = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let js = "window.__bolder__ && window.__bolder__.onEvent(JSON.parse('\(escaped)'))"
        print("[NotesWebView] sendToJS: \(json.prefix(80))...")
        _webView.evaluateJavaScript(js) { result, error in
            if let error {
                print("[NotesWebView] JS error: \(error)")
            } else {
                print("[NotesWebView] JS result: \(String(describing: result))")
            }
        }
    }

    private func flushPendingCalls() {
        print("[NotesWebView] flushing \(pendingCalls.count) pending calls")
        let calls = pendingCalls
        pendingCalls.removeAll()
        for json in calls {
            sendToJS(json)
        }
    }

    // MARK: - JS → Swift

    private func handleMessage(_ body: Any) {
        print("[NotesWebView] handleMessage: \(body)")
        guard let dict = body as? [String: Any],
              let action = NotesBridge.decodeAction(dict) else {
            print("[NotesWebView] failed to decode message")
            return
        }
        print("[NotesWebView] decoded action: \(action)")
        onAction?(action)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[NotesWebView] didFinish navigation — isLoaded=true, pending=\(pendingCalls.count)")
        isLoaded = true
        flushPendingCalls()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[NotesWebView] navigation failed: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[NotesWebView] provisional navigation failed: \(error)")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[NotesWebView] didStartProvisionalNavigation")
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Block external link navigation
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - Message handler (avoids retain cycle)

private final class MessageHandler: NSObject, WKScriptMessageHandler {
    let handler: (Any) -> Void

    init(handler: @escaping (Any) -> Void) {
        self.handler = handler
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        handler(message.body)
    }
}
