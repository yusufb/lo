// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "lo",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "LoCore"),
        .executableTarget(
            name: "lo",
            dependencies: ["LoCore"]
        ),
        .testTarget(
            name: "LoCoreTests",
            dependencies: ["LoCore"]
        ),
    ]
)
