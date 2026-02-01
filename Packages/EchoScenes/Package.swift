// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EchoScenes",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "EchoScenes", targets: ["EchoScenes"])
    ],
    dependencies: [
        .package(path: "../EchoEngine"),
        .package(path: "../TwilightEngine")
    ],
    targets: [
        .target(
            name: "EchoScenes",
            dependencies: ["EchoEngine", "TwilightEngine"]
        ),
        .testTarget(
            name: "EchoScenesTests",
            dependencies: ["EchoScenes", "EchoEngine", "TwilightEngine"]
        )
    ]
)
