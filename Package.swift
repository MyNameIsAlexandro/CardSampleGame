// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CardSampleGame",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CardSampleGame",
            targets: ["CardSampleGame"])
    ],
    targets: [
        .target(
            name: "CardSampleGame",
            path: ".",
            exclude: ["CardSampleGameTests", "CardSampleGame.xcodeproj", "CardSampleGame.entitlements"],
            sources: [
                "CardGameApp.swift",
                "ContentView.swift",
                "Models",
                "Views",
                "Data",
                "Helpers"
            ]
        ),
        .testTarget(
            name: "CardSampleGameTests",
            dependencies: ["CardSampleGame"],
            path: "CardSampleGameTests"
        )
    ]
)
