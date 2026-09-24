#!/bin/zsh
# Builds build/Clacky.app. With --install, replaces /Applications/Clacky.app and launches it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Clacky.app
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Clacky" "$APP/Contents/MacOS/Clacky"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Packs "$APP/Contents/Resources/Packs"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Clacky || true
  rm -rf /Applications/Clacky.app
  cp -R "$APP" /Applications/Clacky.app
  echo "Installed /Applications/Clacky.app"
  echo "If keys go silent after a rebuild: System Settings > Privacy & Security > Input Monitoring, toggle Clacky off and on."
  open /Applications/Clacky.app
fi
