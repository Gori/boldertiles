import AppKit
import CoreText

/// Registers all .ttc fonts from the Fonts/ directory at app startup.
enum FontLoader {
    static func registerFonts() {
        // Try to find Fonts/ relative to the executable
        let executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let execDir = executablePath.deletingLastPathComponent()

        var fontsDir: URL?
        // Walk up from the executable directory checking each level
        var dir = execDir
        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("Fonts")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                fontsDir = candidate
                break
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }

        guard let fontsDir else {
            print("[FontLoader] Fonts/ directory not found (searched up from \(execDir.path))")
            return
        }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: fontsDir,
            includingPropertiesForKeys: nil
        ) else {
            print("[FontLoader] Could not list Fonts/ directory")
            return
        }

        var registered = 0
        for file in files where file.pathExtension == "ttc" || file.pathExtension == "ttf" || file.pathExtension == "otf" {
            var errorRef: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(file as CFURL, .process, &errorRef) {
                registered += 1
            } else {
                let error = errorRef?.takeRetainedValue()
                let code = error.map { CFErrorGetCode($0) } ?? 0
                if code != 105 { // 105 = already registered
                    print("[FontLoader] Failed to register \(file.lastPathComponent): \(String(describing: error))")
                }
            }
        }
        print("[FontLoader] Registered \(registered) font files from \(fontsDir.path)")
    }

    /// Create a JetBrains Mono font (variable), falling back to system monospace.
    static func jetBrainsMono(size: CGFloat, weight: NSFont.Weight = .regular, italic: Bool = false) -> NSFont {
        let familyName = "JetBrains Mono"
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: familyName,
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue],
        ])
        let finalDescriptor = italic
            ? descriptor.withSymbolicTraits(.italic)
            : descriptor
        let font = NSFont(descriptor: finalDescriptor, size: size)
        if font?.familyName == familyName {
            return font!
        }
        print("[FontLoader] JetBrains Mono not found, using system monospace")
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

}
