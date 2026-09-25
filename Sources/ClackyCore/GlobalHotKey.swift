import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut via Carbon's RegisterEventHotKey, which needs
/// no Accessibility or Input Monitoring permission. The handler runs on the main thread.
public final class GlobalHotKey {
    public struct Combo: Equatable {
        public let keyCode: UInt32
        public let modifiers: UInt32
        public let display: String

        /// ⌃⌥⌘C: toggles Clacky's sounds.
        public static let clackyToggle = Combo(keyCode: UInt32(kVK_ANSI_C),
                                               modifiers: UInt32(controlKey | optionKey | cmdKey),
                                               display: "⌃⌥⌘C")
    }

    public let combo: Combo
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let id: UInt32

    private static var nextID: UInt32 = 1
    private static var handlers: [UInt32: () -> Void] = [:]

    public var isRegistered: Bool { hotKeyRef != nil }

    public init(combo: Combo, handler: @escaping () -> Void) {
        self.combo = combo
        self.handler = handler
        self.id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
    }

    deinit { unregister() }

    /// Returns false when the system refuses the combination (another app owns it).
    @discardableResult
    public func register() -> Bool {
        if isRegistered { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, let handler = GlobalHotKey.handlers[hotKeyID.id] else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async(execute: handler)
            return noErr
        }, 1, &spec, nil, &handlerRef)
        guard installStatus == noErr else { return false }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4B59) /* 'CLKY' */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
            return false
        }
        hotKeyRef = ref
        GlobalHotKey.handlers[id] = handler
        return true
    }

    public func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        GlobalHotKey.handlers[id] = nil
    }
}
