// swift-tools-version: 6.2

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(nil),
    .strictMemorySafety(),
]

let package = Package(
    name: "WKViewportCoordinator",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "WKViewportCoordinator",
            targets: ["WKViewportCoordinator"]
        ),
    ],
    targets: [
        .target(
            name: "WKViewportCoordinator",
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "WKViewportCoordinatorTests",
            dependencies: ["WKViewportCoordinator"],
            swiftSettings: strictSwiftSettings
        ),
    ]
)
