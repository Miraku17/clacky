import AVFoundation
import ClackyCore

enum SoundPackTests {
    private static func writeConfig(_ json: String, in folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: folder.appendingPathComponent("config.json"))
    }

    static func run() {
        TestKit.run("SoundPack loads the real single pack") {
            let pack = try SoundPack(folder: TestPaths.defaultPack)
            expectEqual(pack.name, "CherryMX Blue - PBT keycaps")
            expectEqual(pack.keyCount, 114)
            let space = pack.buffer(for: 57)
            expectEqual(space.format, AudioBuffers.canonicalFormat)
            expect(space.frameLength > 0)
        }
        TestKit.run("SoundPack unmapped key falls back to some sound") {
            let pack = try SoundPack(folder: TestPaths.defaultPack)
            let a = pack.buffer(for: 999_999)
            let b = pack.buffer(for: 999_999)
            expect(a.frameLength > 0)
            expect(a === b, "fallback is deterministic per key code")
        }
        TestKit.run("SoundPack loads a multi pack from wav files") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("multi")
                try writeConfig(#"{"name":"Multi","key_define_type":"multi","defines":{"57":"space.wav","28":"enter.wav"}}"#, in: folder)
                try TestAudio.writeWav(to: folder.appendingPathComponent("space.wav"), seconds: 0.1)
                try TestAudio.writeWav(to: folder.appendingPathComponent("enter.wav"), seconds: 0.2)
                let pack = try SoundPack(folder: folder)
                expectEqual(pack.keyCount, 2)
                expectEqual(Double(pack.buffer(for: 57).frameLength), 4_800, accuracy: 480)
                expectEqual(Double(pack.buffer(for: 28).frameLength), 9_600, accuracy: 480)
            }
        }
        TestKit.run("SoundPack name falls back to folder name") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("My Folder")
                try writeConfig(#"{"key_define_type":"multi","defines":{"1":"a.wav"}}"#, in: folder)
                try TestAudio.writeWav(to: folder.appendingPathComponent("a.wav"), seconds: 0.05)
                expectEqual(try SoundPack(folder: folder).name, "My Folder")
            }
        }
        TestKit.run("SoundPack missing audio file error names the file") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("broken")
                try writeConfig(#"{"key_define_type":"multi","defines":{"1":"ghost.wav"}}"#, in: folder)
                expectThrows(try SoundPack(folder: folder)) { error in
                    expect(error.localizedDescription.contains("ghost.wav"), error.localizedDescription)
                }
            }
        }
        TestKit.run("SoundPack missing config throws missingConfig") {
            try TestKit.withTempDir { tmp in
                expectThrows(try SoundPack(folder: tmp)) { error in
                    guard case SoundPack.Error.missingConfig = error else { return expect(false, "\(error)") }
                }
            }
        }
        TestKit.run("SoundPack with no usable defines throws noSounds") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("beyond")
                try writeConfig(#"{"key_define_type":"single","sound":"s.wav","defines":{"1":[5000,100]}}"#, in: folder)
                try TestAudio.writeWav(to: folder.appendingPathComponent("s.wav"), seconds: 0.05)
                expectThrows(try SoundPack(folder: folder)) { error in
                    guard case SoundPack.Error.noSounds = error else { return expect(false, "\(error)") }
                }
            }
        }
    }
}

