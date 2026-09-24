#!/bin/zsh
# Imports seven switch recordings from tplai/kbsim (MIT) as version-2 Mechvibes packs.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone -q --depth 1 --filter=blob:none --sparse https://github.com/tplai/kbsim.git "$WORK/kbsim" \
  || { echo "could not clone https://github.com/tplai/kbsim" >&2; exit 1; }
git -C "$WORK/kbsim" sparse-checkout set src/assets/audio >/dev/null   # cone mode also checks out root files such as LICENSE.md
cp "$WORK/kbsim/LICENSE.md" Resources/Packs/LICENSE-KBSIM.txt

typeset -A names
names=(alpaca "Alpaca (linear)" blackink "Gateron Ink Black" bluealps "Blue Alps" boxnavy "Kailh Box Navy"
       buckling "IBM Buckling Spring" redink "Gateron Ink Red" topre "Topre (kbsim)")

for pack in alpaca blackink bluealps boxnavy buckling redink topre; do
  src="$WORK/kbsim/src/assets/audio/$pack"
  dst="Resources/Packs/kbsim-$pack"
  [[ -d "$src/press" && -d "$src/release" ]] || { echo "upstream is missing $src/press or release; nothing changed" >&2; exit 1; }
  rm -rf "$dst"; mkdir -p "$dst"
  cp -R "$src/press" "$src/release" "$dst/"
  cat > "$dst/config.json" <<JSON
{
  "id": "kbsim-$pack",
  "name": "${names[$pack]}",
  "key_define_type": "multi",
  "version": 2,
  "sound": "press/GENERIC_R{0-4}.mp3",
  "soundup": "release/GENERIC.mp3",
  "defines": {
    "14": "press/BACKSPACE.mp3", "28": "press/ENTER.mp3", "57": "press/SPACE.mp3",
    "14-up": "release/BACKSPACE.mp3", "28-up": "release/ENTER.mp3", "57-up": "release/SPACE.mp3"
  }
}
JSON
  echo "imported $dst (${names[$pack]})"
done
