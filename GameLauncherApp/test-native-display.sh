#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOOL="$HERE/dist/Game Launcher.app/Contents/Resources/GameDisplayTest"
if [ ! -x "$TOOL" ]; then
    echo "Build first: sh GameLauncherApp/build-macos.sh" >&2
    exit 1
fi
if [ "${1:-}" = "--check" ]; then
    [ "$#" -eq 2 ] || { echo "Usage: $0 --check PROFILE" >&2; exit 2; }
    exec "$TOOL" --check "$2"
fi
[ "$#" -eq 1 ] || { echo "Usage: $0 PROFILE (for example 2048x1280)" >&2; exit 2; }
exec "$TOOL" --test "$1"
