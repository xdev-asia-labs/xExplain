// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xExplain",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Library that can be imported by xInsight, xInsight Dev, xThermal
        .library(
            name: "xExplain",
            targets: ["xExplain"]
        ),
        // CLI executable for terminal usage
        .executable(
            name: "xExplain-CLI",
            targets: ["xExplain-CLI"]
        ),
    ],
    dependencies: [
        // No external dependencies - pure Swift for maximum compatibility
    ],
    targets: [
        .target(
            name: "xExplain",
            dependencies: [],
            path: "Sources/xExplain"
        ),
        .executableTarget(
            name: "xExplain-CLI",
            dependencies: ["xExplain"],
            path: "Sources/xExplain-CLI"
        ),
        .testTarget(
            name: "xExplainTests",
            dependencies: ["xExplain"],
            path: "Tests/xExplainTests"
        ),
    ]
)
