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
        .library(
            name: "PackAuthoring",
            targets: ["PackAuthoring"]
        ),
        .executable(
            name: "pack-compiler",
            targets: ["PackCompilerTool"]
        ),
    ],
    targets: [
        .target(
            name: "TwilightEngine",
            dependencies: [],
            path: "Sources/TwilightEngine"
        ),
        .target(
            name: "TwilightEngineDevTools",
            dependencies: ["TwilightEngine"],
            path: "Sources/TwilightEngineDevTools"
        ),
        .target(
            name: "PackAuthoring",
            dependencies: ["TwilightEngine"],
            path: "Sources/PackAuthoring"
        ),
        .executableTarget(
            name: "PackCompilerTool",
            dependencies: ["PackAuthoring"],
            path: "Sources/PackCompilerTool"
        ),
        .testTarget(
            name: "TwilightEngineTests",
            dependencies: ["TwilightEngine", "TwilightEngineDevTools"],
            path: "Tests/TwilightEngineTests",
            resources: [
                .process("Fixtures/Replay")
            ]
        ),
        .testTarget(
            name: "PackAuthoringTests",
            dependencies: ["PackAuthoring", "TwilightEngine"],
            path: "Tests/PackAuthoringTests"
        ),
    ]
)
