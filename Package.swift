// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Stacksift",
    platforms: [.macOS(.v10_13), .iOS(.v12), .tvOS(.v12), .watchOS(.v3)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Stacksift",
            targets: ["Stacksift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stacksift/Impact", from: "0.3.3"),
        .package(url: "https://github.com/stacksift/Wells", from: "0.1.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Stacksift",
            dependencies: ["Impact", "Wells"]),
        .testTarget(
            name: "StacksiftTests",
            dependencies: ["Stacksift"]),
    ]
)
