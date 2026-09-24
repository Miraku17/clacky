import Foundation

/// The Mechvibes `config.json` schema, reduced to what Clacky needs.
public struct PackConfig: Decodable, Equatable {
    public enum DefineType: String, Decodable { case single, multi }

    public enum Define: Equatable {
        /// `single` packs: a window into the shared sprite file, in milliseconds.
        case span(startMs: Double, durationMs: Double)
        /// `multi` packs: a file name relative to the pack folder.
        case file(String)
    }

    public let name: String?
    public let keyDefineType: DefineType
    public let sound: String?
    public let defines: [Int: Define]
    /// Release (key-up) sounds from `"<code>-up"` defines in version-2 packs.
    public let keyUpDefines: [Int: Define]
    /// Version-2 `soundup`: a generic release file or a `{a-b}` pattern.
    public let soundUp: String?

    private enum CodingKeys: String, CodingKey { case name, keyDefineType, sound, soundup, defines }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        keyDefineType = try c.decode(DefineType.self, forKey: .keyDefineType)
        sound = try c.decodeIfPresent(String.self, forKey: .sound)
        soundUp = try c.decodeIfPresent(String.self, forKey: .soundup)

        let raw = try c.decodeIfPresent([String: RawDefine?].self, forKey: .defines) ?? [:]
        var map: [Int: Define] = [:]
        var upMap: [Int: Define] = [:]
        for (key, value) in raw {
            guard let value else { continue }
            let isUp = key.hasSuffix("-up")
            guard let code = Int(isUp ? String(key.dropLast(3)) : key) else { continue }
            let define: Define
            switch value {
            case .numbers(let n) where n.count >= 2: define = .span(startMs: n[0], durationMs: n[1])
            case .string(let file): define = .file(file)
            default: continue
            }
            if isUp { upMap[code] = define } else { map[code] = define }
        }
        defines = map
        keyUpDefines = upMap

        if keyDefineType == .single, (sound ?? "").isEmpty {
            throw DecodingError.dataCorruptedError(
                forKey: .sound, in: c,
                debugDescription: "single packs need a \"sound\" file name")
        }
    }

    /// Tolerant wrapper: anything that is not `[start, duration]` or a
    /// string is `.other` and dropped by the caller.
    private enum RawDefine: Decodable {
        case numbers([Double])
        case string(String)
        case other

        init(from decoder: Decoder) throws {
            let s = try decoder.singleValueContainer()
            if let n = try? s.decode([Double].self) { self = .numbers(n) }
            else if let str = try? s.decode(String.self) { self = .string(str) }
            else { self = .other }
        }
    }

    /// Version-2 multi packs name a pool of generic sounds with a `{a-b}` pattern,
    /// e.g. `press/GENERIC_R{0-4}.mp3`, used for every key without a define.
    /// Empty for single packs and for multi packs without such a pattern.
    public var genericSoundFiles: [String] {
        keyDefineType == .multi ? Self.expand(sound) : []
    }

    /// Release-sound files: a `{a-b}` pattern expands, a plain name is one file.
    public var genericReleaseFiles: [String] {
        guard keyDefineType == .multi, let soundUp, !soundUp.isEmpty else { return [] }
        let expanded = Self.expand(soundUp)
        return expanded.isEmpty ? [soundUp] : expanded
    }

    /// `press/GENERIC_R{0-4}.mp3` → five names. Empty when there is no `{a-b}` pattern.
    static func expand(_ pattern: String?) -> [String] {
        guard let pattern,
              let open = pattern.firstIndex(of: "{"), let close = pattern.firstIndex(of: "}"), open < close else { return [] }
        let range = pattern[pattern.index(after: open)..<close].split(separator: "-", maxSplits: 1)
        guard range.count == 2, let lo = Int(range[0]), let hi = Int(range[1]), lo <= hi, hi - lo < 1_000 else { return [] }
        let prefix = pattern[..<open], suffix = pattern[pattern.index(after: close)...]
        return (lo...hi).map { "\(prefix)\($0)\(suffix)" }
    }

    public static func parse(_ data: Data) throws -> PackConfig {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PackConfig.self, from: data)
    }

    public static func load(from url: URL) throws -> PackConfig {
        try parse(Data(contentsOf: url))
    }
}
