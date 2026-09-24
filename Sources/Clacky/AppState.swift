import AppKit
import Combine
import Foundation
import ServiceManagement
import ClackyCore

final class AppState: ObservableObject {
    @Published var enabled: Bool { didSet { settings.enabled = enabled } }
    @Published var volume: Float { didSet { settings.volume = volume; audio.volume = volume } }
    @Published private(set) var availablePacks: [String] = []
    @Published private(set) var packInfos: [PackInfo] = []
    @Published private(set) var selectedPack: String = ""
    @Published private(set) var isListening = false
    @Published private(set) var isLoadingPack = false
    @Published private(set) var hasPermission = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var lastError: String?

    private let settings = Settings()
    private let audio = AudioEngine()
    private let library: PackLibrary
    private let listener = KeyListener()
    private var pack: SoundPack?
    private var switcher = PackSwitcher()

    // Error sources, combined into `lastError`. Each clears itself when its step succeeds.
    private var packError: String?
    private var tapError: String?
    private var prepareError: String?
    private var loginError: String?

    private var permissionPoll: Timer?
    private var windowObserver: NSObjectProtocol?

    init() {
        library = PackLibrary(packsDirectory: PackLibrary.defaultPacksDirectory,
                              bundledPacksDirectory: Bundle.main.resourceURL?.appendingPathComponent("Packs"))
        enabled = settings.enabled
        volume = settings.volume
        audio.volume = settings.volume
        listener.onKeyPress = { [weak self] code in self?.keyPressed(code) }
        // The MenuBarExtra panel is the app's only window; refresh whenever it becomes key.
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        refresh()
        if !hasPermission {
            KeyListener.requestPermission()
            startPermissionPoll()
        }
    }

    /// Hot path. Runs on the main thread from the event tap.
    private func keyPressed(_ macCode: Int64) {
        guard enabled, let pack else { return }
        let code = KeyMap.mechvibesCode(forMacKeyCode: macCode) ?? Int(macCode) + 100_000
        audio.play(pack.buffer(for: code))
    }

    /// Re-checks permission, installs the tap when possible, rescans packs,
    /// and loads the remembered (or first) pack when none is loaded.
    func refresh() {
        ensureListening()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        do {
            try library.prepare()
            prepareError = nil
        } catch {
            prepareError = error.localizedDescription
        }
        packInfos = library.packInfos()
        availablePacks = packInfos.map(\.folderName)
        if pack == nil, let first = availablePacks.first {
            let wanted = settings.selectedPackName ?? first
            selectPack(availablePacks.contains(wanted) ? wanted : first)
        }
        publishErrors()
    }

    private func ensureListening() {
        hasPermission = KeyListener.hasPermission
        guard hasPermission else { return }
        if listener.start() {
            tapError = nil
            permissionPoll?.invalidate()
            permissionPoll = nil
        } else {
            tapError = "Could not install the keyboard listener. Toggle Clacky off and on in Input Monitoring."
        }
        isListening = listener.isRunning
    }

    /// Plays the loaded pack's Space sound so a pack can be auditioned from the panel.
    func preview() {
        guard let pack else { return }
        audio.play(pack.buffer(for: 57))
    }

    /// Until Input Monitoring is granted, check every couple of seconds so the
    /// tap goes live the moment the user flips the switch in System Settings.
    private func startPermissionPoll() {
        guard permissionPoll == nil else { return }
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.ensureListening()
            self.publishErrors()
        }
    }

    /// `preview` plays a sample once the pack is in, which is what a person picking
    /// from the list wants; the automatic load at launch stays silent.
    func selectPack(_ name: String, preview: Bool = false) {
        guard switcher.request(name) else { return }
        selectedPack = switcher.selected
        isLoadingPack = true
        DispatchQueue.global(qos: .userInitiated).async { [library] in
            let result = Result { try library.load(named: name) }
            DispatchQueue.main.async { self.finishLoading(name: name, result: result, preview: preview) }
        }
    }

    private func finishLoading(name: String, result: Result<SoundPack, Error>, preview shouldPreview: Bool) {
        let loaded = try? result.get()
        switch switcher.finished(name, success: loaded != nil) {
        case .apply:
            pack = loaded
            settings.selectedPackName = name
            packError = nil
            if shouldPreview { preview() }
        case .ignore:
            return
        case .revert:
            if case .failure(let error) = result { packError = "\(name): \(error.localizedDescription)" }
        }
        isLoadingPack = switcher.inFlight != nil
        selectedPack = switcher.selected
        publishErrors()
    }

    private func publishErrors() {
        lastError = packError ?? tapError ?? audio.lastError ?? prepareError ?? loginError
    }

    func requestPermission() {
        KeyListener.requestPermission()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        startPermissionPoll()
        refresh()
    }

    func openPacksFolder() { NSWorkspace.shared.open(library.packsDirectory) }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Launch at login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        publishErrors()
    }
}
