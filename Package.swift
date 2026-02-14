// swift-tools-version: 5.10

import PackageDescription
import Foundation

// Resolve path relative to Package.swift location
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let ghosttyKitAvailable = FileManager.default.fileExists(
    atPath: "\(packageDir)/Frameworks/GhosttyKit.xcframework/Info.plist"
)

var targets: [Target] = [
    .executableTarget(
        name: "Bolder",
        dependencies: ghosttyKitAvailable ? ["GhosttyKit"] : [],
        path: "Sources/Bolder",
        resources: [],
        swiftSettings: ghosttyKitAvailable ? [.define("GHOSTTY_AVAILABLE")] : [],
        linkerSettings: ghosttyKitAvailable ? [
            .linkedFramework("Metal"),
            .linkedFramework("QuartzCore"),
            .linkedFramework("CoreFoundation"),
            .linkedFramework("CoreGraphics"),
            .linkedFramework("CoreText"),
            .linkedFramework("CoreVideo"),
            .linkedFramework("IOSurface"),
            .linkedFramework("Carbon"),
            .linkedLibrary("c++"),
        ] : []
    ),
    .testTarget(
        name: "BolderTests",
        dependencies: ["Bolder"],
        path: "Tests/BolderTests"
    ),
]

if ghosttyKitAvailable {
    targets.append(
        .binaryTarget(
            name: "GhosttyKit",
            path: "Frameworks/GhosttyKit.xcframework"
        )
    )
}

let package = Package(
    name: "Bolder",
    platforms: [.macOS(.v14)],
    targets: targets
)
