# Clacky — Mechanical Keyboard Sounds for macOS

Date: 2026-09-25
Status: approved design, pre-implementation

## 1. Purpose

A personal-use macOS menu-bar app that plays mechanical keyboard switch sounds
on every keystroke, system-wide, like Keeby or Mechvibes. It reads the open
Mechvibes sound-pack format so any community pack can be dropped in.

Success looks like: launch the app once, grant Input Monitoring, and every key
press anywhere on the Mac produces a low-latency switch sound from the chosen
pack. Volume, pack choice, and on/off are one click away in the menu bar.

Owner: single user, Apple Silicon MacBook, macOS 26.3. No distribution, no
App Store, no notarization.

## 2. Non-goals for v1

- Key-up (release) sounds
- Per-application muting
- Random pitch variation
- A separate settings window (the menu bar menu is the whole UI)
- Windows or Linux support
- Mac App Store sandboxing (global key monitoring is impossible under it)

## 3. Toolchain and constraints

- Swift 6.2 with Command Line Tools only. No Xcode is installed, so the
  project is a Swift Package (`Package.swift`) built with `swift build`, and
  a shell script assembles the `.app` bundle.
- Minimum deployment target: macOS 14 (SwiftUI `MenuBarExtra` and
  `SMAppService` are available; the dev machine is 26.3).
- macOS cannot decode Ogg Vorbis with AVFoundation. Most Mechvibes "single"
  packs ship one `.ogg` sprite, so the package includes `stb_vorbis.c`
  (public domain, single file) as a C target.

## 4. Architecture

One Swift package, `Clacky`, with these targets:

| Target        | Kind             | Purpose                                              |
|---------------|------------------|------------------------------------------------------|
| `CVorbis`     | C library target | Wraps `stb_vorbis.c`; exposes decode-to-PCM          |
| `ClackyCore`  | Swift library    | Pack loading, key mapping, audio engine, settings    |
| `Clacky`      | Executable       | SwiftUI menu-bar app, event tap wiring, app lifecycle|
| `ClackyCoreTests` | Test target  | Unit tests for `ClackyCore`                          |

Splitting `ClackyCore` from the executable keeps the testable logic free of
AppKit/SwiftUI lifecycle code.

### 4.1 Components

**KeyListener** (`Clacky`)
- Installs a session-level, listen-only `CGEventTap` for `keyDown`, `keyUp`,
  and `flagsChanged`.
- Drops events where `kCGKeyboardEventAutorepeat != 0`.
- For `flagsChanged`, determines press vs release by comparing the modifier
  flag for that key code against the previous flags state; only press is
  forwarded in v1.
- Emits `(macKeyCode: Int64, isDown: Bool)` through a callback. Nothing else
  happens on the tap thread beyond a dictionary lookup and a buffer schedule.
- Re-enables the tap if the system disables it (`tapDisabledByTimeout` or
  `tapDisabledByUserInput`).
- Depends on: Input Monitoring permission (`CGPreflightListenEventAccess`,
  `CGRequestListenEventAccess`).

**KeyMap** (`ClackyCore`)
- Pure function: macOS virtual key code (Carbon `kVK_*` values) → Mechvibes
  key code (libuiohook-style integers, e.g. Space = 57, Enter = 28, Backspace
  = 14, letters 16–25 / 30–38 / 44–50, arrows 61000/61003/61005/61008,
  modifiers 29/42/54/56/3640/3675/3676, F1–F10 = 59–68, F11 = 87, F12 = 88).
- Returns `nil` for keys with no Mechvibes equivalent.
- Fully covered by a unit test that checks every entry in the table and that
  the table has no duplicate Mechvibes targets for the main alphanumeric
  block.

**SoundPack** (`ClackyCore`)
- `init(folder: URL) throws` loads `config.json` and produces
  `[MechvibesKeyCode: AVAudioPCMBuffer]`.
- Supports both Mechvibes `key_define_type` values:
  - `"single"`: one audio file named by `sound`; `defines` maps key-code
    string → `[startMs, durationMs]`. The file is decoded once and sliced
    into per-key buffers.
  - `"multi"`: `defines` maps key-code string → file name; each file is
    decoded into its own buffer.
