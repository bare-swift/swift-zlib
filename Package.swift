// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import PackageDescription

let package = Package(
    name: "swift-zlib",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Zlib", targets: ["Zlib"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
        .package(url: "https://github.com/bare-swift/swift-bytes.git", from: "0.1.0"),
        .package(url: "https://github.com/bare-swift/swift-deflate.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "Zlib",
            dependencies: [
                .product(name: "Bytes", package: "swift-bytes"),
                .product(name: "Deflate", package: "swift-deflate")
            ]
        ),
        .testTarget(
            name: "ZlibTests",
            dependencies: ["Zlib"]
        )
    ]
)
