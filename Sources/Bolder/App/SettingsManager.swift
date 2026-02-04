import Foundation

/// Manages keyboard shortcut settings with global and project-level scoping.
final class SettingsManager {
    static let shared = SettingsManager()

    static let settingsDidChangeNotification = Notification.Name("SettingsDidChange")

    enum Scope: Int {
        case global = 0
        case project = 1
    }

    private(set) var shortcuts: [ShortcutAction: KeyBinding] = ShortcutAction.defaults
    private(set) var activeScope: Scope = .global
    private var projectURL: URL?

    private init() {}

    // MARK: - File paths

    private static var globalSettingsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bolderDir = appSupport.appendingPathComponent("Bolder", isDirectory: true)
        return bolderDir.appendingPathComponent("settings.json")
    }

    private func projectSettingsURL(for url: URL) -> URL {
        url.appendingPathComponent(".bolder", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    // MARK: - Load

    /// Load settings. Project settings override global, which override defaults.
    func load(projectURL: URL) {
        self.projectURL = projectURL

        // Start with defaults
        var resolved = ShortcutAction.defaults

        // Layer global settings
        if let global = Self.loadFile(at: Self.globalSettingsURL) {
            for (action, binding) in global {
                resolved[action] = binding
            }
        }

        // Layer project settings (highest priority)
        let projectFile = projectSettingsURL(for: projectURL)
        if let project = Self.loadFile(at: projectFile) {
            activeScope = .project
            for (action, binding) in project {
                resolved[action] = binding
            }
        } else {
            activeScope = .global
        }

        shortcuts = resolved
    }

    // MARK: - Save

    func save(_ newShortcuts: [ShortcutAction: KeyBinding], scope: Scope, projectURL: URL? = nil) {
        let url: URL
        switch scope {
        case .global:
            url = Self.globalSettingsURL
        case .project:
            guard let project = projectURL ?? self.projectURL else { return }
            url = projectSettingsURL(for: project)
        }

        let dict = Dictionary(uniqueKeysWithValues: newShortcuts.map { ($0.key.rawValue, $0.value) })
        let wrapper = SettingsFile(shortcuts: dict)

        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(wrapper)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }

        shortcuts = newShortcuts
        activeScope = scope
        NotificationCenter.default.post(name: Self.settingsDidChangeNotification, object: self)
    }

    /// Reset shortcuts to defaults and save.
    func resetToDefaults(scope: Scope, projectURL: URL? = nil) {
        save(ShortcutAction.defaults, scope: scope, projectURL: projectURL)
    }

    // MARK: - Private helpers

    private static func loadFile(at url: URL) -> [ShortcutAction: KeyBinding]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let wrapper = try JSONDecoder().decode(SettingsFile.self, from: data)
            var result: [ShortcutAction: KeyBinding] = [:]
            for (key, binding) in wrapper.shortcuts {
                if let action = ShortcutAction(rawValue: key) {
                    result[action] = binding
                }
            }
            return result.isEmpty ? nil : result
        } catch {
            print("Failed to load settings from \(url.path): \(error)")
            return nil
        }
    }
}

/// On-disk format for settings files.
private struct SettingsFile: Codable {
    let shortcuts: [String: KeyBinding]
}
