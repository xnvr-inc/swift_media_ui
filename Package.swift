// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaUI",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MediaUI", targets: ["MediaUI"]),
        .executable(name: "MediaUIDemo", targets: ["MediaUIDemo"]),
    ],
    targets: [
        .target(name: "MediaUI"),
        .executableTarget(name: "MediaUIDemo", dependencies: ["MediaUI"], path: "Examples/MediaUIDemo"),
        .testTarget(name: "MediaUITests", dependencies: ["MediaUI"]),
    ]
)
