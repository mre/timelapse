// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Timelapse",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Timelapse", targets: ["Timelapse"])],
    targets: [
        .executableTarget(name: "Timelapse"),
        .testTarget(name: "TimelapseTests", dependencies: ["Timelapse"]),
    ],
    swiftLanguageModes: [.v5]
)
