// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TwilightEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TwilightEngine",
            targets: ["TwilightEngine"]
        ),
    ],
    targets: [
        .target(
            name: "TwilightEngine",
            dependencies: [],
            path: "Sources/TwilightEngine"
        ),
        .testTarget(
            name: "TwilightEngineTests",
            dependencies: ["TwilightEngine"],
            path: "Tests/TwilightEngineTests"
        ),
    ]
)
