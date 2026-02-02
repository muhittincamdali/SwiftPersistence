// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftPersistence",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "SwiftPersistence",
            targets: ["SwiftPersistence"]
        )
    ],
    targets: [
        .target(
            name: "SwiftPersistence",
            path: "Sources/SwiftPersistence"
        ),
        .testTarget(
            name: "SwiftPersistenceTests",
            dependencies: ["SwiftPersistence"],
            path: "Tests/SwiftPersistenceTests"
        )
    ]
)
