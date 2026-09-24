import Foundation
import ClackyCore

enum ScaffoldTests {
    static func run() {
        TestKit.run("repo root has Package.swift") {
            let pkg = TestPaths.repoRoot.appendingPathComponent("Package.swift")
            expect(FileManager.default.fileExists(atPath: pkg.path), pkg.path)
        }
    }
}
