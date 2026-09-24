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
