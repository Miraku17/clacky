import AppKit
import SwiftUI
import Combine
import Foundation
import ServiceManagement
import os
import ClackyCore

private let log = Logger(subsystem: "com.zianvalles.clacky", category: "state")

final class AppState: ObservableObject {
    @Published var enabled: Bool { didSet { settings.enabled = enabled } }
    @Published var volume: Float { didSet { settings.volume = volume; audio.volume = volume } }
    @Published var releaseSounds: Bool { didSet { settings.releaseSounds = releaseSounds } }
    @Published var pitchVariation: Bool { didSet { settings.pitchVariation = pitchVariation } }
    @Published var stereo: Bool { didSet { settings.stereo = stereo } }
    @Published private(set) var mutedApps: MutedApps
    @Published var hotkeyEnabled: Bool { didSet { settings.hotkeyEnabled = hotkeyEnabled; applyHotkey() } }
    @Published private(set) var hotkeyUnavailable = false
    /// The frontmost app's bundle id, kept current from NSWorkspace notifications.
    @Published private(set) var frontmostBundleID: String?
    /// The last app in front that was not Clacky: what "Add current app" means while the window is open.
    @Published private(set) var lastOtherApp: NSRunningApplication?
    private var hotKey: GlobalHotKey?
    private var activationObserver: NSObjectProtocol?
    @Published private(set) var packHasReleaseSounds = false
    let pressed = PressedKeys()
    /// Set when launch found no Input Monitoring grant; the app opens its window so the instructions are visible.
    private var openWindowOnLaunchPending = false
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
    private var closeObserver: NSObjectProtocol?

