import AppKit
import GhosttyKit

/// Singleton managing the ghostty_app_t lifetime and runtime callbacks.
final class GhosttyBridge {
    static let shared = GhosttyBridge()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?

    private var initialized = false

    private init() {}

    func initialize() {
        guard !initialized else { return }
        initialized = true

        // Initialize the ghostty library
        ghostty_init(0, nil)

        // Create and finalize config
        guard let cfg = ghostty_config_new() else {
            print("Warning: Failed to create GhosttyKit config")
            return
        }
        ghostty_config_load_default_files(cfg)
        ghostty_config_finalize(cfg)
        self.config = cfg

        // Set up runtime callbacks
        var runtime = ghostty_runtime_config_s()
        runtime.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtime.supports_selection_clipboard = false
        runtime.wakeup_cb = { userdata in
            DispatchQueue.main.async {
                guard let ud = userdata else { return }
                let bridge = Unmanaged<GhosttyBridge>.fromOpaque(ud).takeUnretainedValue()
                bridge.tick()
            }
        }
        runtime.action_cb = { app, target, action in
            // Handle actions from the terminal (title changes, bells, etc.)
            // Return false for unhandled actions
            return false
        }
        runtime.read_clipboard_cb = { userdata, location, state in
            // Read from system clipboard
            guard let state else { return }
            let pasteboard = NSPasteboard.general
            let content = pasteboard.string(forType: .string) ?? ""
            content.withCString { ptr in
                // Complete the clipboard request on the surface that asked for it
            }
        }
        runtime.confirm_read_clipboard_cb = nil
        runtime.write_clipboard_cb = { userdata, location, content, len, confirm in
            // Write to system clipboard
            guard let content, len > 0 else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            // Each content entry has mime + data
            for i in 0..<len {
                let entry = content[i]
                if let data = entry.data {
                    pasteboard.setString(String(cString: data), forType: .string)
                }
            }
        }
        runtime.close_surface_cb = { userdata, processAlive in
            // Surface wants to close — we handle this via tile removal
        }

        guard let ghosttyApp = ghostty_app_new(&runtime, cfg) else {
            print("Warning: Failed to initialize GhosttyKit app")
            return
        }
        self.app = ghosttyApp
    }

    /// Tick the app (process pending work). Called from wakeup callback.
    private func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    /// Read the terminal background color from Ghostty config.
    var backgroundColor: CGColor {
        guard let config else { return CGColor(red: 0, green: 0, blue: 0, alpha: 1) }
        var color = ghostty_config_color_s()
        let key = "background"
        if ghostty_config_get(config, &color, key, UInt(key.utf8.count)) {
            return CGColor(
                red: CGFloat(color.r) / 255,
                green: CGFloat(color.g) / 255,
                blue: CGFloat(color.b) / 255,
                alpha: 1
            )
        }
        return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    func shutdown() {
        if let app {
            ghostty_app_free(app)
            self.app = nil
        }
        if let config {
            ghostty_config_free(config)
            self.config = nil
        }
        initialized = false
    }
}
