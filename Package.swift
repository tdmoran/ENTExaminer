// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ENTExaminer",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        // Core logic library (testable)
        .target(
            name: "ENTExaminerCore",
            path: "ENTExaminer",
            exclude: [
                "Resources/Assets.xcassets",
                "ENTExaminer.entitlements",
                "App/ENTExaminerApp.swift",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Test runner
        .executableTarget(
            name: "ENTExaminerTests",
            dependencies: ["ENTExaminerCore"],
            path: "Tests"
        ),
    ]
)
