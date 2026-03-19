// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ENTExaminer",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "ENTExaminer",
            path: "ENTExaminer",
            exclude: [
                "Resources/Assets.xcassets",
                "Resources/AppIcon.icns",
                "ENTExaminer.entitlements",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ENTExaminerTests",
            dependencies: ["ENTExaminer"],
            path: "ENTExaminerTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
