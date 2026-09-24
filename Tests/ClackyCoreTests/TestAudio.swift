import AVFoundation
import ClackyCore

enum TestAudio {
    /// Writes a 16-bit PCM wav with a low-frequency sine. Returns the frame count.
    @discardableResult
    static func writeWav(to url: URL, seconds: Double, sampleRate: Double = 44_100,
                         channels: AVAudioChannelCount = 1) throws -> Int {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for ch in 0..<Int(channels) {
            for i in 0..<Int(frames) { buffer.floatChannelData![ch][i] = Float(sin(Double(i) * 0.05)) * 0.5 }
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
        return Int(frames)
    }

    /// Canonical-format buffer whose channel 0 holds 0,1,2,… and channel 1 holds the negatives.
    static func ramp(frames: Int) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: AudioBuffers.canonicalFormat, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for i in 0..<frames {
            buffer.floatChannelData![0][i] = Float(i)
            buffer.floatChannelData![1][i] = -Float(i)
        }
        return buffer
    }
}
