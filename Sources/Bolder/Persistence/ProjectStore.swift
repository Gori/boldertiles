import Foundation

/// Reads and writes tile state to `.bolder/tiles.json` within a project directory.
final class ProjectStore {
    let projectURL: URL
    private let bolderDirURL: URL
    private let tilesFileURL: URL
    private let projectFileURL: URL
    private let notesDirURL: URL
    private let terminalDirURL: URL
    private let featuresFileURL: URL
    private let writeQueue = DispatchQueue(label: "com.bolder.persistence", qos: .utility)

    init(projectURL: URL) {
        self.projectURL = projectURL
        self.bolderDirURL = projectURL.appendingPathComponent(".bolder", isDirectory: true)
        self.tilesFileURL = bolderDirURL.appendingPathComponent("tiles.json")
        self.projectFileURL = bolderDirURL.appendingPathComponent("project.json")
        self.notesDirURL = bolderDirURL.appendingPathComponent("notes", isDirectory: true)
        self.terminalDirURL = bolderDirURL.appendingPathComponent("terminal", isDirectory: true)
        self.featuresFileURL = bolderDirURL.appendingPathComponent("features.json")
    }

    /// Load the strip model from disk synchronously.
    func load() -> StripModel? {
        guard FileManager.default.fileExists(atPath: tilesFileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: tilesFileURL)
            let model = try JSONDecoder().decode(StripModel.self, from: data)
            return model
        } catch {
            print("Failed to load tiles.json: \(error)")
            return nil
        }
    }

    /// Save the strip model to disk asynchronously.
    func save(_ model: StripModel) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(model)
            writeQueue.async { [bolderDirURL, tilesFileURL, projectFileURL] in
                do {
                    try FileManager.default.createDirectory(
                        at: bolderDirURL,
                        withIntermediateDirectories: true
                    )
                    try data.write(to: tilesFileURL, options: .atomic)

                    // Write project.json if it doesn't exist
                    if !FileManager.default.fileExists(atPath: projectFileURL.path) {
                        let projectMeta = ProjectMeta(version: 1, createdAt: Date())
                        let metaData = try JSONEncoder().encode(projectMeta)
                        try metaData.write(to: projectFileURL, options: .atomic)
                    }
                } catch {
                    print("Failed to save: \(error)")
                }
            }
        } catch {
            print("Failed to encode model: \(error)")
        }
    }
    // MARK: - Notes persistence

    /// Load note content for a tile (synchronous, called from main thread).
    func loadNoteContent(for tileID: UUID) -> String? {
        let fileURL = notesDirURL.appendingPathComponent("\(tileID.uuidString).md")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }

    /// Save note content for a tile (async on write queue).
    func saveNoteContent(_ content: String, for tileID: UUID) {
        let fileURL = notesDirURL.appendingPathComponent("\(tileID.uuidString).md")
        writeQueue.async { [notesDirURL] in
            do {
                try FileManager.default.createDirectory(at: notesDirURL, withIntermediateDirectories: true)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save note: \(error)")
            }
        }
    }

    /// Delete note content for a tile (async on write queue).
    func deleteNoteContent(for tileID: UUID) {
        let fileURL = notesDirURL.appendingPathComponent("\(tileID.uuidString).md")
        writeQueue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Terminal metadata persistence

    /// Load terminal metadata for a tile.
    func loadTerminalMeta(for tileID: UUID) -> TerminalMeta? {
        let fileURL = terminalDirURL.appendingPathComponent("\(tileID.uuidString).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(TerminalMeta.self, from: data)
    }

    /// Save terminal metadata for a tile.
    func saveTerminalMeta(_ meta: TerminalMeta, for tileID: UUID) {
        let fileURL = terminalDirURL.appendingPathComponent("\(tileID.uuidString).json")
        writeQueue.async { [terminalDirURL] in
            do {
                try FileManager.default.createDirectory(at: terminalDirURL, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(meta)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Failed to save terminal meta: \(error)")
            }
        }
    }

    /// Delete terminal metadata for a tile.
    func deleteTerminalMeta(for tileID: UUID) {
        let fileURL = terminalDirURL.appendingPathComponent("\(tileID.uuidString).json")
        writeQueue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Features persistence

    /// Load the features store from disk synchronously.
    func loadFeatures() -> FeaturesStore {
        guard FileManager.default.fileExists(atPath: featuresFileURL.path),
              let data = try? Data(contentsOf: featuresFileURL),
              let store = try? JSONDecoder().decode(FeaturesStore.self, from: data) else {
            return FeaturesStore()
        }
        return store
    }

    /// Save the features store to disk asynchronously.
    func saveFeatures(_ store: FeaturesStore) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store) else { return }

        writeQueue.async { [bolderDirURL, featuresFileURL] in
            do {
                try FileManager.default.createDirectory(at: bolderDirURL, withIntermediateDirectories: true)
                try data.write(to: featuresFileURL, options: .atomic)
            } catch {
                print("Failed to save features: \(error)")
            }
        }
    }
}

private struct ProjectMeta: Codable {
    let version: Int
    let createdAt: Date
}