    init() {
        library = PackLibrary(packsDirectory: PackLibrary.defaultPacksDirectory,
                              bundledPacksDirectory: Bundle.main.resourceURL?.appendingPathComponent("Packs"))
        enabled = settings.enabled
        volume = settings.volume
        releaseSounds = settings.releaseSounds
        pitchVariation = settings.pitchVariation
        stereo = settings.stereo
        mutedApps = MutedApps(bundleIDs: settings.mutedApps)
        hotkeyEnabled = settings.hotkeyEnabled
        audio.volume = settings.volume
        listener.onKeyPress = { [weak self] code in self?.keyPressed(code) }
        listener.onKeyRelease = { [weak self] code in self?.keyReleased(code) }
        // Refresh whenever the panel or the main window becomes key.
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        // The main window closing is the reliable moment to drop the Dock icon again.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] note in
            if (note.object as? NSWindow)?.title == "Clacky" { self?.windowDidClose() }
        }
        trackFrontmostApp()
        hotKey = GlobalHotKey(combo: .clackyToggle) { [weak self] in self?.enabled.toggle() }
        applyHotkey()
        refresh()
        openWindowOnLaunchPending = !hasPermission
        if !hasPermission {
            KeyListener.requestPermission()
            startPermissionPoll()
        }
    }

    /// Hot path. Runs on the main thread from the event tap.
    private var ignoredKeyLogs = 0
    private func keyPressed(_ macCode: Int64) {
        pressed.codes.insert(macCode)
        if ModifierTracker.isMomentary(keyCode: macCode) {
            // Caps Lock never reports a release; synthesise one so the drawn key un-lights.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.keyReleased(macCode) }
        }
        guard silenceReason == nil, let pack else {
            if ignoredKeyLogs < 5 {
                ignoredKeyLogs += 1
                log.notice("key ignored: enabled=\(self.enabled) packLoaded=\(self.pack != nil)")
            }
            return
        }
        let code = KeyMap.mechvibesCode(forMacKeyCode: macCode) ?? Int(macCode) + 100_000
        audio.play(pack.buffer(for: code), rate: currentRate(), pan: pan(for: macCode))
    }

    private func keyReleased(_ macCode: Int64) {
        pressed.codes.remove(macCode)
        guard silenceReason == nil, releaseSounds, let pack else { return }
        let code = KeyMap.mechvibesCode(forMacKeyCode: macCode) ?? Int(macCode) + 100_000
        if let buffer = pack.releaseBuffer(for: code) { audio.play(buffer, rate: currentRate(), pan: pan(for: macCode)) }
    }

    private func currentRate() -> Float { pitchVariation ? PitchVariation.rate() : 1 }

    private func pan(for macCode: Int64) -> Float { stereo ? KeyboardLayout.pan(forMacKeyCode: macCode) : 0 }

    // MARK: Muting

    /// Why keystrokes are silent right now, or nil when they play.
    var silenceReason: SilenceReason? {
        SoundGate.reason(enabled: enabled, frontmostBundleID: frontmostBundleID, mutedApps: mutedApps)
    }

    var statusText: String {
        let name: String?
        if case .mutedIn(let id) = silenceReason { name = appName(for: id) } else { name = nil }
        return StatusText.make(hasPermission: hasPermission, listening: isListening, reason: silenceReason, appName: name)
    }

    /// Green when clicking, grey when deliberately silent, orange when access is missing.
    var statusColor: Color {
        if !hasPermission { return .orange }
        if silenceReason != nil { return .secondary }
        return isListening ? .green : .orange
    }

    func muteApp(_ bundleID: String) {
        mutedApps.add(bundleID)
        settings.mutedApps = mutedApps.bundleIDs
    }

    func unmuteApp(_ bundleID: String) {
        mutedApps.remove(bundleID)
        settings.mutedApps = mutedApps.bundleIDs
    }

    /// Running apps with a Dock presence that are not muted yet, for the "Add app" menu.
    var mutableRunningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .filter { $0.bundleIdentifier != MutedApps.ownBundleID && !mutedApps.contains($0.bundleIdentifier) }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
    }

    func appName(for bundleID: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = running.localizedName { return name }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    func appIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func trackFrontmostApp() {
        let front = NSWorkspace.shared.frontmostApplication
        frontmostBundleID = front?.bundleIdentifier
        if front?.bundleIdentifier != MutedApps.ownBundleID { lastOtherApp = front }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.frontmostBundleID = app?.bundleIdentifier
            if let app, app.bundleIdentifier != MutedApps.ownBundleID { self?.lastOtherApp = app }
        }
    }

    private func applyHotkey() {
        guard let hotKey else { return }
        if hotkeyEnabled {
            hotkeyUnavailable = !hotKey.register()
            if hotkeyUnavailable { log.error("hotkey \(hotKey.combo.display, privacy: .public) is taken") }
        } else {
            hotKey.unregister()
            hotkeyUnavailable = false
        }
    }

    /// A click on the drawn keyboard: press now, release 80 ms later.
    func previewKey(_ macCode: Int64) {
        keyPressed(macCode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.keyReleased(macCode) }
    }

    /// True exactly once, on the launch that found no keyboard access.
    func consumeOpenOnLaunch() -> Bool {
        defer { openWindowOnLaunchPending = false }
        return openWindowOnLaunchPending
    }

    func windowDidAppear() {
        openWindowOnLaunchPending = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidClose() {
        NSApp.setActivationPolicy(.accessory)
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
        if hasPermission != isListening || !hasPermission {
            log.notice("permission=\(self.hasPermission) listening=\(self.listener.isRunning)")
        }
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
            packHasReleaseSounds = loaded?.hasReleaseSounds ?? false
            settings.selectedPackName = name
            packError = nil
            log.notice("pack loaded: \(name, privacy: .public) keys=\(loaded?.keyCount ?? 0) generic=\(loaded?.hasGenericPool ?? false)")
            if shouldPreview { preview() }
        case .ignore:
            return
        case .revert:
            if case .failure(let error) = result {
                packError = "\(name): \(error.localizedDescription)"
                log.error("pack failed: \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
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
