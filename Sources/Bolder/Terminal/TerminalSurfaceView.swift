import AppKit
#if GHOSTTY_AVAILABLE
import GhosttyKit
#endif

/// NSView that hosts a Ghostty terminal surface.
/// The Zig/C layer manages Metal rendering internally — it receives this NSView
/// and sets up the CAMetalLayer itself.
final class TerminalSurfaceView: NSView {
    #if GHOSTTY_AVAILABLE
    var surface: ghostty_surface_t?
    #endif

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    #if GHOSTTY_AVAILABLE
    /// Create and attach a Ghostty surface to this view.
    func createSurface(workingDirectory: String?) {
        guard let app = GhosttyBridge.shared.app else { return }
        guard surface == nil else { return }

        var config = ghostty_surface_config_new()
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(
                nsview: Unmanaged.passUnretained(self).toOpaque()
            )
        )
        config.scale_factor = Double(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0)
        config.font_size = 0 // use default from config

        if let cwd = workingDirectory {
            cwd.withCString { ptr in
                config.working_directory = ptr
                self.surface = ghostty_surface_new(app, &config)
            }
        } else {
            surface = ghostty_surface_new(app, &config)
        }

        if let surface {
            // Set initial size
            let scaledSize = convertToBacking(bounds.size)
            ghostty_surface_set_size(surface, UInt32(scaledSize.width), UInt32(scaledSize.height))
            ghostty_surface_set_focus(surface, window?.isKeyWindow ?? false)
        }
    }

    /// Destroy the surface.
    func destroySurface() {
        if let surface {
            ghostty_surface_free(surface)
            self.surface = nil
        }
    }

    // MARK: - Size

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard let surface else { return }
        let scaledSize = convertToBacking(NSRect(origin: .zero, size: newSize)).size
        ghostty_surface_set_size(surface, UInt32(scaledSize.width), UInt32(scaledSize.height))
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let surface else { return }
        let fbFrame = convertToBacking(frame)
        let xScale = fbFrame.size.width / frame.size.width
        let yScale = fbFrame.size.height / frame.size.height
        ghostty_surface_set_content_scale(surface, xScale, yScale)
    }

    // MARK: - Focus

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { surface.map { ghostty_surface_set_focus($0, true) } }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { surface.map { ghostty_surface_set_focus($0, false) } }
        return result
    }

    // MARK: - Keyboard input

    override func keyDown(with event: NSEvent) {
        guard let surface else { super.keyDown(with: event); return }

        var keyEv = ghostty_input_key_s()
        keyEv.action = GHOSTTY_ACTION_PRESS
        keyEv.keycode = UInt32(event.keyCode)
        keyEv.mods = Self.ghosttyMods(event.modifierFlags)
        keyEv.consumed_mods = Self.ghosttyMods(event.modifierFlags.subtracting([.control, .command]))
        keyEv.composing = false

        if let chars = event.characters, let _ = chars.unicodeScalars.first {
            chars.withCString { ptr in
                keyEv.text = ptr
                ghostty_surface_key(surface, keyEv)
            }
        } else {
            keyEv.text = nil
            ghostty_surface_key(surface, keyEv)
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let surface else { super.keyUp(with: event); return }

        var keyEv = ghostty_input_key_s()
        keyEv.action = GHOSTTY_ACTION_RELEASE
        keyEv.keycode = UInt32(event.keyCode)
        keyEv.mods = Self.ghosttyMods(event.modifierFlags)
        keyEv.text = nil
        ghostty_surface_key(surface, keyEv)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface else { super.flagsChanged(with: event); return }

        var keyEv = ghostty_input_key_s()
        keyEv.action = GHOSTTY_ACTION_PRESS
        keyEv.keycode = UInt32(event.keyCode)
        keyEv.mods = Self.ghosttyMods(event.modifierFlags)
        keyEv.text = nil
        ghostty_surface_key(surface, keyEv)
    }

    // MARK: - Mouse input

    override func mouseDown(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, mods)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, mods)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = Self.ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, mods)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        let mods = Self.ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_pos(surface, pos.x, frame.height - pos.y, mods)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        let mods = Self.ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_pos(surface, pos.x, frame.height - pos.y, mods)
    }

    // Scroll gesture direction detection
    private enum ScrollDirection { case undecided, horizontal, vertical }
    private var scrollDirection: ScrollDirection = .undecided
    private var scrollAccumX: CGFloat = 0
    private var scrollAccumY: CGFloat = 0
    private let scrollDirectionThreshold: CGFloat = 4.0

    override func scrollWheel(with event: NSEvent) {
        // Reset on gesture start
        if event.phase == .began {
            scrollDirection = .undecided
            scrollAccumX = 0
            scrollAccumY = 0
            // Always forward .began so the strip can reset its state
            nextResponder?.scrollWheel(with: event)
            return
        }

        // Forward end/cancel to strip
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            nextResponder?.scrollWheel(with: event)
            scrollDirection = .undecided
            return
        }

        // Ignore momentum
        guard event.momentumPhase == [] else { return }

        // Determine direction if still undecided
        if scrollDirection == .undecided {
            scrollAccumX += abs(event.scrollingDeltaX)
            scrollAccumY += abs(event.scrollingDeltaY)

            if scrollAccumX >= scrollDirectionThreshold || scrollAccumY >= scrollDirectionThreshold {
                scrollDirection = scrollAccumX > scrollAccumY ? .horizontal : .vertical
            } else {
                return // Buffer until threshold reached
            }
        }

        if scrollDirection == .horizontal {
            nextResponder?.scrollWheel(with: event)
        } else {
            guard let surface else { return }
            var x = event.scrollingDeltaX
            var y = event.scrollingDeltaY
            if event.hasPreciseScrollingDeltas {
                x *= 2; y *= 2
            }
            var mods: ghostty_input_scroll_mods_t = 0
            if event.hasPreciseScrollingDeltas {
                mods |= 1 // precision bit
            }
            ghostty_surface_mouse_scroll(surface, x, y, mods)
        }
    }

    // MARK: - Modifier translation

    private static func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods: UInt32 = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(mods)
    }
    #endif
}
