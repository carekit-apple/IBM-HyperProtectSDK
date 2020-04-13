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
    ],
    targets: [
        .target(
            name: "CareKitHyperProtectSDK",
            dependencies: ["CareKitStore"]),
        .testTarget(
            name: "CareKitHyperProtectSDKTests",
            dependencies: ["CareKitHyperProtectSDK"]),
    ]
)
