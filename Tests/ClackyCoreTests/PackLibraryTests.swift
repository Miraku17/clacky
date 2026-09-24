import Foundation
import ClackyCore

enum PackLibraryTests {
    private static func makePack(_ name: String, in root: URL, withConfig: Bool = true) throws -> URL {
        let folder = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if withConfig {
            try Data(#"{"key_define_type":"multi","defines":{"1":"a.wav"}}"#.utf8).write(to: folder.appendingPathComponent("config.json"))
        }
        return folder
    }

    static func run() {
        TestKit.run("PackLibrary prepare creates directory and seeds bundled packs") {
            try TestKit.withTempDir { tmp in
                let bundled = tmp.appendingPathComponent("bundled")
                _ = try makePack("seed-pack", in: bundled)
                let packs = tmp.appendingPathComponent("does/not/exist/yet")
                let lib = PackLibrary(packsDirectory: packs, bundledPacksDirectory: bundled)
                try lib.prepare()
                expectEqual(lib.availablePacks().map(\.lastPathComponent), ["seed-pack"])
            }
        }
        TestKit.run("PackLibrary prepare keeps existing packs and adds bundled ones") {
            try TestKit.withTempDir { tmp in
                let bundled = tmp.appendingPathComponent("bundled")
                _ = try makePack("seed-pack", in: bundled)
                let packs = tmp.appendingPathComponent("packs")
                _ = try makePack("mine", in: packs)
                let lib = PackLibrary(packsDirectory: packs, bundledPacksDirectory: bundled)
                try lib.prepare()
                expectEqual(lib.availablePacks().map(\.lastPathComponent), ["mine", "seed-pack"])
            }
        }
        TestKit.run("PackLibrary lists folders with spaces and unicode") {
            try TestKit.withTempDir { tmp in
                let packs = tmp.appendingPathComponent("packs")
                _ = try makePack("Holy Pandas", in: packs)
                _ = try makePack("トプレ 45g", in: packs)
                _ = try makePack("no-config", in: packs, withConfig: false)
                try Data().write(to: packs.appendingPathComponent("stray.txt"))
                let lib = PackLibrary(packsDirectory: packs, bundledPacksDirectory: nil)
                expectEqual(lib.availablePacks().map(\.lastPathComponent), ["Holy Pandas", "トプレ 45g"])
            }
        }
        TestKit.run("PackLibrary loads the real default pack by folder name") {
            let lib = PackLibrary(packsDirectory: TestPaths.packsRoot, bundledPacksDirectory: nil)
            expectEqual(try lib.load(named: "cherrymx-blue-pbt").keyCount, 114)
        }
        TestKit.run("PackLibrary default packs directory is under Application Support") {
            expect(PackLibrary.defaultPacksDirectory.path.hasSuffix("/Library/Application Support/Clacky/Packs"),
                   PackLibrary.defaultPacksDirectory.path)
        }
    }
}

enum PackLibrarySeedingTests {
    private static func makePack(_ name: String, in root: URL, displayName: String? = nil) throws -> URL {
        let folder = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let nameField = displayName.map { #""name":"\#($0)","# } ?? ""
        try Data(#"{\#(nameField)"key_define_type":"multi","defines":{"1":"a.wav"}}"#.utf8)
            .write(to: folder.appendingPathComponent("config.json"))
        return folder
    }

    static func run() {
        TestKit.run("PackLibrary prepare adds bundled packs the user does not have yet") {
            try TestKit.withTempDir { tmp in
                let bundled = tmp.appendingPathComponent("bundled")
                _ = try makePack("seed-a", in: bundled)
                _ = try makePack("seed-b", in: bundled)
                let packs = tmp.appendingPathComponent("packs")
                _ = try makePack("mine", in: packs)
                let lib = PackLibrary(packsDirectory: packs, bundledPacksDirectory: bundled)
                try lib.prepare()
                expectEqual(lib.availablePacks().map(\.lastPathComponent), ["mine", "seed-a", "seed-b"])
            }
        }
        TestKit.run("PackLibrary prepare never overwrites a pack the user already has") {
            try TestKit.withTempDir { tmp in
                let bundled = tmp.appendingPathComponent("bundled")
                _ = try makePack("shared", in: bundled)
                let packs = tmp.appendingPathComponent("packs")
                let mine = try makePack("shared", in: packs)
                try Data("edited".utf8).write(to: mine.appendingPathComponent("marker.txt"))
                let lib = PackLibrary(packsDirectory: packs, bundledPacksDirectory: bundled)
                try lib.prepare()
                let marker = try String(contentsOf: mine.appendingPathComponent("marker.txt"), encoding: .utf8)
                expectEqual(marker, "edited")
            }
        }
        TestKit.run("PackLibrary packInfos reads display names with folder-name fallback") {
            try TestKit.withTempDir { tmp in
                let packs = tmp.appendingPathComponent("packs")
                _ = try makePack("holy-pandas", in: packs, displayName: "Holy Pandas")
                _ = try makePack("no-name", in: packs)
                let lib = PackLibrary(packsDirectory: packs, bundledPacksDirectory: nil)
                let infos = lib.packInfos()
                expectEqual(infos.map(\.folderName), ["holy-pandas", "no-name"])
                expectEqual(infos.map(\.displayName), ["Holy Pandas", "no-name"])
            }
        }
    }
}
