import AVFoundation
import Foundation

/// A loaded Mechvibes pack: one canonical-format buffer per key code, ready to play.
public final class SoundPack {
    public enum Error: Swift.Error, LocalizedError {
        case missingConfig(URL)
        case missingAudioFile(String)
        case noSounds(String)
        public var errorDescription: String? {
            switch self {
            case .missingConfig(let url): return "No config.json in \(url.lastPathComponent)"
            case .missingAudioFile(let name): return "Audio file not found: \(name)"
            case .noSounds(let pack): return "\(pack) has no playable sounds"
            }
        }
    }

    public let name: String
    public let folder: URL
    private let buffers: [Int: AVAudioPCMBuffer]
    private let fallbackPool: [AVAudioPCMBuffer]
    private let releaseBuffers: [Int: AVAudioPCMBuffer]
    private let releasePool: [AVAudioPCMBuffer]
    /// True when the pack ships any key-up (release) sample.
    public let hasReleaseSounds: Bool

    public var keyCount: Int { buffers.count }
    /// True for version-2 packs whose undefined keys draw from a generic pool.
    public let hasGenericPool: Bool

    public init(folder: URL) throws {
        let configURL = folder.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else { throw Error.missingConfig(configURL) }
        let config = try PackConfig.load(from: configURL)
        self.folder = folder
        if let n = config.name, !n.isEmpty { name = n } else { name = folder.lastPathComponent }

        var map: [Int: AVAudioPCMBuffer] = [:]
        var generic: [AVAudioPCMBuffer] = []
        var upMap: [Int: AVAudioPCMBuffer] = [:]
        var releaseGeneric: [AVAudioPCMBuffer] = []
        switch config.keyDefineType {
        case .single:
            let sprite = try Self.loadCanonical(folder.appendingPathComponent(config.sound ?? ""))
            for (code, define) in config.defines {
                guard case .span(let start, let duration) = define else { continue }
                if let slice = try? AudioBuffers.slice(sprite, startMs: start, durationMs: duration) {
                    map[code] = slice
                }
            }
        case .multi:
            var cache: [String: AVAudioPCMBuffer] = [:]
            // Version-2 packs: undefined keys draw from a generic pool instead of the defined keys.
            for file in config.genericSoundFiles where cache[file] == nil {
                cache[file] = try Self.loadCanonical(folder.appendingPathComponent(file))
            }
            generic = config.genericSoundFiles.compactMap { cache[$0] }
            for (code, define) in config.defines {
                guard case .file(let file) = define else { continue }
                if cache[file] == nil {
                    let url = folder.appendingPathComponent(file)
                    // Upstream v2 packs list defines whose files were never shipped; with a
                    // generic pool those keys simply use the pool. Without one it is an error.
                    if !generic.isEmpty, !FileManager.default.fileExists(atPath: url.path) { continue }
                    cache[file] = try Self.loadCanonical(url)
                }
                map[code] = cache[file]
            }
            // Release sounds are optional: missing or undecodable files are skipped.
            for file in config.genericReleaseFiles {
                if cache[file] == nil, let b = Self.loadOptional(folder.appendingPathComponent(file)) { cache[file] = b }
                if let b = cache[file] { releaseGeneric.append(b) }
            }
            for (code, define) in config.keyUpDefines {
                guard case .file(let file) = define else { continue }
                if cache[file] == nil, let b = Self.loadOptional(folder.appendingPathComponent(file)) { cache[file] = b }
                if let b = cache[file] { upMap[code] = b }
            }
        }
        guard !map.isEmpty || !generic.isEmpty else { throw Error.noSounds(name) }
        buffers = map
        hasGenericPool = !generic.isEmpty
        fallbackPool = generic.isEmpty ? map.keys.sorted().map { map[$0]! } : generic
        releaseBuffers = upMap
        releasePool = releaseGeneric
        hasReleaseSounds = !upMap.isEmpty || !releaseGeneric.isEmpty
    }

    /// The buffer for a Mechvibes key code, or a deterministic fallback so no key is silent.
    /// Arrow keys exist under two code sets in the wild (libuiohook 574xx and iohook 610xx);
    /// either one satisfies the other.
    public func buffer(for mechvibesCode: Int) -> AVAudioPCMBuffer {
        if let b = buffers[mechvibesCode] { return b }
        if let alias = Self.aliases[mechvibesCode], let b = buffers[alias] { return b }
        return fallbackPool[abs(mechvibesCode) % fallbackPool.count]
    }

    private static let aliases: [Int: Int] = [
        57416: 61000, 61000: 57416,   // up
        57419: 61003, 61003: 57419,   // left
        57421: 61005, 61005: 57421,   // right
        57424: 61008, 61008: 57424,   // down
    ]

    /// The release (key-up) buffer for a key, or nil when the pack has none for it.
    public func releaseBuffer(for mechvibesCode: Int) -> AVAudioPCMBuffer? {
        if let b = releaseBuffers[mechvibesCode] { return b }
        if let alias = Self.aliases[mechvibesCode], let b = releaseBuffers[alias] { return b }
        guard !releasePool.isEmpty else { return nil }
        return releasePool[abs(mechvibesCode) % releasePool.count]
    }

    private static func loadOptional(_ url: URL) -> AVAudioPCMBuffer? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? loadCanonical(url)
    }

    private static func loadCanonical(_ url: URL) throws -> AVAudioPCMBuffer {
        guard FileManager.default.fileExists(atPath: url.path) else { throw Error.missingAudioFile(url.lastPathComponent) }
        let raw: AVAudioPCMBuffer
        if url.pathExtension.lowercased() == "ogg" {
            let decoded = try VorbisDecoder.decode(Data(contentsOf: url))
            raw = try AudioBuffers.buffer(fromInt16: decoded.samples, channels: decoded.channels, sampleRate: decoded.sampleRate)
        } else {
            raw = try AudioBuffers.buffer(fromFile: url)
        }
        return try AudioBuffers.toCanonical(raw)
    }
}
