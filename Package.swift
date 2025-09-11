// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HoopProxyManager",
    platforms: [
        .macOS(.v13)  // Targeting macOS 13 Ventura for latest Swift features
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0-beta.rc"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    ],
    targets: [
        // Shared business logic library
        .target(
            name: "HoopProxyManagerCore",
            dependencies: [
                .product(name: "TOMLKit", package: "TOMLKit"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
                .unsafeFlags(["-Osize"], .when(configuration: .release)),
            ]
        ),
        // CLI executable target
        .executableTarget(
            name: "HoopProxyManager",
            dependencies: [
                "HoopProxyManagerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
                .unsafeFlags(["-Osize"], .when(configuration: .release)),
            ]
        ),
        // Web UI executable target
        .executableTarget(
            name: "HoopProxyManagerWeb",
            dependencies: [
                "HoopProxyManagerCore",
                .product(name: "Vapor", package: "vapor"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
                .unsafeFlags(["-Osize"], .when(configuration: .release)),
            ]
        ),
        .testTarget(name: "HoopProxyManagerTests", dependencies: ["HoopProxyManagerCore"]),
    ]
)
