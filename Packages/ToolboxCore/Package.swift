// swift-tools-version: 5.7
// SPDX-License-Identifier: MIT
// ToolboxCore: pure logic (no AppKit where avoidable), testable via `swift test`.

import PackageDescription

let package = Package(
    name: "ToolboxCore",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "ToolboxCore", targets: ["ToolboxCore"]),
    ],
    targets: [
        .target(name: "ToolboxCore", path: "Sources/ToolboxCore"),
        .testTarget(name: "ToolboxCoreTests", dependencies: ["ToolboxCore"], path: "Tests/ToolboxCoreTests"),
    ]
)