- `defines` entries that are `null` or missing are skipped.
- Decoding: `.ogg` via `CVorbis`; everything else via `AVAudioFile`. All
  buffers are converted to the engine's processing format (Float32,
  48 kHz if the file differs, stereo or mono preserved) at load time so
  playback never resamples.
- `buffer(for keyCode:) -> AVAudioPCMBuffer` returns the mapped buffer, or a
  deterministic-random fallback from the pack's buffers if the key is unmapped.
  No key is ever silent.
- Exposes `name` (from config, falling back to the folder name).

**AudioEngine** (`ClackyCore`)
- Owns one `AVAudioEngine`, one `AVAudioMixerNode`, and a fixed pool of 16
  `AVAudioPlayerNode`s attached to the mixer.
- `play(_ buffer:)` picks the next node round-robin, stops it if busy,
  schedules the buffer, and plays. This lets rapid overlapping keystrokes all
  sound without allocations on the hot path.
- `volume: Float` (0…1) sets the mixer's output volume.
- Starts the engine lazily on first play; restarts on
  `AVAudioEngineConfigurationChange` (e.g. headphones plugged in).

**Settings** (`ClackyCore`)
- `UserDefaults`-backed: `enabled: Bool` (default true), `volume: Float`
  (default 0.5), `selectedPackName: String?`.
- Launch-at-login is not stored here; `SMAppService.mainApp.status` is the
  source of truth.

**PackLibrary** (`ClackyCore`)
- Knows the packs directory: `~/Library/Application Support/Clacky/Packs/`.
- On first launch, creates the directory and copies the bundled default pack
  into it if it is empty.
- `availablePacks() -> [URL]` lists subfolders that contain a `config.json`.
- `load(named:) throws -> SoundPack`.

**AppState** (`Clacky`, `@Observable`)
- Holds the live `SoundPack`, `AudioEngine`, `Settings`, permission status,
  and `lastError: String?`.
- Wires `KeyListener` callback → `KeyMap` → `SoundPack.buffer(for:)` →
  `AudioEngine.play`. Skips when `enabled == false`.
- Switching packs loads the new pack on a background queue and swaps it
  atomically; on failure it keeps the previous pack and sets `lastError`.

**Menu bar UI** (`Clacky`, SwiftUI `MenuBarExtra`)
Menu contents, top to bottom:
1. Toggle "Enabled" (⌘E shortcut when the menu is open)
2. Volume slider (0–100 %)
3. Picker "Sound Pack" listing `PackLibrary.availablePacks()`, refreshed each
   time the menu opens
4. "Open Packs Folder" (reveals the directory in Finder)
5. Divider
6. If permission is missing: "Grant Input Monitoring…" which opens
   `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
7. If `lastError` is set: a disabled menu item showing the message
8. Toggle "Launch at Login" (`SMAppService`)
9. "Quit Clacky" (⌘Q)

Menu bar icon: an SF Symbol (`keyboard`), rendered dimmed when disabled.

## 5. Data flow

```
CGEventTap (keyDown / flagsChanged press, non-repeat)
   │  macKeyCode
   ▼
KeyMap.mechvibesCode(for:)  ── nil ──▶ SoundPack fallback buffer
   │
   ▼
SoundPack.buffer(for:)
   │  AVAudioPCMBuffer (pre-sliced, engine format)
   ▼
