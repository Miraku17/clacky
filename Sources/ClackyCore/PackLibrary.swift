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

    /// Creates the packs directory and copies in every bundled pack the user does not
    /// already have. Existing folders are never touched, so edits survive updates.
    public func prepare() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        guard let bundled = bundledPacksDirectory else { return }
        for folder in Self.packFolders(in: bundled) {
            let target = packsDirectory.appendingPathComponent(folder.lastPathComponent)
            if !fm.fileExists(atPath: target.path) { try fm.copyItem(at: folder, to: target) }
        }
    }

    /// One entry per available pack with the display name from its config (folder name when absent).
    public func packInfos() -> [PackInfo] {
        availablePacks().map { folder in
            let name = (try? PackConfig.load(from: folder.appendingPathComponent("config.json")))?.name
            let display = (name?.isEmpty == false) ? name! : folder.lastPathComponent
            return PackInfo(folderName: folder.lastPathComponent, displayName: display, folder: folder)
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

public struct PackInfo: Equatable, Identifiable {
    public var id: String { folderName }
    public let folderName: String
    public let displayName: String
    public let folder: URL
}
