// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "CareKitHyperProtectSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "CareKitHyperProtectSDK",
            targets: ["CareKitHyperProtectSDK"]),
    ],
    dependencies: [
        .package(url: "git@github.com:carekit-apple/CareKit-Private.git", .branch("ibm-hyperprotect-sdk")),
        .package(url: "git@github.com:OpenKitten/MongoKitten.git", from: "6.2.0")
    ],
    targets: [
        .target(
            name: "CareKitHyperProtectSDK",
            dependencies: ["CareKitStore", "MongoKitten"]),
        .testTarget(
            name: "CareKitHyperProtectSDKTests",
            dependencies: ["CareKitHyperProtectSDK"]),
    ]
)
