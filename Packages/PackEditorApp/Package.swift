// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PackEditorApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PackEditorApp",
            targets: ["PackEditorApp"]
        ),
    ],
    dependencies: [
        .package(path: "../TwilightEngine"),
        .package(path: "../PackEditorKit"),
    ],
    targets: [
        .target(
            name: "PackEditorApp",
            dependencies: [
                .product(name: "TwilightEngine", package: "TwilightEngine"),
                .product(name: "PackAuthoring", package: "TwilightEngine"),
                .product(name: "PackEditorKit", package: "PackEditorKit"),
            ]
        ),
        .testTarget(
            name: "PackEditorAppTests",
            dependencies: ["PackEditorApp"]
        ),
    ]
)
