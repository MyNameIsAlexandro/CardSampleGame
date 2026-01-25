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
                .copy("Resources/CoreHeroes")
            ]
        ),
    ]
)
