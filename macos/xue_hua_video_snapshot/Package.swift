// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xue_hua_video_snapshot",
    platforms: [
        .macOS("10.15"),
    ],
    products: [
        .library(name: "xue-hua-video-snapshot", targets: ["xue_hua_video_snapshot"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "xue_hua_video_snapshot",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it collects user
                // data, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information,
                // see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
