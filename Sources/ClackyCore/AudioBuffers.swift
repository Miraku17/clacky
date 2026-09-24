import AVFoundation

public enum AudioBuffers {
    public static let sampleRate: Double = 48_000
    public static let channelCount: AVAudioChannelCount = 2
    /// Float32, 48 kHz, stereo, deinterleaved. Every buffer the engine plays is in this format.
    public static let canonicalFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!

    public enum Error: Swift.Error, LocalizedError {
        case emptyBuffer
        case unsupportedChannelCount(Int)
        case conversionFailed(String)
        public var errorDescription: String? {
            switch self {
            case .emptyBuffer: return "Audio buffer is empty"
            case .unsupportedChannelCount(let n): return "Unsupported channel count: \(n)"
            case .conversionFailed(let m): return "Audio conversion failed: \(m)"
            }
        }
    }

    /// Wraps interleaved Int16 PCM (as produced by VorbisDecoder) in a buffer.
    public static func buffer(fromInt16 samples: [Int16], channels: Int, sampleRate: Double) throws -> AVAudioPCMBuffer {
        let frames = channels > 0 ? samples.count / channels : 0
        guard frames > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate,
                                         channels: AVAudioChannelCount(channels), interleaved: true),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))
        else { throw Error.emptyBuffer }
        buffer.frameLength = AVAudioFrameCount(frames)
        samples.withUnsafeBufferPointer { src in
            buffer.int16ChannelData![0].update(from: src.baseAddress!, count: frames * channels)
        }
        return buffer
    }

    /// Reads any AVFoundation-decodable file (wav, aiff, mp3, m4a, caf) in its processing format.
    public static func buffer(fromFile url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)
        else { throw Error.emptyBuffer }
        try file.read(into: buffer)
        return buffer
    }

    /// Converts to `canonicalFormat`. Mono sources are duplicated to both channels.
    public static func toCanonical(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let srcChannels = Int(source.format.channelCount)
        guard srcChannels == 1 || srcChannels == 2 else { throw Error.unsupportedChannelCount(srcChannels) }
        guard source.frameLength > 0 else { throw Error.emptyBuffer }

        // Step 1: same channel count, Float32 / 48 kHz / deinterleaved.
        let midFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: source.format.channelCount)!
        let mid: AVAudioPCMBuffer
        if source.format == midFormat {
            mid = source
        } else {
            guard let converter = AVAudioConverter(from: source.format, to: midFormat)
            else { throw Error.conversionFailed("no converter for \(source.format)") }
            let ratio = sampleRate / source.format.sampleRate
            let capacity = AVAudioFrameCount((Double(source.frameLength) * ratio).rounded(.up)) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: midFormat, frameCapacity: capacity) else { throw Error.emptyBuffer }
            var delivered = false
            var convError: NSError?
            let status = converter.convert(to: out, error: &convError) { _, outStatus in
                if delivered { outStatus.pointee = .endOfStream; return nil }
                delivered = true
                outStatus.pointee = .haveData
                return source
            }
            if status == .error { throw Error.conversionFailed(convError?.localizedDescription ?? "unknown") }
            mid = out
        }
        if mid.format.channelCount == channelCount { return mid }

        // Step 2: mono → stereo by duplication.
        let n = Int(mid.frameLength)
        guard let stereo = AVAudioPCMBuffer(pcmFormat: canonicalFormat, frameCapacity: AVAudioFrameCount(n))
        else { throw Error.emptyBuffer }
        stereo.frameLength = AVAudioFrameCount(n)
        let src = mid.floatChannelData![0]
        stereo.floatChannelData![0].update(from: src, count: n)
        stereo.floatChannelData![1].update(from: src, count: n)
        return stereo
    }

    /// Copies `[startMs, startMs + durationMs)` out of a canonical buffer, clamped to its end.
    /// Throws `emptyBuffer` when the window starts at or after the end.
    public static func slice(_ source: AVAudioPCMBuffer, startMs: Double, durationMs: Double) throws -> AVAudioPCMBuffer {
        let total = Int(source.frameLength)
        let start = max(0, min(total, Int(startMs / 1_000 * sampleRate)))
        let end = max(start, min(total, Int((startMs + durationMs) / 1_000 * sampleRate)))
        let n = end - start
        guard n > 0, let out = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: AVAudioFrameCount(n))
        else { throw Error.emptyBuffer }
        out.frameLength = AVAudioFrameCount(n)
        for ch in 0..<Int(source.format.channelCount) {
            out.floatChannelData![ch].update(from: source.floatChannelData![ch] + start, count: n)
        }
        return out
    }
}
