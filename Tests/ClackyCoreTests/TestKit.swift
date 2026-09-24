import Foundation

/// Minimal test runner. XCTest does not ship with the Command Line Tools,
/// so each test file exposes `static func run()` and main.swift calls them.
enum TestKit {
    static var failures: [String] = []
    static var passed = 0
    static var failed = 0
    static let filter: String? = CommandLine.arguments.dropFirst().first

    static func run(_ name: String, _ body: () throws -> Void) {
        if let filter, !name.localizedCaseInsensitiveContains(filter) { return }
        let before = failures.count
        do { try body() } catch { failures.append("threw \(error)") }
        if failures.count == before {
            passed += 1
            print("  ✓ \(name)")
        } else {
            failed += 1
            print("  ✗ \(name)")
            for f in failures[before...] { print("      \(f)") }
        }
    }

    static func finish() -> Never {
        print("\(passed) passed, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }

    /// Runs `body` with a fresh temporary directory that is deleted afterwards.
    static func withTempDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("clacky-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String = "", file: String = #fileID, line: Int = #line) {
    if !condition() { TestKit.failures.append("\(file):\(line) \(message)") }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #fileID, line: Int = #line) {
    if actual != expected { TestKit.failures.append("\(file):\(line) got \(actual), expected \(expected) \(message)") }
}

func expectEqual(_ actual: Double, _ expected: Double, accuracy: Double, _ message: String = "", file: String = #fileID, line: Int = #line) {
    if abs(actual - expected) > accuracy { TestKit.failures.append("\(file):\(line) got \(actual), expected \(expected) ± \(accuracy) \(message)") }
}

func expectNil<T>(_ value: T?, _ message: String = "", file: String = #fileID, line: Int = #line) {
    if let value { TestKit.failures.append("\(file):\(line) expected nil, got \(value) \(message)") }
}

func expectNotNil<T>(_ value: T?, _ message: String = "", file: String = #fileID, line: Int = #line) {
    if value == nil { TestKit.failures.append("\(file):\(line) expected non-nil \(message)") }
}

/// Fails when `body` does not throw. `check` inspects the error when it does.
func expectThrows<T>(_ body: @autoclosure () throws -> T, _ message: String = "", file: String = #fileID, line: Int = #line, check: ((Error) -> Void)? = nil) {
    do {
        _ = try body()
        TestKit.failures.append("\(file):\(line) expected an error \(message)")
    } catch {
        check?(error)
    }
}
