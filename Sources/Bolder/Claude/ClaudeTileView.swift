import AppKit
import WebKit

/// WKWebView subclass that forwards horizontal scroll gestures to the superview (StripView)
/// so strip-level trackpad swiping works over Claude tiles.
private final class StripPassthroughWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            nextResponder?.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }
}

/// A tile hosting a WKWebView with a React chat UI that communicates with a long-running claude process.
final class ClaudeTileView: NSView, TileContentView, WKNavigationDelegate {
    private let webView: StripPassthroughWebView
    private let debugOverlay = TileDebugOverlay()
    private let projectStore: ProjectStore
    private var tileID: UUID?
    private var session: ClaudeSession?
    private var bridge: ClaudeBridge?
    private var meta: ClaudeMeta = .defaultMeta()

    init(frame frameRect: NSRect, projectStore: ProjectStore) {
        self.projectStore = projectStore

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let m = TileType.claude.contentInsets
        let insetRect = CGRect(
            x: m.left, y: m.bottom,
            width: max(0, frameRect.width - m.left - m.right),
            height: max(0, frameRect.height - m.top - m.bottom)
        )
        let webView = StripPassthroughWebView(frame: insetRect, configuration: config)
        self.webView = webView

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)

        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self

        // Inject error catcher before any page loads
        let errorScript = WKUserScript(
            source: """
            window.__loadError = null;
            window.__jsErrors = [];
            window.onerror = function(msg, url, line, col, err) {
                window.__jsErrors.push(msg + ' at ' + (url||'') + ':' + line + ':' + col);
                return false;
            };
            window.addEventListener('unhandledrejection', function(e) {
                window.__jsErrors.push('unhandled rejection: ' + (e.reason ? e.reason.message || String(e.reason) : 'unknown'));
            });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        webView.configuration.userContentController.addUserScript(errorScript)

        addSubview(webView)
        debugOverlay.install(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        webView.frame = insetContentFrame(bounds)
    }

    private func insetContentFrame(_ rect: NSRect) -> NSRect {
        let m = TileType.claude.contentInsets
        return NSRect(
            x: m.left, y: m.bottom,
            width: max(0, rect.width - m.left - m.right),
            height: max(0, rect.height - m.top - m.bottom)
        )
    }

    // MARK: - TileContentView

    func configure(with tile: TileModel) {
        tileID = tile.id
        meta = projectStore.loadClaudeMeta(for: tile.id) ?? .defaultMeta()

        if session == nil {
            let session = ClaudeSession(
                sessionID: meta.sessionID,
                autoApprove: meta.autoApprove,
                projectURL: projectStore.projectURL
            )
            self.session = session

            let bridge = ClaudeBridge(webView: webView, session: session) { [weak self] updatedMeta in
                guard let self, let id = self.tileID else { return }
                self.meta = updatedMeta
                self.projectStore.saveClaudeMeta(updatedMeta, for: id)
            }
            self.bridge = bridge

            session.onEvent = { [weak bridge] json in
                bridge?.sendEvent(json)
            }
            session.onSessionID = { [weak self] sessionID in
                guard let self, let id = self.tileID else { return }
                self.meta.sessionID = sessionID
                self.projectStore.saveClaudeMeta(self.meta, for: id)
            }

            loadWebUI()
        }

        debugOverlay.setLines(["claude"])
    }

    func activate() {}
    func throttle() {}

    func suspend() {
        // Keep session alive so conversation survives scrolling offscreen
    }

    func resetForReuse() {
        terminateSession()
        tileID = nil
    }

    func setFontSize(_ size: CGFloat) {
        let referenceSize: CGFloat = TileModel.defaultFontSize(for: .claude)
        webView.pageZoom = size / referenceSize
    }

    // MARK: - Session management

    func terminateSession() {
        session?.terminate()
        session = nil
        bridge = nil
    }

    // MARK: - Web UI

    private func loadWebUI() {
        loadBundledUI()
    }

    private func loadBundledUI() {
        if let resourceURL = Bundle.module.resourceURL {
            let claudeUIDir = resourceURL.appendingPathComponent("ClaudeUI")
            let indexURL = claudeUIDir.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: indexURL.path) {
                webView.loadFileURL(indexURL, allowingReadAccessTo: claudeUIDir)
                return
            }
        }

        if let url = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "ClaudeUI") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }

        print("[ClaudeTile] Could not find ClaudeUI resources")
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check for JS errors after page load
        webView.evaluateJavaScript("JSON.stringify(window.__jsErrors)") { result, _ in
            if let json = result as? String, json != "[]" {
                print("[ClaudeTile] JS errors: \(json)")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[ClaudeTile] navigation failed: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[ClaudeTile] provisional navigation failed: \(error)")
    }

    /// The inner web view, for first-responder routing.
    var innerWebView: WKWebView { webView }
}
