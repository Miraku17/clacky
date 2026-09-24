# Clacky v2 — Application Window, Live Keyboard, Sound Options

Date: 2026-09-25
Status: approved design, pre-implementation
Extends: `2026-09-25-clacky-design.md` (v1). Everything in v1 stays unless
this document says otherwise.

## 1. Purpose

Give Clacky a real application window: a drawing of the user's MacBook Air
keyboard that lights up as they type and plays a key's sound when clicked,
next to the full set of settings. Add two sound options (key-release
sounds, pitch variation) and seven more switch recordings from kbsim.

Success: from the menu-bar panel, "Open Clacky…" shows the window; typing
anywhere lights the matching keys; clicking a drawn key plays it; turning
on "Key release sounds" adds the up-stroke on packs that have one; every
pack in the list, including the seven new ones, loads and plays.

## 2. Non-goals

- Non-US or non-MacBook layouts (the layout table is data, so more can come later).
- Editing packs, per-key custom sounds, mouse sounds.
- Function-row media actions: on a MacBook the F-keys send system events
  unless Fn is held, so they do not light up by default.
- Localisation.

## 3. Sound options

### 3.1 Key-release sounds
- Version-2 Mechvibes packs carry `soundup` (a generic release file or a
  `{a-b}` pattern) and `"<code>-up"` defines. `PackConfig` gains
  `keyUpDefines: [Int: Define]` and `genericReleaseFiles: [String]`.
- `SoundPack` loads them into `releaseBuffers` and `releasePool`, exposes
  `releaseBuffer(for:) -> AVAudioPCMBuffer?` (defined → arrow alias →
  pool pick → nil) and `hasReleaseSounds`. Missing release files are
  skipped, never fatal: release is optional.
- `KeyListener` adds `keyUp` to its mask and an `onKeyRelease` callback.
  `ModifierTracker` gains `event(keyCode:flags:) -> ModifierEvent?`
  (`.press` / `.release` / nil); `isPress` stays and delegates to it.
- `AppState.keyReleased` plays the release buffer when the setting is on.
- Setting `releaseSounds`, default true. The toggle's caption reads
  "This pack has no release sounds" when `hasReleaseSounds` is false.

### 3.2 Pitch variation
- `PitchVariation.rate(amount:random:)` returns `1 + amount * (2r − 1)`;
  amount is 0.03 (±3 %). Pure function, unit tested.
- `AudioEngine` voices become player → `AVAudioUnitVarispeed` → mixer.
  `play(_:rate:)` sets the voice's rate (clamped 0.5…2.0) before playing.
- Setting `pitchVariation`, default true.

### 3.3 More packs (kbsim, MIT)
- `Tools/import-kbsim.sh` sparse-clones `tplai/kbsim`, copies
  `src/assets/audio/<pack>/{press,release}` for `alpaca, blackink,
  bluealps, boxnavy, buckling, redink, topre` into
  `Resources/Packs/kbsim-<pack>/`, writes a version-2 `config.json` per
  pack, and copies the repository LICENSE to
  `Resources/Packs/LICENSE-KBSIM.txt`.
- Display names: Alpaca (linear), Gateron Ink Black, Blue Alps, Kailh Box
  Navy, IBM Buckling Spring, Gateron Ink Red, Topre (kbsim).
- Config written per pack:
  `sound: press/GENERIC_R{0-4}.mp3`, `soundup: release/GENERIC.mp3`,
  defines 14/28/57 → press/BACKSPACE|ENTER|SPACE.mp3 and `-up` twins →
  release/…; `key_define_type: multi`, `version: 2`.
- The existing "every bundled pack loads" test covers them; a second
  assertion checks each kbsim pack reports `hasReleaseSounds == true`.

## 4. The window

### 4.1 Scene and lifecycle
- A SwiftUI `Window("Clacky", id: "main")` scene beside the existing
  `MenuBarExtra`. Default size 900×540, minimum 760×460.
- Opened from the panel's "Open Clacky…" button and with ⌘, when Clacky
  is frontmost. On launch, when Input Monitoring is not granted, the
  window opens by itself so the access instructions are visible without
  hunting for a menu-bar icon. The trigger is `onAppear` of the
  menu-bar label view, which is on screen from launch.
- While the window is open the app's activation policy is `.regular`
  (Dock icon, ⌘-Tab); when it closes it returns to `.accessory`.

