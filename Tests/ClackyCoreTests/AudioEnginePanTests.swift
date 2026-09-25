import AVFoundation
import ClackyCore

enum AudioEnginePanTests {
    /// A steady 0.5-amplitude tone, identical in both channels.
    private static func tone(frames: Int = 4_800) -> AVAudioPCMBuffer {
        let b = AVAudioPCMBuffer(pcmFormat: AudioBuffers.canonicalFormat, frameCapacity: AVAudioFrameCount(frames))!
        b.frameLength = AVAudioFrameCount(frames)
        for i in 0..<frames {
            let v = Float(sin(Double(i) * 0.1)) * 0.5
            b.floatChannelData![0][i] = v
            b.floatChannelData![1][i] = v
        }
        return b
    }

    private static func rms(_ b: AVAudioPCMBuffer, channel: Int) -> Double {
        let n = Int(b.frameLength)
        guard n > 0 else { return 0 }
        var sum = 0.0
        for i in 0..<n { let v = Double(b.floatChannelData![channel][i]); sum += v * v }
        return (sum / Double(n)).squareRoot()
    }

    private static func renderedLR(pan: Float) throws -> (Double, Double) {
        let engine = try AudioEngine(voices: 2, offlineFrames: 4_096)
        engine.volume = 1
        engine.play(tone(), rate: 1, pan: pan)
        let out = try engine.renderOffline(frames: 4_096)
        return (rms(out, channel: 0), rms(out, channel: 1))
    }

    static func run() {
        TestKit.run("AudioEngine pan left makes the left channel louder") {
            let (l, r) = try renderedLR(pan: -0.6)
            expect(l > 0.01, "left should carry signal, got \(l)")
            expect(l > r * 1.5, "left \(l) vs right \(r)")
        }
        TestKit.run("AudioEngine pan right makes the right channel louder") {
            let (l, r) = try renderedLR(pan: 0.6)
            expect(r > l * 1.5, "left \(l) vs right \(r)")
        }
        TestKit.run("AudioEngine pan zero keeps both channels equal") {
            let (l, r) = try renderedLR(pan: 0)
            expect(l > 0.01)
            expectEqual(l, r, accuracy: l * 0.05)
        }
        TestKit.run("AudioEngine pan is clamped to -1...1") {
            let engine = try AudioEngine(voices: 1, offlineFrames: 4_096)
            engine.play(tone(frames: 48), rate: 1, pan: 7)
            expectEqual(engine.lastAppliedPan, 1)
            engine.play(tone(frames: 48), rate: 1, pan: -7)
            expectEqual(engine.lastAppliedPan, -1)
        }
    }
}
