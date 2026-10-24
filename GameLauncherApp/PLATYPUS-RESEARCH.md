# Per-game launcher design: Platypus findings

Researched 2026-09-23. The user chose the recommended native design, now implemented in source version 0.2.0. See LAUNCHER-GENERATION.md for the implementation and Mac verification steps. The findings below record why the native route was selected; Platypus itself is not bundled.

## Cancellation

Platypus's normal (non-admin) Cancel action calls `[task terminate]` on its NSTask. That sends **SIGTERM to the immediate script task**, not Ctrl+C / SIGINT, and not a recursive process-tree kill. Its application-quit handler also calls `terminate` on the task.

The project's `play` explicitly traps INT, TERM, HUP and EXIT. Its cancellation cleanup interrupts the Racket child, falls back to SIGKILL if it does not exit promptly, stops helper processes, calls the user's broad Wine cleanup scripts when Wine is detected, and conditionally restores the fixed display/pointer profile. The launcher's cleanup—not Platypus—is responsible for those effects. Normal completion clears the cleanup flag and preserves the backend's normal-exit handling.

A generated script must use `exec /bin/sh .../play alias` rather than introducing an unforwarded child shell. This keeps the immediate task PID as the `play` supervisor and allows either Platypus's Cancel or a native `Process.terminate()` to reach the same trap. Keep the current cleanup behavior, but warn that it can terminate Wine sessions beyond the selected game.

## Foreground behavior

The inspected Platypus runtime calls `makeKeyAndOrderFront:` when initializing the Progress Bar window and when preparing the Text Window for execution. `Run in background` is not a reliable focus fix: it sets LSUIElement, and the runtime explicitly calls `activateIgnoringOtherApps:YES` in that mode.

The inspected windows are ordinary NSWindows, not always-on-top panels. The output parser does not repeatedly bring the window forward for ordinary text updates. This source review explains startup focus acquisition, but does not prove the cause of every observed Wine/Steam focus issue. Do not remove the user's per-game focus routines without actual game tests.

## Placement and CLI support

The CLI can set the application name (`-a`), bundle ID (`-I`), icon (`-i`), interface (`-o 'Progress Bar'` or `-o 'Text Window'`), interpreter (`-p /bin/sh`), bundled files (`-f`), and quit-after-execution (`-R`).

The documented CLI does not expose window placement, non-activating behavior, or pinning a window below the menu bar across display-mode changes. The nib uses frame-autosave names `ProgressBarWindow` and `TextWindow`; stored Cocoa window-frame preferences can influence initial placement. This is not equivalent to tracking the top edge after the backend switches resolution.

The inspected progress window has 438×87 content with a maximum width of 600; the text window defaults to 580×420 content and has a 400×200 minimum. These are implementation details, not a stable public placement API.

## Recommended design, subject to user choice

A generated native .app could preserve the familiar workflow while using a small AppKit non-activating panel at normal window level, compact progress or text output, and a Cancel button. It should be placed relative to NSScreen.visibleFrame and repositioned when display geometry changes, without requesting foreground activation. The per-game app would run the existing `play`, pass SIGTERM on cancellation and wait for cleanup before exiting.

Export UI: default name from the game title, sanitized reverse-DNS bundle ID under `org.<username>`, .icns picker, progress/text selection, destination, and no remain-running toggle enabled by default. Keep the human-readable title separate from the filesystem-safe app name and bundle-ID component; colons must not appear in the identifier. Avoid silent replacement of an existing .app.

An actual Platypus export remains possible if it is required, but stock Platypus cannot promise the requested non-activating/top-anchored behavior without additional customization. Do not add Accessibility automation just to move or defocus the launcher itself.

## Sources

Reviewed upstream commit `fda6025c28e4f6027be5ae757a144fedb629a537`:

- [SEController.m: Cancel](https://github.com/sveinbjornt/Platypus/blob/fda6025c28e4f6027be5ae757a144fedb629a537/ScriptExec/SEController.m#L1349-L1358)
- [SEController.m: window initialization and activation](https://github.com/sveinbjornt/Platypus/blob/fda6025c28e4f6027be5ae757a144fedb629a537/ScriptExec/SEController.m#L531-L731)
- [MainMenu.xib: geometry and frame-autosave names](https://github.com/sveinbjornt/Platypus/blob/fda6025c28e4f6027be5ae757a144fedb629a537/ScriptExec/Resources/MainMenu.xib)
- [Platypus command-line manual](https://www.sveinbjorn.org/files/manpages/platypus.man.html)
- Local project: `play` and `GameLauncherApp/Sources/LauncherRuntime/LaunchController.swift`.

macOS runtime behavior, display changes and real Wine sessions were not tested in the Linux sandbox.
