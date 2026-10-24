# 0.3.1: native window positioning and shell cleanup

> **Historical 0.3.1 notes — superseded by 0.3.2.** The supplied scripts/log show a dyld-loading failure, not proof of incorrect signal delivery. The extra Cancel strategy described below has been rolled back. Only centering timing and useful helper logging are retained. Follow **WINE-INTEGRATION.md** for current behavior; do not use the old exit-75/retry expectations below.


## Report and findings

The user reports that the 0.3.0 guarded native display test and native game switching work on their Mac. They also report a horizontally misplaced launcher panel and Wine processes remaining after Cancel, even though display/pointer restoration occurs.

Two source-level findings:

1. The exported GameRunner registered its screen-change observer **after** `launcher.start`, which includes the synchronous native mode switch. That can lose the notification and leave the panel positioned for the previous desktop width.
2. `play` allowed the Racket process only **one second** to finish before SIGKILL, potentially interrupting its cleanup. It then called the external Wine cleanup helpers **only if** `pgrep -f 'wineserver|wine-preloader|wine64-preloader'` matched. Wrapped/renamed processes need not match this pattern. Helper output/errors were discarded.

These are concrete weaknesses corrected in this patch. They are not proof of the exact cause of the user's remaining Wine processes: the current live `wine_env.sh` and kill scripts were not available in the sandbox, and no real Wine session has been tested here.

## Changes

### Position

The screen observer is registered before launch. Placement is recalculated after `start` returns and on screen changes, with bounded next-turn / 0.1 / 0.5 / 1.0 second refreshes while AppKit settles its screen geometry. A newer refresh invalidates older callbacks. There is no continual repositioning timer and no app activation or focus click change.

The geometry policy is unchanged: **horizontal center of the display**, clamped to its visible area, **4 points below the menu-bar area**.

### Cancel

Cancel still sends a single **SIGTERM to `play`**, the long-lived shell supervisor. It does not send an unscoped signal to a process group.

- `play` requests a Racket interrupt and allows **up to five seconds** for the backend to finish. Only the Racket PID is force-stopped if it fails to exit. The live cleanup scripts are then run explicitly and awaited, regardless of that result.
- When installed/executable, **`~/bin/kill-wine-processes.sh` always runs**; no process-name gate can suppress it. It is invoked as an executable, preserving its own shebang.
- If it is absent, the installed **`~/bin/kill-steam-sk.sh`** and **`~/bin/kill-steam-dxvk.sh`** helpers run. If the general helper reports an error, installed Steam fallbacks are also attempted, while retaining the error status.
- Script names, output, errors and exit status are now visible in the session log. Exit 0 means the script completed successfully; it is **not independent verification that all Wine processes are gone**.
- Missing executable helpers are reported. If Wine is detected but no helper is available, Cancel reports failure. A native-only installation without helpers and without detected Wine can still cancel normally. Detection is diagnostic here, never a gate in front of an installed helper.
- Repeated TERM/INT/HUP during cleanup cannot terminate the supervisor halfway through the helpers. These user-maintained helpers are **not** subject to the five-second Racket cutoff; a hung helper can keep Cancel waiting, so its last log line is important.
- Successful cancellation returns 130. A helper failure, or detected Wine with no helper, returns **75**. Pointer cleanup and native restoration still proceed. The editor reports the failure; a cancelled exported app stays open with details instead of silently disappearing.

Your existing broad Wine cleanup policy is retained. These helpers can close Wine sessions beyond the current game. Save work and do not run another Wine session while testing. Helpers may be called after backend cleanup already ran; if a helper treats “nothing left to kill” as an error, its output/exit code will now expose that instead of silently hiding it. No new global `pkill wine` strategy was added.

## Why not just change to SIGINT?

Terminal Ctrl+C normally sends **SIGINT to the foreground process group**. Sending SIGINT to one PID from a GUI is not equivalent. Shell/background-job signal dispositions and detached Wine processes add more differences; changing only the signal number does not guarantee that a Wine shell trap will run.

The recommended contract is explicit cleanup under a surviving shell supervisor, rather than depending on incidental propagation through Racket, wrapper shells and detached processes. A fully isolated session/process-group design is possible later, but it must prove group ownership and handle detached Wine servers; broadcasting SIGINT to an inherited group could interrupt unrelated processes.

`wine_env.sh` is **still a live sourced file** during the same launch paths as before. `wine_x87.sh` is also unchanged. This patch does not move their logic into Racket, copy them into the app, or invent a private cleanup function in `wine_env.sh`. If its particular traps/functions are essential after the explicit kill helpers run, the current file is needed to design a correct cleanup entry point with the matching wrapper/prefix environment.

## Retest on the Mac

1. Keep the working 0.3.0 source/app as a fallback. Extract 0.3.1 separately.
2. Build from its parent folder:

   ```sh
   sh GameLauncherApp/build-macos.sh --open
   ```

3. **Re-create the per-game app** with Game → Create Launcher. Old exported apps contain the old GameRunner and `play`; rebuilding only the editor will not update them.
4. Use the already-tested native display setting/profile. Launch one game with no other Wine session running. Check horizontal centering after the display settles. The top gap should remain unchanged.
5. Save in the game, then Cancel. Check for `Executando script de limpeza: ...` followed by the actual helper output and its completion/error. Confirm the game/Wine processes really exit, not just that the display restores.
6. Check a separate normal-exit session as well. The native display implementation and normal Racket/Wine cleanup path were not changed by this patch.

If Wine remains running, provide:

- The game alias and whether it is Steam, Epic, GOG, Amazon or direct Wine.
- The newly exported app's log from `~/Library/Logs/Game Launcher/` (its filename uses the app's bundle identifier), or Save Log in the editor/panel.
- Current `~/bin/libexec/wine_env.sh` and `~/bin/kill-wine-processes.sh`, plus the relevant Steam cleanup script if the log selects it. Redact secrets if any.

This will distinguish a helper that never ran, a missing/shebang/permission error, the wrong Wine prefix/environment, and a helper that returned success without actually ending the game.

## Verification

Portable checks: **27 RackUnit cases**, **25 isolated cancellation cases**, and **19 Swift syntax parses** pass. Cancellation fixtures include both positive and false-negative process detection, a real owned dummy process terminated by the helper, Racket cleanup longer than one second, repeated signals during cleanup, missing/failing helpers and fallbacks. They never touch real Wine/macOS tools. Shell syntax/resource-copy checks pass.

**41 Swift XCTest methods** are present, including a new cleanup-error visibility test, but cannot be compiled/run in this Linux sandbox. Source checks guard early observer registration and bounded refresh; they do not test AppKit notification timing. Actual panel centering and live Wine cleanup must be retested on the Mac. The 0.3.0 native switching success is user-reported, not a claim that this patch has been Mac-tested.
