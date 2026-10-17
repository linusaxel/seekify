// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Seekify",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Seekify"),
        .testTarget(name: "SeekifyTests", dependencies: ["Seekify"]),
    ]
)
