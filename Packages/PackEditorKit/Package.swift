// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PackEditorKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PackEditorKit",
            targets: ["PackEditorKit"]
        ),
    ],
    dependencies: [
        .package(path: "../TwilightEngine"),
    ],
    targets: [
        .target(
            name: "PackEditorKit",
            dependencies: [
                .product(name: "TwilightEngine", package: "TwilightEngine"),
                .product(name: "PackAuthoring", package: "TwilightEngine"),
            ],
            path: "Sources/PackEditorKit"
        ),
        .testTarget(
            name: "PackEditorKitTests",
            dependencies: ["PackEditorKit"],
            path: "Tests/PackEditorKitTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
