// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreHeroes",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CoreHeroesContent",
            targets: ["CoreHeroesContent"]
        ),
    ],
    targets: [
        .target(
            name: "CoreHeroesContent",
            resources: [
                // Compiled binary pack (fast loading, compressed) - used at runtime
                .copy("Resources/CoreHeroes.pack"),
                // JSON source directory - for PackLoader tests and content authoring
                .copy("Resources/CoreHeroes")
            ]
        ),
    ]
)
