// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CalDashKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CalDashKit", targets: ["CalDashKit"]),
    ],
    targets: [
        .target(name: "CalDashKit"),
        .testTarget(name: "CalDashKitTests", dependencies: ["CalDashKit"]),
    ]
)
