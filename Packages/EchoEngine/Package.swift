// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EchoEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "EchoEngine", targets: ["EchoEngine"])
    ],
    dependencies: [
        .package(path: "../ThirdParty/FirebladeECS"),
        .package(path: "../TwilightEngine")
    ],
    targets: [
        .target(
            name: "EchoEngine",
            dependencies: [
                .product(name: "FirebladeECS", package: "FirebladeECS"),
                "TwilightEngine"
            ]
        ),
        .testTarget(
            name: "EchoEngineTests",
            dependencies: ["EchoEngine", "TwilightEngine"]
        )
    ]
)
