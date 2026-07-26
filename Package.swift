// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RekieSekie",
    defaultLocalization: "ja",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.10.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "RekieSekie",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/RekieSekie",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RekieSekieTests",
            dependencies: ["RekieSekie"],
            path: "Tests/RekieSekieTests"
        )
    ]
)
