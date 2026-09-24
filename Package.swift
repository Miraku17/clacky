// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clacky",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CVorbis"),
        .target(name: "ClackyCore", dependencies: ["CVorbis"]),
        .executableTarget(name: "Clacky", dependencies: ["ClackyCore"]),
        // XCTest is not available with Command Line Tools alone (no Xcode),
        // so the tests are a plain executable: `swift run ClackyCoreTests [filter]`.
        .executableTarget(name: "ClackyCoreTests", dependencies: ["ClackyCore"], path: "Tests/ClackyCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