AudioEngine.play(buffer)  → next free AVAudioPlayerNode → mixer → output
```

The tap callback does no allocation, no file I/O, and no logging in the hot
path. Target end-to-end latency: under 20 ms on the default output device.

## 6. Sound pack storage and format

- Directory: `~/Library/Application Support/Clacky/Packs/<PackName>/`
- Required file: `config.json` (Mechvibes schema, fields used: `name`,
  `key_define_type`, `sound`, `defines`; `id` and `includes_numpad` are read
  but ignored).
- Audio files are referenced relative to the pack folder.
- The app bundle carries one default pack under `Contents/Resources/Packs/`.
  The default is a Cherry MX Blue style pack taken from the Mechvibes
  open-source repository (MIT). Its license file is copied alongside.

## 7. Permissions and error handling

| Situation | Behaviour |
|-----------|-----------|
| Input Monitoring not granted at launch | Call `CGRequestListenEventAccess()` (shows the system prompt). Menu shows "Grant Input Monitoring…". Re-check every time the menu opens and when the app becomes active; install the tap as soon as access is granted. |
| Tap disabled by the system | Re-enable inside the callback via `CGEvent.tapEnable`. |
| Pack fails to parse or decode | Keep the previous pack, set `lastError` with the pack name and reason, show it in the menu. |
| Packs directory missing or empty | Recreate it and re-copy the bundled default pack. |
| Audio engine fails to start | Set `lastError`; retry on next key press. |
| Output device changes | Handle `AVAudioEngineConfigurationChange`: stop, reconnect nodes, restart. |

Ad-hoc code signing and TCC: Input Monitoring grants are tied to the code
signature. Every rebuild produces a new ad-hoc signature, so macOS may drop
the grant. The build script prints a reminder, and the menu item makes
re-granting a two-click job. If this becomes annoying, the follow-up is a
self-signed signing certificate in Keychain, which keeps the identity stable
across builds.

## 8. Build, packaging, install

`build.sh` at the repo root:
1. `swift build -c release --arch arm64`
2. Assemble `build/Clacky.app/Contents/{MacOS,Resources}`:
   - copy the `Clacky` binary into `MacOS/`
   - copy `Resources/Info.plist` (`CFBundleIdentifier = com.zianvalles.clacky`,
     `LSUIElement = true` so there is no Dock icon, `CFBundleName`,
     `CFBundleShortVersionString`, `NSHumanReadableCopyright`)
   - copy `Resources/Packs/` (default pack) into `Resources/`
   - copy `Resources/AppIcon.icns` if present
3. `codesign --force --sign - --deep build/Clacky.app`
4. With `--install`: `rm -rf /Applications/Clacky.app && cp -R build/Clacky.app /Applications/`
   then `open /Applications/Clacky.app`.

`swift build` and `swift test` work directly for development; only the bundle
step needs the script.

## 9. Testing

Unit tests (`swift test`, no permissions or audio device needed):
- `KeyMapTests`: every Carbon key code in the table maps to the expected
  Mechvibes code; unmapped codes return nil; no duplicate targets in the
  alphanumeric block.
- `SoundPackConfigTests`: decodes fixture `config.json` files for `single`
  and `multi` types; tolerates `null` defines; rejects missing `sound` for
  `single`; reports a useful error for malformed JSON.
- `SpriteSlicingTests`: given a synthetic PCM buffer and a define of
  `[startMs, durationMs]`, the slice has the expected frame count and
  content; slices that run past the end are clamped, not crashed.
- `VorbisDecodeTests`: a small bundled `.ogg` fixture decodes to the expected
  channel count, sample rate, and approximate frame count.
- `PackLibraryTests`: with a temporary directory, lists only subfolders that
  contain `config.json`; copies the default pack when empty.

Manual acceptance (documented in README):
1. `./build.sh --install`
2. Grant Input Monitoring when prompted.
3. Type in any app; hear sounds. Hold a key; hear one sound, not a stream.
4. Change volume and pack from the menu; changes apply immediately.
5. Toggle Enabled off; silence. On; sounds.
6. Quit and relaunch; settings are remembered.

## 10. Resolved defaults

- App name: Clacky. Bundle id: `com.zianvalles.clacky`.
- Repo: `~/Projects/clacky`, git-tracked.
- Default volume 50 %, enabled on launch, launch-at-login off until toggled.
- Modifier keys (Shift, Cmd, Ctrl, Opt, Fn) make a sound on press, like real
  boards. Caps Lock included.
- Fn-row media keys that arrive as `NX_SYSDEFINED` events are ignored.
