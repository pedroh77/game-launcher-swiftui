# Native display switching and remaining dependencies

**0.4.0 update:** native focus/cursor is now a separate opt-in setting, and new exports include both language catalogs and the chosen input setting. Racket still owns focus timing; cliclick/Cursorcerer remain the legacy option. Re-create exports to adopt the changes. See [NATIVE-INPUT-AND-LANGUAGE.md](NATIVE-INPUT-AND-LANGUAGE.md). The versioned details below describe earlier releases.

**0.3.2:** native display implementation is unchanged. The centering timing fix is retained; speculative 0.3.1 cancellation changes are reverted now that the user's logs identify a dylib-loading failure in the Wine helper. See **WINE-INTEGRATION.md** for the replacement helper and live environment setting.


Version **0.3.1**, 2026-09-23. Native switching is implemented as an **opt-in, Mac-test-required path**. RDM remains the default. Focus clicks/cliclick, Cursorcerer, pointer scaling, Wine scripts and store tools are unchanged.

The user confirmed the 0.3.0 guarded test and native sessions work. The native driver is unchanged in 0.3.1; see **CANCEL-AND-POSITION.md** for the window-timing and shell-cleanup corrections. Existing exports must be re-created to get those corrections.

## Start with the guarded test

Keep the working 0.2.3 app and source as a fallback. Finish all game sessions before testing. Do not run RDM or another display manager during the test. This first native implementation supports **one online, built-in, non-mirrored display**, matching the supplied report. Unsupported topology produces an error before switching; it does not guess or silently fall back to RDM.

1. Build from the extracted 0.3.1 parent folder:

   ```sh
   sh GameLauncherApp/build-macos.sh --open
   ```

   The build runs Swift tests, then builds/signs the editor, GameRunner and the diagnostic GameDisplayTest. It does **not** switch your display or enable native mode.

2. Leave **Settings → Display manager → Use native display switching instead of RDM** **off**. Quit any existing game launcher sessions. Read-only preflight:

   ```sh
   sh GameLauncherApp/test-native-display.sh --check 2048x1280
   ```

   This prints the chosen mode, current desktop and restore target; it creates/acquires the native-session lock briefly, but does not change resolution, pointer preferences or games.

3. Run the guarded switch test:

   ```sh
   sh GameLauncherApp/test-native-display.sh 2048x1280
   ```

   It requires you to type **TEST** and press Return. A separate worker switches to 2048×1280 at 1× for **12 seconds**, then restores the **captured desktop mode**. Ctrl+C requests early restoration. No `play`, game, Wine cleanup, pointer adjustment, click or screen capture is involved.

   The parent watchdog is independent of the worker's main queue: after 20 seconds it requests restoration/exit with SIGTERM; after 23 seconds it ends only that worker if still stuck. CoreGraphics' process-lifetime fallback then reverts to the **permanent Displays setting**, which is not necessarily the mode captured at test start. Hardware/OS failures cannot be guaranteed recoverable by software. If watchdog messages or errors appear, **do not enable native mode**; inspect System Settings → Displays and share the output.

4. A normal test prints `RESTORED: captured desktop mode verified`. **Also check the desktop after the worker has exited**, not just before: terminating a program that used this temporary API returns macOS to the permanent Displays setting. Your reported 1440×900 at 2× desktop should remain correct after exit. If it changes again on exit, first set the intended desktop mode in System Settings → Displays; keep RDM selected until the full test passes.

5. Repeat for any other profiles you use: `2560x1600`, `1680x1050`, `1920x1200`, `1280x800`. The diagnostic also accepts `1440x900`. Each test is separately confirmed and always restores; there is no “keep this experimental mode” action. Custom profiles are supported by game sessions only if an exact native match exists.

## Enable native sessions after testing

1. Turn on **Settings → Display manager → Use native display switching instead of RDM**.
2. Leave the backend-folder override blank to use the bundled updated backend. Old external backends are rejected before native switching. If maintaining an override, it needs this release's `display.rkt` **and** `native-display.rkt`; the bundled `play` already has the matching protocol.
3. Select a game with a tested profile and launch it. Verify the log identifies **Native display** with the intended logical size, framebuffer and refresh rate.
4. Exit that game normally. The shared owner must restore **1440×900 at 2×**, preserving the established game-session restore policy. The backend still resets pointer scaling to **1**.
5. Run a separate session, save in the game, and test **Stop Session/Cancel**. The existing broad Wine cleanup remains; it can close other Wine sessions. Resolution restoration occurs only after `play` and its cleanup finish.
6. Re-create exported per-game apps after enabling the preference. Their `nativeDisplay` selection is an export-time snapshot. Old exports and old configuration files default to RDM; changing the editor preference does not update existing apps. Test normal exit and Cancel in one newly exported app as well.

