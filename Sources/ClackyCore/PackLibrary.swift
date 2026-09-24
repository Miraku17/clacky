import Foundation

/// Finds packs on disk and seeds the user's packs folder from the app bundle.
public final class PackLibrary {
    public static var defaultPacksDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clacky/Packs", isDirectory: true)
    }

    public let packsDirectory: URL
    public let bundledPacksDirectory: URL?

    public init(packsDirectory: URL, bundledPacksDirectory: URL?) {
        self.packsDirectory = packsDirectory
        self.bundledPacksDirectory = bundledPacksDirectory
    }

    /// Creates the packs directory and, when it holds no packs, copies every bundled pack into it.
    public func prepare() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        guard availablePacks().isEmpty, let bundled = bundledPacksDirectory else { return }
        for folder in Self.packFolders(in: bundled) {
            try fm.copyItem(at: folder, to: packsDirectory.appendingPathComponent(folder.lastPathComponent))
        }
    }

    /// Sub-folders of the packs directory that contain a `config.json`, sorted by name.
    public func availablePacks() -> [URL] { Self.packFolders(in: packsDirectory) }

    public func load(named folderName: String) throws -> SoundPack {
        try SoundPack(folder: packsDirectory.appendingPathComponent(folderName, isDirectory: true))
    }

    private static func packFolders(in root: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { fm.fileExists(atPath: $0.appendingPathComponent("config.json").path) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}
