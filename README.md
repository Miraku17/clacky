# Clacky

Mechanical keyboard sounds for every keystroke on macOS. Personal-use menu-bar
app; reads [Mechvibes](https://mechvibes.com) sound packs.

## Build and install

    ./build.sh --install

Needs the Swift toolchain (Command Line Tools). No Xcode.
First launch asks for Input Monitoring; grant it in
System Settings > Privacy & Security > Input Monitoring.

After every rebuild macOS may drop that grant. Toggle Clacky off and on in
that list and sounds return.

## The window

Menu-bar icon → Open Clacky… (or ⌘, while Clacky is frontmost). The drawn
keyboard lights as you type; click a key to hear it. Settings: Enabled,
volume, pack, key release sounds (packs that ship release samples: the
kbsim and "travel" packs), pitch variation, launch at login. The window
opens by itself at launch when Input Monitoring is not yet granted.

## Adding sound packs

Clacky ships 25 packs: the 18 Mechvibes packs and 7 from kbsim (MIT).

1. Click the menu-bar icon > Open Packs Folder.
2. Drop in a Mechvibes pack folder (it must contain `config.json`).
3. Pick it from the Sound Pack menu.

Both `single` (one `.ogg` sprite) and `multi` (one file per key) packs work.

## Development

    swift build                    # compile
    swift run ClackyCoreTests      # unit tests (no permissions needed); add a word to filter
    ./build.sh                     # build/Clacky.app without installing

Tests are a plain executable because XCTest does not ship with the Command
Line Tools.

Layout: `Sources/ClackyCore` is the testable library (decoding, pack loading,
key mapping, audio engine); `Sources/Clacky` is the app shell (event tap,
state, SwiftUI panel); `Sources/CVorbis` vendors `stb_vorbis.c`.

Bundled packs come from the Mechvibes repository (`Resources/Packs/LICENSE-MECHVIBES.txt`)
and from kbsim (`Resources/Packs/LICENSE-KBSIM.txt`), both MIT. `Tools/import-kbsim.sh`
regenerates the kbsim folders.

## App icon

`Resources/AppIcon.icns` is generated, not hand-drawn. To change it, edit
`Tools/make-icon.swift` and run:

    swift Tools/make-icon.swift build/icon && cp build/icon/AppIcon.icns Resources/

## If keys go silent

Read the app's own diagnostics (use the full path; `log` is also a zsh builtin):

    /usr/bin/log show --last 5m --info --predicate 'subsystem == "com.zianvalles.clacky"' --style compact

Healthy output shows `permission=true`, `event tap installed`, `pack loaded`,
then `keyDown` lines as you type. `permission=false` means Input Monitoring is
off for Clacky in System Settings. The app is signed with a requirement pinned
to its bundle identifier, so rebuilding no longer invalidates that grant.