Disable the preference to return the editor to the RDM path. Re-create native exports with it disabled to change them back. **Do not uninstall RDM yet**: old exports, direct Terminal/Platypus `play` launches and the unchecked preference still use it. This release does not introduce a native mode for standalone Terminal `play` invocations.

## Ownership and safeguards

- `LauncherRuntime.NativeDisplaySession` is shared by the editor, exported GameRunner and guarded diagnostic. It uses **public CoreGraphics only**, with explicit CoreGraphics imports.
- Preflight finds exact logical width/height and framebuffer scale. It prefers the current refresh rate and current mode when applicable, never a merely similar resolution. Both target and fixed game restore modes must exist before any switch.
- The editor/GameRunner owns the lease from before backend spawn until cleanup/output completion. Normal completion, Cancel and close therefore converge on the same restore method. The existing direct `/bin/sh play` process and single SIGTERM cancellation route are unchanged.
- A per-user nonblocking file lock excludes simultaneous native sessions/tests across apps. It does not control RDM, old launchers or unrelated apps; do not run competing sessions/display tools.
- The app supplies the reserved `GAME_LAUNCHER_NATIVE_DISPLAY` marker only for its live lease. `display.rkt` validates the live game's profile against it and does not run RDM; `play` skips its RDM restore too. Do not set this marker manually in Terminal. Internal markers inherited by the Swift launcher are cleared.
- Native mode `off` suppresses resolution/pointer/blackbar changes. The existing 1920×1080 skip is retained on a supported built-in display. External/multiple/mirrored displays require the RDM path in this initial release.
- Pointer policy remains in the backend. Native cancellation resets it even if the logical resolution already equals 1440×900, avoiding the old resolution-only test suppressing pointer cleanup. `GAME_LAUNCHER_ACTIVATE_SETTINGS` is a helper-path override used by isolated cancellation tests; ordinary runs use the existing macOS helper.
- A failed switch/start attempts to restore the captured desktop. A successful game session restores the fixed 1440×900 at 2× profile. Failed restoration keeps the lease/lock and session open and exposes **Retry Display Restore**; normal automatic exit does not report success or abandon the owner. Restore any disconnected/mirrored topology before retrying. The editor unhides on a restore failure; the game panel remains non-activating.
- A hard crash/Force Quit cannot execute normal cleanup. CoreGraphics documents reversion to the permanent Displays setting on process exit, **not guaranteed restoration of the captured mode**. No permanent display settings are written by this feature. The independent watchdog is for the short diagnostic, not a time limit on real games.

Reference: [Apple: CGDisplaySetDisplayMode](https://developer.apple.com/documentation/coregraphics/cgdisplaysetdisplaymode(_:_:_:)). Apple documents synchronous switching, process-lifetime modes and mirroring side effects; these motivate the separate test worker and conservative display-topology check.

## Supplied display report

The user's read-only report lists built-in main display ID 1, not mirrored, with current 1440×900 at 2×. The following exact matches were checked against the backend presets; all report **60 Hz**:

| Logical size | Scale | Framebuffer | Reported ID |
|---|---:|---|---:|
| 2560×1600 | 1× | 2560×1600 | 18 |
| 2048×1280 | 1× | 2048×1280 | 17 |
| 1680×1050 | 2× | 3360×2100 | 15 |
| 1920×1200 | 1× | 1920×1200 | 16 |
| 1280×800 | 2× | 2560×1600 | 7 |
| 1440×900 (restore) | 2× | 2880×1800 | 12 |

IDs are evidence from that report, not hard-coded production identifiers. The implementation re-enumerates and verifies the actual mode. Enumeration alone did not test switching or restoration.

## cliclick remains a separate follow-up

The working focus clicks and per-game delays/coordinates are unchanged. A future native mouse-event helper could replace the cliclick executable with CoreGraphics CGEvent posting while retaining clicks and requiring appropriate Accessibility permission. Click-free focus is a separate experiment: identify the actual game's owning window/process, try application activation and Accessibility focus/raise, and only then remove a tested game's click workaround. No new Accessibility or screen-capture request is introduced by this display-only update.
