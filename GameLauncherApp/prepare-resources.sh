#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(dirname "$HERE")
mkdir -p "$HERE/Resources/Backend/runners"
cp "$ROOT/game-launcher/"*.rkt "$HERE/Resources/Backend/"
cp "$ROOT/game-launcher/runners/"*.rkt "$HERE/Resources/Backend/runners/"
for helper in wine-launch.sh wine-cleanup.sh blackbars runtime_loader libRuntimeRosettax87; do
    if [ -f "$ROOT/game-launcher/$helper" ]; then
        cp "$ROOT/game-launcher/$helper" "$HERE/Resources/Backend/$helper"
        chmod +x "$HERE/Resources/Backend/$helper"
    fi
done
if [ -f "$ROOT/files-referenced-and-others/AppIcon.icns" ]; then
    cp "$ROOT/files-referenced-and-others/AppIcon.icns" "$HERE/Resources/AppIcon.icns"
fi
cp "$ROOT/play" "$HERE/Resources/Backend/play"
cp "$ROOT/game-launcher/games.seed.json" "$HERE/Resources/games.seed.json"
echo "Prepared bundled backend and seed library. No user files were modified."
