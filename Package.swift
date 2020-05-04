// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "HyperProtectSyncSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "HyperProtectSyncSDK",
            targets: ["HyperProtectSyncSDK"]),
    ],
    dependencies: [
        .package(url: "git@github.com:carekit-apple/CareKit.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "HyperProtectSyncSDK",
            dependencies: ["CareKitStore"]),
        .testTarget(
            name: "HyperProtectSyncSDKTests",
            dependencies: ["HyperProtectSyncSDK", "CareKitStore"]),
    ]
)
