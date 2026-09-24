import AVFoundation
import ClackyCore

enum AudioEngineRateTests {
    static func run() {
        TestKit.run("AudioEngine rate is clamped and applied") {
            let engine = AudioEngine(voices: 2)
            let silence = AVAudioPCMBuffer(pcmFormat: AudioBuffers.canonicalFormat, frameCapacity: 48)!
            silence.frameLength = 48
            engine.play(silence, rate: 9)
            expectEqual(engine.lastAppliedRate, 2)
            engine.play(silence, rate: 0.1)
            expectEqual(engine.lastAppliedRate, 0.5)
            engine.play(silence, rate: 1.02)
            expectEqual(Double(engine.lastAppliedRate), 1.02, accuracy: 1e-6)
            engine.play(silence)
            expectEqual(engine.lastAppliedRate, 1)
            expectNil(engine.lastError)
        }
    }
}
