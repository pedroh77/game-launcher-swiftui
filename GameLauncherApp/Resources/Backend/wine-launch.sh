#!/bin/sh
# live-wine-env-v1: executable adapter required by Heroic's --wine interface.
# The live environment file owns Wine/Sikarugir/renderer variables. Do not copy
# those definitions here. Steam/direct and Heroic all use this same entry point.

launcher_env_file=${GAME_LAUNCHER_WINE_ENV:-"$HOME/bin/libexec/wine_env.sh"}
case "$launcher_env_file" in
    /*) ;;
    *) echo "ERROR: Wine environment path must be absolute: $launcher_env_file" >&2; exit 64 ;;
esac
[ -f "$launcher_env_file" ] && [ -r "$launcher_env_file" ] || {
    echo "ERROR: Wine environment file is not readable: $launcher_env_file" >&2; exit 66;
}
[ -n "${WRAPPER:-}" ] && [ -d "$WRAPPER" ] || {
    echo "ERROR: WRAPPER must identify an existing Contents directory." >&2; exit 64;
}
# Keep environment-file status output off Wine's stdout (Heroic may query --version).
if . "$launcher_env_file" >&2; then :; else
    echo "ERROR: Could not load Wine environment: $launcher_env_file" >&2
    exit 70
fi
[ -n "${WINE_BIN:-}" ] && [ -x "$WINE_BIN" ] || {
    echo "ERROR: WINE_BIN from the environment file is not executable." >&2; exit 69;
}
# Runners already discard launch stdout. Keep stdout available here for store
# version/path queries, but silence Wine/loader stderr at exec only. The live
# script's progress and the adapter's validation errors above remain visible.
case "${GAME_LAUNCHER_USE_ROSETTA:-1}" in
    1)
        if [ -z "${RUNTIME_LOADER:-}" ] || [ ! -x "$RUNTIME_LOADER" ]; then
            ADAPTER_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
            if [ -x "$ADAPTER_DIR/runtime_loader" ]; then
                RUNTIME_LOADER="$ADAPTER_DIR/runtime_loader"
            fi
        fi
        [ -n "${RUNTIME_LOADER:-}" ] && [ -x "$RUNTIME_LOADER" ] || {
            echo "ERROR: RosettaX87 requested but RUNTIME_LOADER is not executable." >&2; exit 69;
        }
        exec "$RUNTIME_LOADER" "$WINE_BIN" "$@" 2>/dev/null
        ;;
    0) exec "$WINE_BIN" "$@" 2>/dev/null ;;
    *) echo "ERROR: GAME_LAUNCHER_USE_ROSETTA must be 0 or 1." >&2; exit 64 ;;
esac
