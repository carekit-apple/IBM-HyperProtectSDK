// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "IBMHyperProtectSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "IBMHyperProtectSDK",
            targets: ["IBMHyperProtectSDK"]),
    ],
    dependencies: [
        .package(url: "git@github.com:carekit-apple/CareKit.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "IBMHyperProtectSDK",
            dependencies: ["CareKitStore"]),
        .testTarget(
            name: "IBMHyperProtectSDKTests",
            dependencies: ["IBMHyperProtectSDK", "CareKitStore"]),
    ]
)
