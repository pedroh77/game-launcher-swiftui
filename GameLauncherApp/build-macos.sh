#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$(uname -s)" != Darwin ]; then
    echo "This application requires macOS 13+ and Xcode 15+ (or matching Command Line Tools)." >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
    echo "Install Xcode Command Line Tools first: xcode-select --install" >&2
    exit 1
fi
sh "$HERE/prepare-resources.sh"
export MACOSX_DEPLOYMENT_TARGET=13.0
xcrun swift test --package-path "$HERE"
xcrun swift build --package-path "$HERE" -c release --product GameLauncher
xcrun swift build --package-path "$HERE" -c release --product GameRunner
xcrun swift build --package-path "$HERE" -c release --product GameDisplayTest
xcrun swift build --package-path "$HERE" -c release --product blackbars
BIN_DIR=$(xcrun swift build --package-path "$HERE" -c release --show-bin-path)
APP="$HERE/dist/Game Launcher.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/GameLauncher" "$APP/Contents/MacOS/GameLauncher"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
cp -R "$HERE/Resources/." "$APP/Contents/Resources/"
# SwiftPM localization resources are needed by the editor AND exported runners.
LOCALES="$BIN_DIR/GameLauncher_LauncherCore.bundle"
[ -d "$LOCALES" ] || { echo "Missing localization resource bundle: $LOCALES" >&2; exit 1; }
rm -rf "$APP/Contents/Resources/GameLauncher_LauncherCore.bundle"
cp -R "$LOCALES" "$APP/Contents/Resources/"
cp "$BIN_DIR/GameRunner" "$APP/Contents/Resources/GameRunner"
cp "$BIN_DIR/GameDisplayTest" "$APP/Contents/Resources/GameDisplayTest"
cp "$BIN_DIR/blackbars" "$APP/Contents/Resources/Backend/blackbars"
cp "$BIN_DIR/blackbars" "$APP/Contents/Resources/blackbars"
chmod +x "$APP/Contents/Resources/GameDisplayTest"
/usr/bin/codesign --force --sign - "$APP/Contents/Resources/GameDisplayTest"
chmod +x "$APP/Contents/Resources/GameRunner"
/usr/bin/codesign --force --sign - "$APP/Contents/Resources/GameRunner"
chmod +x "$APP/Contents/Resources/Backend/blackbars" "$APP/Contents/Resources/blackbars"
/usr/bin/codesign --force --sign - "$APP/Contents/Resources/Backend/blackbars"
/usr/bin/codesign --force --sign - "$APP/Contents/Resources/blackbars"
if [ -f "$APP/Contents/Resources/Backend/runtime_loader" ]; then
    chmod +x "$APP/Contents/Resources/Backend/runtime_loader"
    /usr/bin/codesign --force --sign - "$APP/Contents/Resources/Backend/runtime_loader"
fi
if [ -f "$APP/Contents/Resources/Backend/libRuntimeRosettax87" ]; then
    chmod +x "$APP/Contents/Resources/Backend/libRuntimeRosettax87"
    /usr/bin/codesign --force --sign - "$APP/Contents/Resources/Backend/libRuntimeRosettax87"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/GameLauncher"
# Ad-hoc signing for local use, no developer account or App Sandbox required.
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
echo "Built: $APP"
echo "Open it with: open \"$APP\""
if [ "${1:-}" = "--open" ]; then open "$APP"; fi
