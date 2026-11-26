// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Blindfold",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Blindfold", targets: ["Blindfold"])],
    targets: [
        .executableTarget(name: "Blindfold"),
        .testTarget(name: "BlindfoldTests", dependencies: ["Blindfold"]),
    ]
)
