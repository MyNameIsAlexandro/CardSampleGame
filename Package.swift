// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CardSampleGame",
    platforms: [
        .iOS(.v16)
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
            sources: [
                "CardGameApp.swift",
                "ContentView.swift",
                "Models",
                "Views",
                "Data"
            ]
        )
    ]
)
