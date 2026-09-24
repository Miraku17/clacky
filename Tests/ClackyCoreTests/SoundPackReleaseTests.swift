import AVFoundation
import ClackyCore

enum SoundPackReleaseTests {
    private static func makeV2(in tmp: URL, name: String, config: String, files: [(String, Double)]) throws -> URL {
        let folder = tmp.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("press"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("release"), withIntermediateDirectories: true)
        try Data(config.utf8).write(to: folder.appendingPathComponent("config.json"))
        for (file, seconds) in files { try TestAudio.writeWav(to: folder.appendingPathComponent(file), seconds: seconds) }
        return folder
    }

    static func run() {
        TestKit.run("SoundPack loads release sounds from -up defines and the soundup pool") {
            try TestKit.withTempDir { tmp in
                let folder = try makeV2(in: tmp, name: "rel", config: #"{"key_define_type":"multi","sound":"press/G{0-1}.wav","soundup":"release/G.wav","defines":{"57":"press/space.wav","57-up":"release/space.wav"}}"#,
                    files: [("press/G0.wav", 0.1), ("press/G1.wav", 0.1), ("press/space.wav", 0.3), ("release/G.wav", 0.1), ("release/space.wav", 0.2)])
                let pack = try SoundPack(folder: folder)
                expect(pack.hasReleaseSounds)
                expectEqual(Double(pack.releaseBuffer(for: 57)?.frameLength ?? 0), 9_600, accuracy: 480)
                expectEqual(Double(pack.releaseBuffer(for: 30)?.frameLength ?? 0), 4_800, accuracy: 480, "undefined key uses the release pool")
            }
        }
        TestKit.run("SoundPack without release files reports none") {
            let pack = try SoundPack(folder: TestPaths.defaultPack)
            expect(!pack.hasReleaseSounds)
            expectNil(pack.releaseBuffer(for: 57))
        }
        TestKit.run("SoundPack skips missing release files") {
            try TestKit.withTempDir { tmp in
                let folder = try makeV2(in: tmp, name: "partial", config: #"{"key_define_type":"multi","sound":"press/G{0-0}.wav","soundup":"release/missing.wav","defines":{"57-up":"release/space.wav","14-up":"release/ghost.wav"}}"#,
                    files: [("press/G0.wav", 0.1), ("release/space.wav", 0.2)])
                let pack = try SoundPack(folder: folder)
                expect(pack.hasReleaseSounds)
                expectNotNil(pack.releaseBuffer(for: 57))
                expectNil(pack.releaseBuffer(for: 14), "missing define file and no pool → silent")
                expectNil(pack.releaseBuffer(for: 30))
            }
        }
        TestKit.run("SoundPack release buffers honour arrow aliases") {
            try TestKit.withTempDir { tmp in
                let folder = try makeV2(in: tmp, name: "arrows", config: #"{"key_define_type":"multi","sound":"press/G{0-0}.wav","defines":{"61003-up":"release/left.wav"}}"#,
                    files: [("press/G0.wav", 0.1), ("release/left.wav", 0.2)])
                let pack = try SoundPack(folder: folder)
                expect(pack.releaseBuffer(for: 57419) === pack.releaseBuffer(for: 61003))
                expectNotNil(pack.releaseBuffer(for: 57419))
            }
        }
    }
}
