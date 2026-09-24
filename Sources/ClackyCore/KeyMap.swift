/// macOS virtual key codes (Carbon `kVK_*`) → Mechvibes / libuiohook key codes.
public enum KeyMap {
    public static func mechvibesCode(forMacKeyCode code: Int64) -> Int? { table[code] }

    static let table: [Int64: Int] = [
        // Letters
        0x00: 30, 0x01: 31, 0x02: 32, 0x03: 33, 0x04: 35, 0x05: 34,   // A S D F H G
        0x06: 44, 0x07: 45, 0x08: 46, 0x09: 47, 0x0B: 48,             // Z X C V B
        0x0C: 16, 0x0D: 17, 0x0E: 18, 0x0F: 19, 0x10: 21, 0x11: 20,   // Q W E R Y T
        0x1F: 24, 0x20: 22, 0x22: 23, 0x23: 25,                       // O U I P
        0x25: 38, 0x26: 36, 0x28: 37,                                 // L J K
        0x2D: 49, 0x2E: 50,                                           // N M
        // Digits and symbols
        0x12: 2, 0x13: 3, 0x14: 4, 0x15: 5, 0x17: 6, 0x16: 7,         // 1 2 3 4 5 6
        0x1A: 8, 0x1C: 9, 0x19: 10, 0x1D: 11,                         // 7 8 9 0
        0x1B: 12, 0x18: 13, 0x21: 26, 0x1E: 27, 0x2A: 43,             // - = [ ] \
        0x29: 39, 0x27: 40, 0x2B: 51, 0x2F: 52, 0x2C: 53, 0x32: 41,   // ; ' , . / `
        // Control keys
        0x24: 28, 0x30: 15, 0x31: 57, 0x33: 14, 0x35: 1, 0x39: 58,    // Return Tab Space Backspace Esc CapsLock
        0x37: 3675, 0x36: 3676,                                       // Left/Right Command
        0x38: 42, 0x3C: 54,                                           // Left/Right Shift
        0x3A: 56, 0x3D: 3640,                                         // Left/Right Option
        0x3B: 29, 0x3E: 3613,                                         // Left/Right Control
        0x3F: 3677,                                                   // Fn → context-menu slot
        // Function row
        0x7A: 59, 0x78: 60, 0x63: 61, 0x76: 62, 0x60: 63, 0x61: 64,   // F1–F6
        0x62: 65, 0x64: 66, 0x65: 67, 0x6D: 68, 0x67: 87, 0x6F: 88,   // F7–F12
        0x69: 3639, 0x6B: 70, 0x71: 3653,                             // F13 F14 F15 → PrtSc ScrLk Pause
        // Navigation
        0x72: 3666, 0x73: 3655, 0x74: 3657, 0x75: 3667, 0x77: 3663, 0x79: 3665, // Help/Ins Home PgUp FwdDel End PgDn
        0x7B: 57419, 0x7C: 57421, 0x7D: 57424, 0x7E: 57416,           // ← → ↓ ↑
        // Keypad
        0x41: 83, 0x43: 55, 0x45: 78, 0x47: 69, 0x4B: 3637, 0x4C: 3612, 0x4E: 74, 0x51: 13,
        0x52: 82, 0x53: 79, 0x54: 80, 0x55: 81, 0x56: 75, 0x57: 76, 0x58: 77, 0x59: 71, 0x5B: 72, 0x5C: 73,
    ]
}
