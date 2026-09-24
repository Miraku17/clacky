import Foundation

enum TestPaths {
    /// Tests/ClackyCoreTests/TestPaths.swift → repo root.
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    static let packsRoot = repoRoot.appendingPathComponent("Resources/Packs")
    static let defaultPack = packsRoot.appendingPathComponent("cherrymx-blue-pbt")
}
