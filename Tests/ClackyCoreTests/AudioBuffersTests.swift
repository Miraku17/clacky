import AVFoundation
import ClackyCore

enum AudioBuffersTests {
    static func run() {
        TestKit.run("AudioBuffers int16 mono becomes canonical stereo") {
            let n = 24_000
            let samples = (0..<n).map { Int16(truncatingIfNeeded: $0 % 1000) }
            let raw = try AudioBuffers.buffer(fromInt16: samples, channels: 1, sampleRate: 24_000)
            let out = try AudioBuffers.toCanonical(raw)
            expectEqual(out.format, AudioBuffers.canonicalFormat)
            expectEqual(Double(out.frameLength), 48_000, accuracy: 480)
            for i in stride(from: 0, to: 4_000, by: 97) {
                expectEqual(out.floatChannelData![0][i], out.floatChannelData![1][i], "mono must be duplicated at \(i)")
            }
        }
        TestKit.run("AudioBuffers canonical input passes through") {
            let out = try AudioBuffers.toCanonical(TestAudio.ramp(frames: 100))
            expectEqual(out.frameLength, 100)
            expectEqual(out.floatChannelData![0][42], 42)
            expectEqual(out.floatChannelData![1][42], -42)
        }
        TestKit.run("AudioBuffers resamples preserving duration") {
            try TestKit.withTempDir { tmp in
                let url = tmp.appendingPathComponent("a.wav")
                try TestAudio.writeWav(to: url, seconds: 0.5, sampleRate: 44_100, channels: 2)
                let raw = try AudioBuffers.buffer(fromFile: url)
                expectEqual(raw.frameLength, 22_050)
                let out = try AudioBuffers.toCanonical(raw)
                expectEqual(Double(out.frameLength), 24_000, accuracy: 480)  // 10 ms
                expectEqual(out.format.channelCount, 2)
            }
        }
        TestKit.run("AudioBuffers slice copies the requested window") {
            let out = try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: 10, durationMs: 5)  // 480 in, 240 long
            expectEqual(out.frameLength, 240)
            expectEqual(out.floatChannelData![0][0], 480)
            expectEqual(out.floatChannelData![1][0], -480)
            expectEqual(out.floatChannelData![0][239], 719)
        }
        TestKit.run("AudioBuffers slice clamps to end") {
            let out = try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: 15, durationMs: 1_000)  // 720 in, wants 48 000
            expectEqual(out.frameLength, 280)
        }
        TestKit.run("AudioBuffers slice beyond end throws") {
            expectThrows(try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: 100, durationMs: 10))
        }
        TestKit.run("AudioBuffers empty int16 throws") {
            expectThrows(try AudioBuffers.buffer(fromInt16: [], channels: 2, sampleRate: 44_100))
        }
    }
}

enum AudioBuffersReviewTests {
    static func run() {
        TestKit.run("AudioBuffers slice with absurd start throws instead of trapping") {
            expectThrows(try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: 1e300, durationMs: 10))
            expectThrows(try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: .nan, durationMs: 10))
            expectThrows(try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: 0, durationMs: .infinity - .infinity))
        }
        TestKit.run("AudioBuffers slice with huge negative start and huge duration returns the whole buffer") {
            let out = try AudioBuffers.slice(TestAudio.ramp(frames: 1_000), startMs: -1e300, durationMs: 1e308)
            expectEqual(out.frameLength, 1_000)
        }
    }
}
