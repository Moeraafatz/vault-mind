// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaultMind",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "VaultMindCore", targets: ["VaultMindCore"]),
        .library(name: "VaultMindUI", targets: ["VaultMindUI"]),
        .executable(name: "VaultMind", targets: ["VaultMind"]),
        .executable(name: "VaultMindTools", targets: ["VaultMindTools"])
    ],
    targets: [
        .target(
            name: "VaultMindCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Accelerate"),
                .linkedFramework("PDFKit"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreServices"),
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "VaultMindUI",
            dependencies: ["VaultMindCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "VaultMind",
            dependencies: ["VaultMindCore", "VaultMindUI"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "VaultMindTools",
            dependencies: ["VaultMindCore", "VaultMindUI"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "VaultMindTests",
            dependencies: ["VaultMindCore", "VaultMindUI"]
        )
    ]
)
