import AppKit
import Combine
import Foundation
import ServiceManagement
import ClackyCore

final class AppState: ObservableObject {
    @Published var enabled: Bool { didSet { settings.enabled = enabled } }
    @Published var volume: Float { didSet { settings.volume = volume; audio.volume = volume } }
    @Published private(set) var availablePacks: [String] = []
    @Published private(set) var selectedPack: String = ""
    @Published private(set) var hasPermission = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var lastError: String?

    private let settings = Settings()
    private let audio = AudioEngine()
    private let library: PackLibrary
    private let listener = KeyListener()
    private var pack: SoundPack?

    init() {
        library = PackLibrary(packsDirectory: PackLibrary.defaultPacksDirectory,
                              bundledPacksDirectory: Bundle.main.resourceURL?.appendingPathComponent("Packs"))
        enabled = settings.enabled
        volume = settings.volume
        audio.volume = settings.volume
        listener.onKeyPress = { [weak self] code in self?.keyPressed(code) }
        refresh()
        if !hasPermission { KeyListener.requestPermission() }
    }

    /// Hot path. Runs on the main thread from the event tap.
    private func keyPressed(_ macCode: Int64) {
        guard enabled, let pack else { return }
        let code = KeyMap.mechvibesCode(forMacKeyCode: macCode) ?? Int(macCode) + 100_000
        audio.play(pack.buffer(for: code))
    }

    /// Called whenever the panel opens: re-check permission, rescan packs, load the first pack if none is loaded.
    func refresh() {
        hasPermission = KeyListener.hasPermission
        if hasPermission { listener.start() }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        do { try library.prepare() } catch { lastError = error.localizedDescription }
        availablePacks = library.availablePacks().map(\.lastPathComponent)
        if pack == nil, let first = availablePacks.first {
            let wanted = settings.selectedPackName ?? first
            selectPack(availablePacks.contains(wanted) ? wanted : first)
        }
    }

    func selectPack(_ name: String) {
        guard !name.isEmpty, name != selectedPack || pack == nil else { return }
        selectedPack = name
        DispatchQueue.global(qos: .userInitiated).async { [library] in
            let result = Result { try library.load(named: name) }
            DispatchQueue.main.async { self.finishLoading(name: name, result: result) }
        }
    }

    private func finishLoading(name: String, result: Result<SoundPack, Error>) {
        switch result {
        case .success(let loaded):
            pack = loaded
            settings.selectedPackName = name
            lastError = nil
        case .failure(let error):
            lastError = "\(name): \(error.localizedDescription)"
            if let current = pack { selectedPack = current.folder.lastPathComponent }
        }
    }

    func requestPermission() {
        KeyListener.requestPermission()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        refresh()
    }

    func openPacksFolder() { NSWorkspace.shared.open(library.packsDirectory) }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            lastError = nil
        } catch {
            lastError = "Launch at login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
