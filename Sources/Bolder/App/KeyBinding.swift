import AppKit

/// Actions that can be bound to keyboard shortcuts.
enum ShortcutAction: String, CaseIterable, Codable {
    case focusLeft
    case focusRight
    case moveTileLeft
    case moveTileRight
    case shrinkTile
    case growTile
    case toggleFullWidth
    case addNotesTile
    case addTerminalTile
    case addClaudeTile
    case removeTile
    case toggleFullscreen
    case fontSizeUp
    case fontSizeDown
    case addFeaturesTile
    case refineNote
    case saveAsFeature

    var displayName: String {
        switch self {
        case .focusLeft:       return "Focus Left"
        case .focusRight:      return "Focus Right"
        case .moveTileLeft:    return "Move Tile Left"
        case .moveTileRight:   return "Move Tile Right"
        case .shrinkTile:      return "Shrink Tile"
        case .growTile:        return "Grow Tile"
        case .toggleFullWidth: return "Toggle Full/Half"
        case .addNotesTile:    return "Add Notes Tile"
        case .addTerminalTile: return "Add Terminal Tile"
        case .addClaudeTile:   return "Add Claude Tile"
        case .removeTile:      return "Remove Tile"
        case .toggleFullscreen: return "Toggle Fullscreen"
        case .fontSizeUp:      return "Increase Font Size"
        case .fontSizeDown:    return "Decrease Font Size"
        case .addFeaturesTile: return "Add Features Tile"
        case .refineNote:      return "Refine with Claude"
        case .saveAsFeature:   return "Save as Feature"
        }
    }

    static let defaults: [ShortcutAction: KeyBinding] = [
        .focusLeft:       KeyBinding(key: "left", option: true),
        .focusRight:      KeyBinding(key: "right", option: true),
        .moveTileLeft:    KeyBinding(key: "left", shift: true, option: true),
        .moveTileRight:   KeyBinding(key: "right", shift: true, option: true),
        .shrinkTile:      KeyBinding(key: "-", option: true),
        .growTile:        KeyBinding(key: "=", option: true),
        .toggleFullWidth: KeyBinding(key: "h", option: true),
        .addNotesTile:    KeyBinding(key: "n", command: true, shift: true),
        .addTerminalTile: KeyBinding(key: "t", command: true),
        .addClaudeTile:   KeyBinding(key: "n", command: true),
        .removeTile:      KeyBinding(key: "w", command: true),
        .toggleFullscreen: KeyBinding(key: "f", command: true),
        .fontSizeUp:      KeyBinding(key: "=", command: true),
        .fontSizeDown:    KeyBinding(key: "-", command: true),
        .addFeaturesTile: KeyBinding(key: "f", command: true, shift: true),
        .refineNote:      KeyBinding(key: "r", command: true, shift: true),
        .saveAsFeature:   KeyBinding(key: "s", command: true, shift: true),
    ]
}

/// A keyboard shortcut binding.
struct KeyBinding: Codable, Equatable {
    let key: String
    var command: Bool = false
    var shift: Bool = false
    var option: Bool = false
    var control: Bool = false

    /// Maps special key names to their keyCodes.
    static let specialKeyCodes: [String: UInt16] = [
        "left": 123,
        "right": 124,
        "up": 126,
        "down": 125,
        "delete": 51,
        "forwarddelete": 117,
        "escape": 53,
        "tab": 48,
        "return": 36,
        "space": 49,
    ]

    /// Checks whether this binding matches the given key event.
    func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let wantCommand = command
        let wantShift = shift
        let wantOption = option
        let wantControl = control

        guard flags.contains(.command) == wantCommand,
              flags.contains(.shift) == wantShift,
              flags.contains(.option) == wantOption,
              flags.contains(.control) == wantControl else {
            return false
        }

        if let expectedCode = KeyBinding.specialKeyCodes[key] {
            return event.keyCode == expectedCode
        }

        return event.charactersIgnoringModifiers?.lowercased() == key.lowercased()
    }

    /// Human-readable display string, e.g. "⌘⇧←".
    var displayString: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option  { parts.append("⌥") }
        if shift   { parts.append("⇧") }
        if command { parts.append("⌘") }

        let keyDisplay: String
        switch key.lowercased() {
        case "left":  keyDisplay = "←"
        case "right": keyDisplay = "→"
        case "up":    keyDisplay = "↑"
        case "down":  keyDisplay = "↓"
        case "space": keyDisplay = "Space"
        case "tab":   keyDisplay = "⇥"
        case "return": keyDisplay = "⏎"
        case "delete": keyDisplay = "⌫"
        case "escape": keyDisplay = "⎋"
        default:       keyDisplay = key.uppercased()
        }
        parts.append(keyDisplay)
        return parts.joined()
    }

    /// Converts to NSMenuItem key equivalent format.
    var menuKeyEquivalent: (String, NSEvent.ModifierFlags) {
        var flags: NSEvent.ModifierFlags = []
        if command { flags.insert(.command) }
        if shift   { flags.insert(.shift) }
        if option  { flags.insert(.option) }
        if control { flags.insert(.control) }

        let equiv: String
        switch key.lowercased() {
        case "left":  equiv = String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
        case "right": equiv = String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))
        case "up":    equiv = String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        case "down":  equiv = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        case "delete": equiv = String(Character(UnicodeScalar(NSDeleteFunctionKey)!))
        case "escape": equiv = String(Character(UnicodeScalar(27)))
        case "tab":   equiv = "\t"
        case "return": equiv = "\r"
        case "space": equiv = " "
        default:      equiv = key.lowercased()
        }
        return (equiv, flags)
    }

    /// Construct a KeyBinding from a captured NSEvent.
    static func from(_ event: NSEvent) -> KeyBinding {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check if it's a special key by keyCode
        let keyName: String
        let reverseMap = Dictionary(uniqueKeysWithValues: specialKeyCodes.map { ($0.value, $0.key) })
        if let special = reverseMap[event.keyCode] {
            keyName = special
        } else {
            keyName = event.charactersIgnoringModifiers?.lowercased() ?? ""
        }

        return KeyBinding(
            key: keyName,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
    }
}
