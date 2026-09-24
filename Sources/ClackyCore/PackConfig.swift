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

    private enum CodingKeys: String, CodingKey { case name, keyDefineType, sound, defines }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        keyDefineType = try c.decode(DefineType.self, forKey: .keyDefineType)
        sound = try c.decodeIfPresent(String.self, forKey: .sound)

        let raw = try c.decodeIfPresent([String: RawDefine?].self, forKey: .defines) ?? [:]
        var map: [Int: Define] = [:]
        for (key, value) in raw {
            guard let code = Int(key), let value else { continue }
            switch value {
            case .numbers(let n) where n.count >= 2:
                map[code] = .span(startMs: n[0], durationMs: n[1])
            case .numbers:
                continue
            case .string(let file):
                map[code] = .file(file)
            case .other:
                continue
            }
        }
        defines = map

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
        guard keyDefineType == .multi, let sound else { return [] }
        guard let open = sound.firstIndex(of: "{"), let close = sound.firstIndex(of: "}"), open < close else { return [] }
        let range = sound[sound.index(after: open)..<close].split(separator: "-", maxSplits: 1)
        guard range.count == 2, let lo = Int(range[0]), let hi = Int(range[1]), lo <= hi, hi - lo < 1_000 else { return [] }
        let prefix = sound[..<open], suffix = sound[sound.index(after: close)...]
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
