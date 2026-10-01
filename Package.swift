// swift-tools-version: 6.3

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(nil),
    .strictMemorySafety(),
]

let package = Package(
    name: "WKViewportCoordinator",
    platforms: [
        .iOS("18.4")
    ],
    products: [
        .library(
            name: "WKViewportCoordinator",
            targets: ["WKViewportCoordinator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lynnswap/ABIBridge.git", .upToNextMinor(from: "0.5.1")),
    ],
    targets: [
        .target(
            name: "WKViewportCoordinator",
            dependencies: [.product(name: "ABIBridge", package: "ABIBridge")],
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "WKViewportCoordinatorTests",
            dependencies: ["WKViewportCoordinator"],
            swiftSettings: strictSwiftSettings
        ),
    ]
)
