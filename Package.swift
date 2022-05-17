// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "build_ipa",
    platforms: [.macOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "build_ipa",
            targets: ["build_ipa"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/kareman/SwiftShell", from: "5.1.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(name: "build_ipa",
                          dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            "SwiftShell",
            "Alamofire"
        ]),
        .testTarget(
            name: "build_ipaTests",
            dependencies: ["build_ipa"]),
    ]
)
