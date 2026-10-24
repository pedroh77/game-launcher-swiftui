# Replacing cliclick and Cursorcerer — historical feasibility notes

**Status as of 0.4.0:** opt-in native clicks/cursor handling and localization are now integrated in the source. See [NATIVE-INPUT-AND-LANGUAGE.md](NATIVE-INPUT-AND-LANGUAGE.md) for the implemented behavior, limitations and Mac verification steps. The research below records the earlier proposal; it is not the current release specification.

Research: 2026-09-23, before the standalone diagnostic and integration. The behavior described below as current is the retained legacy path.

## Current behavior verified in focus.rkt

For a numeric focus delay: wait for the monitored game process, wait the configured delay, issue two single clicks at the configured coordinates (default 1919,1079), send Control-Option-K through System Events, wait three seconds, then issue one more single click. A false focus mode disables this; legacy procedure hooks are separate. The Cursorcerer hotkey is a toggle, not an explicit hide command.

## cliclick: public native replacement is practical

Use Swift/CoreGraphics mouse-down and mouse-up CGEvents, retaining the existing sequence initially. Replacing the executable does not prove click-free Wine activation will work: NSRunningApplication activation/Accessibility window focus is a separate experiment. Preserve coordinate semantics and event spacing; verify mouse-up delivery and check coordinates against the post-switch display layout rather than silently clicking an unrelated location.

Preflight event-posting/Accessibility permission and clearly report missing permission. An editor permission grant must not be assumed to cover independently identified exported apps. Screen Recording is not inherently needed just to post clicks; avoid adding screen capture or keyboard monitoring.

## Cursorcerer: background hiding is the caveat

Apple documents that CGDisplayHideCursor normally requires the caller to be the foreground application. Our launcher intentionally stays in the background while the game runs. NSCursor.hide or a naive CGDisplayHideCursor call is therefore not an equivalent global replacement. Do not activate the launcher to make hiding work: that defeats game focus.

A known implementation sets the private WindowServer connection property `SetsCursorInBackground` via CGSSetConnectionProperty, then balances CGDisplayHideCursor/CGDisplayShowCursor calls. This can be called from native code, but is undocumented, unsuitable for App Store distribution, and may break after macOS updates. Personal use removes distribution concerns, not compatibility risk. The technique has not been tested on this user's Mac. Do not claim it is Cursorcerer's exact current implementation; its author describes a global-hiding hack, but its source was not inspected here.

If accepted: isolate private symbols behind runtime availability checks, make background hiding opt-in, retain an explicit legacy setting, and fail visibly if unsupported. A successful function return alone is not proof the cursor actually remained hidden over Wine. Reproduce only the launcher's needed behavior, not an entire replacement utility.

## Suggested architecture and safe test

Keep Racket's existing game/process detection and delay policy; use a dedicated structured local channel to request native actions from the owning Swift process. Do not parse human-readable progress logs as a control protocol. The owner must live throughout the session so hide/show accounting remains in the same process. Gate the bundled Racket legacy actions to avoid duplicate clicks/toggles; leave the user's original ~/bin/game-launcher untouched.

Before integration, use a time-limited, explicitly started test. Click tests should target a harmless test surface. Cursor tests must include a different foreground app and later a real Wine game. Define mouse-movement reveal behavior, test Command-Tab, and provide a visible/manual escape plus timed restoration. Do not grab/disable the mouse or continually fight game cursor state. Balance only hides owned by this session, cancel pending clicks as soon as Stop is requested, and restore on normal exit, Cancel, launch failure and foreground/session transitions. Forced termination/process-lifetime recovery needs real Mac verification; never promise a cleanup handler can run after Force Quit.

Use the same Swift component in the editor and exported launchers; re-create exports to update it. Original CLI scripts retain cliclick/Cursorcerer unless explicitly updated later. No Sikarugir, Heroic, Wine environment, Racket replacement or display-engine rewrite is needed.

## Sources

- Apple, CGDisplayHideCursor: https://developer.apple.com/documentation/coregraphics/cgdisplayhidecursor(_:)
- Apple, event-posting access preflight: https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess()
- cliclick documentation/permissions: https://github.com/BlueM/cliclick
- Cursorcerer author (hotkey toggle and idle/movement behavior): https://doomlaser.com/cursorcerer-hide-your-cursor-at-will/
- Background-hiding implementation discussion: https://www.acheron.fail/posts/pixel-picker/
- Recent independent Swift example of the same private property (not a dependency or verification): https://github.com/peter6366/CursorIdleHider
