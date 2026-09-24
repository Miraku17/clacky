import Foundation
import CVorbis

public struct DecodedAudio {
    public let channels: Int
    public let sampleRate: Double
    public let frameCount: Int
    /// Interleaved 16-bit PCM, `frameCount * channels` values.
    public let samples: [Int16]
}

public enum VorbisDecoder {
    public enum Error: Swift.Error, LocalizedError {
        case decodeFailed
        public var errorDescription: String? { "Could not decode Ogg Vorbis data" }
    }

    public static func decode(_ data: Data) throws -> DecodedAudio {
        var channels: Int32 = 0
        var sampleRate: Int32 = 0
        var output: UnsafeMutablePointer<Int16>? = nil
        let frames = data.withUnsafeBytes { raw -> Int32 in
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            return stb_vorbis_decode_memory(base, Int32(data.count), &channels, &sampleRate, &output)
        }
        guard frames > 0, channels > 0, let out = output else { throw Error.decodeFailed }
        defer { free(out) }
        let count = Int(frames) * Int(channels)
        let samples = Array(UnsafeBufferPointer(start: out, count: count))
        return DecodedAudio(channels: Int(channels), sampleRate: Double(sampleRate),
                            frameCount: Int(frames), samples: samples)
    }
}
