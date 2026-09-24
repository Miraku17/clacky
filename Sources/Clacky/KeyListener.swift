import CoreGraphics
import Foundation
import os
import ClackyCore

private let log = Logger(subsystem: "com.zianvalles.clacky", category: "tap")

/// Listen-only session event tap on the main run loop.
final class KeyListener {
    /// Called on the main thread with the macOS virtual key code of every non-repeat press.
    var onKeyPress: ((Int64) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var modifiers = ModifierTracker()
    private var eventCount = 0

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// Shows the system Input Monitoring prompt (once) and adds the app to the list.
    @discardableResult
    static func requestPermission() -> Bool { CGRequestListenEventAccess() }

    var isRunning: Bool { tap != nil }

    /// Installs the tap. Returns false when the system refuses, which means no permission.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .listenOnly, eventsOfInterest: mask,
                                           callback: keyListenerCallback, userInfo: refcon)
        else {
            log.error("tapCreate failed: Input Monitoring not granted for this build")
            return false
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src
        log.notice("event tap installed")
        return true
    }

    func stop() {
        if let src = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        if let port = tap { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        tap = nil
        source = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.error("tap disabled by system (\(type.rawValue)); re-enabling")
            if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
        case .keyDown:
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            eventCount += 1
            if eventCount <= 5 || eventCount % 200 == 0 { log.notice("keyDown code=\(code) total=\(self.eventCount)") }
            onKeyPress?(code)
        case .flagsChanged:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if modifiers.isPress(keyCode: code, flags: event.flags.rawValue) { onKeyPress?(code) }
        default:
            break
        }
    }
}

private func keyListenerCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                 refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<KeyListener>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
