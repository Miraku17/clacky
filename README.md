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

## Adding sound packs

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

Default pack: CherryMX Blue (PBT) from the Mechvibes repository, MIT licensed.
See `Resources/Packs/cherrymx-blue-pbt/LICENSE-MECHVIBES.txt`.
