#!/bin/bash
# wine-cleanup-v3: wrapper-local dylib repair and explicit wineserver environment.
# Usage: kill-wine-processes.sh [--check] [NAME | /path/Game.app[/Contents] ...]
# No arguments: Steam_DXVK and Steam_SK under $HOME/Applications.
# --check is read-only: no copies, no wineserver execution, no process termination.

check_only=0
if [ "${1:-}" = "--check" ]; then check_only=1; shift; fi
if [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [--check] [NAME | /absolute/path/Game.app[/Contents] ...]"
    echo "Default: Steam_DXVK Steam_SK. A real run can end every game in those prefixes."
    exit 0
fi
[ "$#" -gt 0 ] || set -- Steam_DXVK Steam_SK

# Fill each missing destination independently. Do not replace existing libraries
# or follow a dangling destination symlink. Publish the small copy atomically.
copy_if_missing() {
    local source="$1" destination="$2" temporary
    if [ -f "$destination" ] && [ -r "$destination" ]; then return 0; fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        echo "ERROR: destination exists but is not a readable file: $destination" >&2
        return 1
    fi
    if [ "$check_only" -eq 1 ]; then
        echo "Would copy: $source -> $destination"
        return 0
    fi
    mkdir -p "$(dirname "$destination")" || return 1
    temporary=$(mktemp "$(dirname "$destination")/.libinotify.XXXXXX") || return 1
    if ! cp -p "$source" "$temporary"; then rm -f "$temporary"; return 1; fi
    # -n avoids overwriting another concurrent repair. Remove an unused temp too.
    if ! mv -n "$temporary" "$destination"; then rm -f "$temporary"; return 1; fi
    rm -f "$temporary"
    [ -f "$destination" ] && [ -r "$destination" ] || return 1
    echo "Library available: $destination"
}

# Wine 10/11 return 1 both when there is no lock owner and on some failures.
# Only classify a SILENT 1 as idle after the same prefix's -w returns promptly
# without diagnostics. -w waits for the server; it does not start a game/server.
# Keep the check bounded so a still-running server cannot hang this helper.
request_shutdown() (
    local wineserver="$1" prefix="$2" search="$3" contents="$4"
    local diagnostic waiter="" status wait_status i
    diagnostic=$(mktemp "${TMPDIR:-/tmp}/wine-cleanup.XXXXXX") || return 1
    # Only stop/reap our own wait-command child, never a Wine game/server PID.
    trap 'if [ -n "$waiter" ]; then
              kill -TERM "$waiter" 2>/dev/null
              sleep 0.1
              if kill -0 "$waiter" 2>/dev/null; then kill -KILL "$waiter" 2>/dev/null; fi
              wait "$waiter" 2>/dev/null
          fi
          rm -f "$diagnostic"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    run_server() {
        WINEPREFIX="$prefix" \
        DYLD_LIBRARY_PATH="$search" \
        DYLD_FALLBACK_LIBRARY_PATH="$search:/usr/lib" \
            "$wineserver" "$@"
    }
    echo "Requesting wineserver -k..."
    run_server -k >"$diagnostic" 2>&1
    status=$?
    cat "$diagnostic"
    if [ "$status" -eq 0 ]; then
        echo "wineserver -k returned successfully for: $contents"
        return 0
    fi
    if [ "$status" -ne 1 ] || [ -s "$diagnostic" ]; then
        echo "ERROR: wineserver failed (exit $status): $wineserver" >&2
        return "$status"
    fi

    # Exec directly, not an extra background shell/function: $! must identify
    # only the short-lived -w command so timeout cleanup cannot leave it behind.
    WINEPREFIX="$prefix" \
    DYLD_LIBRARY_PATH="$search" \
    DYLD_FALLBACK_LIBRARY_PATH="$search:/usr/lib" \
        "$wineserver" -w >"$diagnostic" 2>&1 &
    waiter=$!
    for i in {1..20}; do
        if ! kill -0 "$waiter" 2>/dev/null; then break; fi
        sleep 0.1
    done
    if kill -0 "$waiter" 2>/dev/null; then
        cat "$diagnostic"
        echo "ERROR: -k returned 1 and the same-prefix -w check did not finish within 2s." >&2
        echo "The server may still be running; cleanup is not confirmed: $prefix" >&2
        return 1
    fi
    wait "$waiter"
    wait_status=$?
    waiter=""
    cat "$diagnostic"
    if [ "$wait_status" -eq 0 ] && [ ! -s "$diagnostic" ]; then
        echo "Already stopped: Wine reports no active server for this prefix: $prefix"
        return 0
    fi
    echo "ERROR: could not confirm an idle prefix (-k exit 1; -w exit $wait_status): $prefix" >&2
    return 1
)

kill_wrapper_wine() {
    local supplied="$1" contents support frameworks wineserver prefix source candidate search
    while [ "${supplied%/}" != "$supplied" ]; do supplied=${supplied%/}; done
    case "$supplied" in
        /*) contents="$supplied" ;;
        */*|""|-*) echo "ERROR: use a wrapper name or an absolute .app/Contents path: $1" >&2; return 1 ;;
        *) contents="$HOME/Applications/$supplied"
           case "$contents" in *.app) ;; *) contents="$contents.app" ;; esac ;;
    esac
    case "$contents" in
        *.app/Contents) ;;
        *.app) contents="$contents/Contents" ;;
        *) echo "ERROR: not an .app or .app/Contents path: $1" >&2; return 1 ;;
    esac
    # A colon cannot be represented inside a DYLD search-path component.
    case "$contents" in *:*) echo "ERROR: colon in wrapper path is unsupported: $contents" >&2; return 1 ;; esac
    support="$contents/SharedSupport"
    frameworks="$contents/Frameworks"
    wineserver="$support/wine/bin/wineserver"
    prefix="$support/prefix"
    [ -x "$wineserver" ] || { echo "ERROR: wineserver missing/not executable: $wineserver" >&2; return 1; }
    [ -d "$prefix" ] || { echo "ERROR: prefix missing: $prefix" >&2; return 1; }
    source=""
    for candidate in "$frameworks/libinotify.0.dylib" "$support/wine/lib/libinotify.0.dylib" "$support/libinotify.0.dylib"; do
        if [ -f "$candidate" ] && [ -r "$candidate" ]; then source="$candidate"; break; fi
    done
    [ -n "$source" ] || { echo "ERROR: no readable libinotify.0.dylib in this wrapper: $contents" >&2; return 1; }
    echo "Wrapper: $contents"
    copy_if_missing "$source" "$support/libinotify.0.dylib" || return 1
    copy_if_missing "$source" "$support/wine/lib/libinotify.0.dylib" || return 1

    # @rpath alone cannot find anything when wineserver has no LC_RPATH.
    # Supply wrapper-local leaf-name search directories for THIS invocation.
    # Set these after starting bash, not via /usr/bin/env or another system shell
    # which macOS may sanitize. Do not modify Mach-O load commands or signatures.
    search="$frameworks:$support/wine/lib:$support/wine/lib64:$support"
    echo "WINEPREFIX: $prefix"
    echo "DYLD_LIBRARY_PATH: $search"
    if [ "$check_only" -eq 1 ]; then
        echo "CHECK ONLY: wineserver was not started. This does not validate dyld loading."
        return 0
    fi
    request_shutdown "$wineserver" "$prefix" "$search" "$contents"
}

result=0
for wrapper in "$@"; do
    kill_wrapper_wine "$wrapper" || result=1
done
if [ "$result" -ne 0 ]; then
    echo "One or more wrappers failed; cleanup is not confirmed." >&2
elif [ "$check_only" -eq 0 ]; then
    echo "All selected prefixes: shutdown request succeeded or Wine reported an already-stopped server."
fi
exit "$result"
