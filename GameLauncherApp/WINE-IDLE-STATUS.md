# 0.3.3 — cleanup when Wine is already stopped

The user confirmed **nothing was running in either wrapper** during the reported 0.3.2 helper test. The new log no longer showed the dyld abort, but the helper incorrectly labelled Wine's silent exit 1 as an unconditional error.

Upstream Wine 10 and 11's `kill_lock_owner` returns false when there is no server directory or no lock owner. The `-k` command turns that into exit 1. Other failures can also produce 1, so the correction does **not** just ignore every exit 1.

Sources reviewed:
- https://github.com/wine-mirror/wine/blob/wine-10.0/server/request.c (`kill_lock_owner`, `wait_for_lock`)
- https://github.com/wine-mirror/wine/blob/wine-11.0/server/request.c
- https://github.com/wine-mirror/wine/blob/master/server/main.c (option handling)

## New behavior

- `-k` returns 0: report the successful shutdown request as before.
- `-k` returns 1 **with any output/diagnostic**: preserve the output and report failure.
- `-k` returns 1 **silently**: invoke `wineserver -w` with the same prefix and library environment. It waits for the selected prefix's server; it does not start a server/game.
  - Quiet exit 0 within about two seconds: report **Already stopped: Wine reports no active server for this prefix**, and return success.
  - Diagnostic, nonzero exit, or timeout: retain failure. On timeout/interruption, stop and reap only the helper's own `-w` child. TERM followed by KILL if needed is limited to that diagnostic child, not an active game/server.
- Actual dyld failures, missing files and other nonzero statuses remain errors.
- `--check` remains file-only: no Wine executable is started and no copies are made.

This relies on the selected Wine binary's own prefix/lock reporting; it is not a system-wide process scan or proof about Wine running under a different prefix. A genuine prefix/namespace mismatch still requires investigating the running game's environment, not broad process killing.

## Use the corrected helper

The standalone download and top-level `kill-wine-processes.sh` in the 0.3.3 source archive are identical to its bundled `game-launcher/wine-cleanup.sh`.

From the extracted parent folder:

```sh
cp -p "$HOME/bin/kill-wine-processes.sh" \
  "$HOME/bin/kill-wine-processes.sh.backup-$(date +%Y%m%d-%H%M%S)"
install -m 755 kill-wine-processes.sh "$HOME/bin/kill-wine-processes.sh"
"$HOME/bin/kill-wine-processes.sh"
```

With the wrappers idle, expect an **Already stopped** message for each and overall exit 0. During a later real cleanup test, save all Windows work first: `-k` can end all programs within the selected prefix. No arguments still selects Steam_DXVK and Steam_SK.

For the app build, use **0.3.4 or later**: it retains this helper fix and also corrects the subsequently reported renderer-symbol launch failure. The following describes the original 0.3.3 scope. The only functional changes from 0.3.2 are in the cleanup helper; the matching bundled copy covers normal Racket cleanup too. Swift/UI, Wine environment configuration/adapter, display manager and GUI Cancel behavior are unchanged (apart from release metadata). Build as usual:

```sh
sh GameLauncherApp/build-macos.sh --open
```

Re-create exported apps when ready. Contents of the live `wine_env.sh` remain external and unchanged. See WINE-INTEGRATION.md for the environment-path/editor feature and full integration instructions.

## Verification

Isolated compiled fake-Wine tests pass for quiet idle prefixes, successful kills, noisy kill failure, failed/noisy wait, blocked wait, an uncooperative wait child, and normal Racket cleanup after Wine already exited. Existing library-copy, environment, adapter/arguments, shell-safe path and failure aggregation fixtures pass too. No real Wine was started or killed here.

27 RackUnit cases, 9 baseline mocked Cancel cases, shell/resource checks and 21 Swift syntax parses pass. The 44 Swift XCTest methods and the actual Mac Wine/UI behavior remain unverified in this Linux sandbox. The user has confirmed the idle condition and supplied the new log, not yet tested this 0.3.3 revision.