### 4.2 Layout
```
┌────────────────────────────────────────────────────────────────┐
│ Clacky                                                          │
│ ┌──────────────┐  ┌────────────────────────────────────────┐   │
│ │ Enabled  [⏻] │  │ esc F1 F2 … F12  ◉                     │   │
│ │ Volume ──●── │  │ ` 1 2 3 4 5 6 7 8 9 0 - = delete        │   │
│ │              │  │ tab q w e r t y u i o p [ ] \           │   │
│ │ Sound pack   │  │ caps a s d f g h j k l ; ' return       │   │
│ │ ▢ CherryMX…  │  │ shift z x c v b n m , . / shift         │   │
│ │ ▣ Holy Pandas│  │ fn ctrl opt cmd  space  cmd opt ◀ ▲▼ ▶  │   │
│ │ ▢ Alpaca     │  └────────────────────────────────────────┘   │
│ │  …           │  Click a key to hear it. Keys light as you type│
│ │ [✓] Release  │                                                 │
│ │ [✓] Pitch    │                                                 │
│ │ [ ] Login    │                                                 │
│ └──────────────┘                                                 │
│ ● Listening                                   Open packs folder │
└────────────────────────────────────────────────────────────────┘
```
Left column 260 pt: Enabled switch, volume, pack list (keycap rows from
v1, reused), the three toggles. Right: the keyboard, scaled to the
available width, keeping its aspect ratio. Footer: status dot and text
(same states as the panel), the access button when needed, Open packs
folder.

### 4.3 Keyboard view
- `KeyboardLayout.macBookAirUS: [[KeyCap]]` in `ClackyCore`. `KeyCap` has
  `label`, `macKeyCode: Int64?` (nil for the Touch ID key), `width` in
  key units, `height` (0.6 for the function row, 1 otherwise). Row widths
  all total 14.5 units. The arrow cluster is left (1u), an up/down pair
  stacked in one 1u column, right (1u).
- Rendering: a `GeometryReader` computes the unit from the width; each
  key is a rounded rectangle with the label, filled with the accent colour
  while pressed and fading back over 180 ms.
- `AppState.pressedKeys: Set<Int64>` is fed by key down/up and modifier
  press/release from the tap. Clicking a key calls
  `AppState.previewKey(_:)`, which plays the press sound at once and the
  release sound (if enabled and available) 80 ms later.

## 5. Data flow additions

```
tap keyDown  → pressedKeys.insert → press buffer  → engine.play(rate)
tap keyUp    → pressedKeys.remove → release buffer (if on) → engine.play(rate)
flagsChanged → ModifierTracker.event → press/release as above
window click → previewKey → press now, release after 80 ms
```

## 6. Error handling

| Situation | Behaviour |
|-----------|-----------|
| Pack has no release sounds | Toggle stays enabled, caption explains; keyUp is silent. |
| Release file listed but missing | Skipped at load; no error shown. |
| kbsim import script cannot reach GitHub | Script exits non-zero with the URL; repo state untouched. |
| Window closed while a key is held | `pressedKeys` clears on keyUp as usual; no stuck highlight because state lives in AppState, not the view. |
| Varispeed rate out of range | Clamped in `AudioEngine`. |

## 7. Settings persistence

`Settings` gains `releaseSounds: Bool` (default true) and
`pitchVariation: Bool` (default true).

## 8. Testing

Unit (TestKit):
- `PackConfig`: `-up` defines land in `keyUpDefines` and not in `defines`;
  `soundup` plain name → one generic release file; `{a-b}` pattern expands.
- `SoundPack`: release buffer resolution (defined, alias, pool, nil);
  missing release file is skipped; `hasReleaseSounds` true/false.
- `ModifierTracker.event`: press, release, second-key, caps lock.
- `PitchVariation`: r = 0 → 1 − amount, r = 1 → 1 + amount, r = 0.5 → 1.
- `AudioEngine.play(_:rate:)` clamps and does not error.
- `KeyboardLayout`: every row totals 14.5 units; every non-nil code is
  unique; every non-nil code maps in `KeyMap` or is a modifier/fn.
- Bundled packs: all load; kbsim packs report release sounds.
- `Settings` defaults for the two new keys.

Manual: open window from the panel; type and watch keys light; click keys;
toggle release sounds on a kbsim pack and a Cherry pack; toggle pitch
variation and hold a letter; close window and confirm the Dock icon
disappears; quit and relaunch with access revoked and confirm the window
opens on its own.

## 9. Resolved defaults

- Highlight fade 180 ms; preview release delay 80 ms; pitch ±3 %.
- Window id `main`; pack folder prefix `kbsim-`.
- The panel keeps its current design; it only gains "Open Clacky…".