enum SoundPackReviewTests {
    static func run() {
        TestKit.run("SoundPack resolves arrow keys defined only with the 61000-series codes") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("arrows")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data(#"{"key_define_type":"multi","defines":{"61003":"left.wav","1":"other.wav"}}"#.utf8)
                    .write(to: folder.appendingPathComponent("config.json"))
                try TestAudio.writeWav(to: folder.appendingPathComponent("left.wav"), seconds: 0.1)
                try TestAudio.writeWav(to: folder.appendingPathComponent("other.wav"), seconds: 0.3)
                let pack = try SoundPack(folder: folder)
                expectEqual(Double(pack.buffer(for: 57419).frameLength), 4_800, accuracy: 480, "libuiohook left arrow should use the 61003 define")
            }
        }
        TestKit.run("SoundPack resolves arrow keys defined only with the libuiohook codes") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("arrows2")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data(#"{"key_define_type":"multi","defines":{"57416":"up.wav","1":"other.wav"}}"#.utf8)
                    .write(to: folder.appendingPathComponent("config.json"))
                try TestAudio.writeWav(to: folder.appendingPathComponent("up.wav"), seconds: 0.1)
                try TestAudio.writeWav(to: folder.appendingPathComponent("other.wav"), seconds: 0.3)
                let pack = try SoundPack(folder: folder)
                expectEqual(Double(pack.buffer(for: 61000).frameLength), 4_800, accuracy: 480)
            }
        }
    }
}

enum SoundPackV2Tests {
    static func run() {
        TestKit.run("SoundPack v2 multi pack uses the generic pool for undefined keys") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("v2")
                try FileManager.default.createDirectory(at: folder.appendingPathComponent("press"), withIntermediateDirectories: true)
                try Data(#"{"name":"V2","key_define_type":"multi","sound":"press/G{0-1}.wav","defines":{"57":"press/space.wav"}}"#.utf8)
                    .write(to: folder.appendingPathComponent("config.json"))
                try TestAudio.writeWav(to: folder.appendingPathComponent("press/space.wav"), seconds: 0.3)
                try TestAudio.writeWav(to: folder.appendingPathComponent("press/G0.wav"), seconds: 0.1)
                try TestAudio.writeWav(to: folder.appendingPathComponent("press/G1.wav"), seconds: 0.1)
                let pack = try SoundPack(folder: folder)
                expectEqual(pack.keyCount, 1)
                expectEqual(Double(pack.buffer(for: 57).frameLength), 14_400, accuracy: 480)
                expectEqual(Double(pack.buffer(for: 30).frameLength), 4_800, accuracy: 480, "undefined key should come from the generic pool")
                expect(pack.buffer(for: 30) === pack.buffer(for: 30), "deterministic per key")
            }
        }
        TestKit.run("SoundPack v2 multi pack with a missing generic file names it") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("v2broken")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data(#"{"key_define_type":"multi","sound":"G{0-1}.wav","defines":{"57":"space.wav"}}"#.utf8)
                    .write(to: folder.appendingPathComponent("config.json"))
                try TestAudio.writeWav(to: folder.appendingPathComponent("space.wav"), seconds: 0.1)
                try TestAudio.writeWav(to: folder.appendingPathComponent("G0.wav"), seconds: 0.1)
                expectThrows(try SoundPack(folder: folder)) { error in
                    expect(error.localizedDescription.contains("G1.wav"), error.localizedDescription)
                }
            }
        }
    }
}

enum SoundPackV2MissingDefineTests {
    static func run() {
        TestKit.run("SoundPack v2 multi pack skips a defined key whose file is missing when a generic pool exists") {
            try TestKit.withTempDir { tmp in
                let folder = tmp.appendingPathComponent("v2partial")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data(#"{"key_define_type":"multi","sound":"G{0-1}.wav","defines":{"57":"space.wav","14":"ghost.wav"}}"#.utf8)
                    .write(to: folder.appendingPathComponent("config.json"))
                try TestAudio.writeWav(to: folder.appendingPathComponent("space.wav"), seconds: 0.3)
                try TestAudio.writeWav(to: folder.appendingPathComponent("G0.wav"), seconds: 0.1)
                try TestAudio.writeWav(to: folder.appendingPathComponent("G1.wav"), seconds: 0.1)
                let pack = try SoundPack(folder: folder)
                expectEqual(pack.keyCount, 1)
                expectEqual(Double(pack.buffer(for: 14).frameLength), 4_800, accuracy: 480, "missing define falls back to the generic pool")
            }
        }
    }
}
