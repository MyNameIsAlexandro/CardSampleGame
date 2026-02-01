// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EchoEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "EchoEngine", targets: ["EchoEngine"])
    ],
    dependencies: [
        .package(url: "https://github.com/fireblade-engine/ecs.git", from: "0.17.5"),
        .package(path: "../TwilightEngine")
    ],
    targets: [
        .target(
            name: "EchoEngine",
            dependencies: [
                .product(name: "FirebladeECS", package: "ecs"),
                "TwilightEngine"
            ]
        ),
        .testTarget(
            name: "EchoEngineTests",
            dependencies: ["EchoEngine", "TwilightEngine"]
        )
    ]
)
