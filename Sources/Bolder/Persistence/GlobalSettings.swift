import Foundation

/// Manages global application settings stored in ~/Library/Application Support/Bolder/.
struct GlobalSettings: Codable {
    var windowRestoreEnabled: Bool = true
    var shortcuts: [String: KeyBinding]?

    static let settingsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bolderDir = appSupport.appendingPathComponent("Bolder", isDirectory: true)
        return bolderDir.appendingPathComponent("settings.json")
    }()

    static func load() -> GlobalSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return GlobalSettings()
        }
        do {
            let data = try Data(contentsOf: settingsURL)
            return try JSONDecoder().decode(GlobalSettings.self, from: data)
        } catch {
            return GlobalSettings()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let dir = GlobalSettings.settingsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try encoder.encode(self)
            try data.write(to: GlobalSettings.settingsURL, options: .atomic)
        } catch {
            print("Failed to save global settings: \(error)")
        }
    }
}
