import AVFoundation
import ClackyCore

enum AudioEngineTests {
    static func run() {
        TestKit.run("AudioEngine volume is clamped") {
            let engine = AudioEngine(voices: 2)
            engine.volume = 0.3
            expectEqual(Double(engine.volume), 0.3, accuracy: 0.001)
            engine.volume = 7
            expectEqual(engine.volume, 1)
            engine.volume = -1
            expectEqual(engine.volume, 0)
        }
        TestKit.run("AudioEngine play starts engine and cycles voices without error") {
            let engine = AudioEngine(voices: 2)
            let silence = AVAudioPCMBuffer(pcmFormat: AudioBuffers.canonicalFormat, frameCapacity: 48)!
            silence.frameLength = 48   // zero-filled
            for _ in 0..<5 { engine.play(silence) }   // more plays than voices
            expectNil(engine.lastError)
        }
    }
}
