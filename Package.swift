// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeletionLadder",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DeletionLadder", targets: ["DeletionLadder"])
    ],
    targets: [
        .target(name: "DeletionLadder"),
        .testTarget(name: "DeletionLadderTests", dependencies: ["DeletionLadder"])
    ]
)
