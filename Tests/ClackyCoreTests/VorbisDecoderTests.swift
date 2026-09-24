import Foundation
import ClackyCore

enum VorbisDecoderTests {
    static func run() {
        TestKit.run("VorbisDecoder decodes the default pack sprite") {
            let data = try Data(contentsOf: TestPaths.defaultPack.appendingPathComponent("sound.ogg"))
            let audio = try VorbisDecoder.decode(data)
            expect((1...2).contains(audio.channels), "channels \(audio.channels)")
            expect(audio.sampleRate > 8_000, "sampleRate \(audio.sampleRate)")
            expectEqual(audio.samples.count, audio.frameCount * audio.channels)
            expect(Double(audio.frameCount) / audio.sampleRate > 5, "sprite should be several seconds long")
        }
        TestKit.run("VorbisDecoder rejects garbage") {
            expectThrows(try VorbisDecoder.decode(Data([0, 1, 2, 3, 4, 5, 6, 7])))
        }
    }
}
