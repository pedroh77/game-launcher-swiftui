# Changes

## 0.4.2 — 2026-09-24

- **Integrated and Bundled Blackbars Helper**: Added `blackbars.swift` as a native SwiftPM executable target (`BlackBars`) in `Package.swift`. It compiles to `dist/Game Launcher.app/Contents/Resources/Backend/blackbars` and is ad-hoc signed automatically during build. Racket `config.rkt` and Swift `LaunchController` resolve the bundled `blackbars` path automatically, with seamless fallback to `~/bin/libexec/blackbars` for external CLI launches.
- **Default Native Focus Clicking**: Enabled native input by default in editor preferences (`Preferences.init`), reflecting that native input and clicking are verified and stable. Older exports lacking the explicit configuration field continue to default to legacy input for backward compatibility.
- **Second Cursor Disappearance Following Delayed Focus Click**: In `focus.rkt`, added a second cursor hide request after the final delayed focus click when native input is active (preserving legacy single-toggle Cursorcerer behavior when native input is off). `NativeInputSession` now accepts and validates the complete 5-action sequence (`["click", "click", "hide", "click", "hide"]`), and `QuartzInputDriver` implements balanced re-entrant hide counting (`hideCount`) so all `CGDisplayHideCursor` invocations are strictly matched by `CGDisplayShowCursor` on cleanup or cancellation.
- **Bundled RosettaX87 JIT Binaries**: Bundled `runtime_loader` and `libRuntimeRosettax87` inside `Resources/Backend/` and codesigned them. `wine-launch.sh` and `config.rkt` now automatically detect and fall back to the bundled `runtime_loader` if not explicitly set in the external environment, and exported standalone apps package these helper binaries into their bundle.
- **Application Icon**: Configured `AppIcon.icns` as the application icon in `Info.plist` (`CFBundleIconFile`) and bundled it into application resources.
- Bumped metadata to 0.4.2/build 15 in `Info.plist` and `StandaloneLauncher.swift`.

## 0.4.1 — 2026-09-24

- **The 0.4.0 source release never compiled a distributable app on macOS, because one test failed.** Swift itself compiled successfully; `xcrun swift test` ran all 53 methods with exactly one failure, and `build-macos.sh` opens with `set -eu` and runs tests before any release build — so the script aborted before packaging, signing and verification. That is why 0.4.0 produced no `dist/Game Launcher.app` while 0.3.5 did. 0.4.1 is the first version of the native-input/localization work that actually builds and packages on a Mac.
- Fixed `LibraryTests.test2048DisplayProfileRoundTripsWithoutChangingOtherSettings`, which compared `GameRecord.displays`' label against the hardcoded English literal `"2048 × 1280 · 1× / pointer 2×"`. That label is produced by `L(…)`, which resolves through the catalog selected from `Locale.preferredLanguages`. On a Brazilian-Portuguese Mac it correctly resolved to `"… / ponteiro 2×"`, so the assertion was locale-dependent and could only ever pass on an English system.
- The comparison now uses `L10n.lookup(…)` — the same lookup the UI performs — so it holds under any system language. Added two language-pinned assertions (`en` and `pt-BR`) so the profile's intended wording in each catalog stays verified, matching the existing style in `LocalizationTests`. **Test only; no production code, persisted data or catalog entry changed.** The localization feature was correct; its test was written against pre-localization expectations.
- Audited every string literal in `Tests/**/*.swift` against both catalogs to find the same class of bug elsewhere. Of 282 keys, exactly two have a translation differing from the key and appear in tests: this display label, and `"Ready"`. Every `"Ready"` use already pins `language:` explicitly or reads a specific `pt-BR.lproj` bundle. No other locale-dependent assertion remains.
- Reproduced the failure and confirmed the fix in this sandbox (no Swift compiler) by faithfully re-implementing `L10n.selectedLanguage`/`render` — including `_`→`-` normalization, `pt`/`en` prefix matching and the English fallback — against the real catalogs. Old assertion: FAIL under `pt-BR`/`pt_BR`, PASS under `en-US`/`ja-JP`, reproducing the user's reported error text verbatim. New assertion: PASS under all four. Portable suites re-run clean: 37 RackUnit cases, 282-key catalog/placeholder/coverage checks, Wine and nine Cancel fixtures, 25 Swift syntax parses.
- **Confirmed by an actual macOS build.** The user reran `build-macos.sh` against the corrected source: all three release products built, both `.xctest` bundles ran, and `dist/Game Launcher.app` was packaged and ad-hoc signed with both language catalogs (282 pt-BR keys) inside `GameLauncher_LauncherCore.bundle`. This is the first Mac-side confirmation of the 0.4.0 Swift integration, which had previously been delivered uncompiled.
- Bumped metadata to 0.4.1/build 14 in `Info.plist` and in `StandaloneLauncher.swift`, so newly exported per-game launchers carry the corrected version stamp. No test asserts on version metadata, so the bump is safe.
- Release hygiene: source archives exclude `.build/`, `dist/`, Racket `compiled/` byte-code caches and `.DS_Store`. The `.build` directory in the extracted 0.4.0 artifact retained absolute paths to a directory that no longer exists; deleting it before rebuilding avoids stale-path reuse.
- Still requires Mac verification, now unblocked by the successful build: actual game-input behavior and TCC grants for the editor and each exported app, real English/Portuguese layout, focus clicks in a live Wine/native game, cursor restoration, and no-late-click behavior on Cancel. Native input remains **off by default**.

## 0.4.0 — 2026-09-23

- Added opt-in shared native clicks and cursor ownership, a private acknowledged Racket control channel, TCC/symbol/topology checks, coordinate/sequence/freshness validation, cancellation and retryable cursor restoration. Only the original four focus actions are accepted; human logs cannot trigger them. No changes to the configured Racket delay/order or legacy input when native mode is off.
- Integrated editor preferences and backward-compatible standalone configuration; older exports default to legacy input. Native input requires an updated backend. Display switching and existing shell cleanup/signal behavior remain independent and unchanged apart from localized UI messages and input cancellation at the lifecycle boundary.
- Added 282 English/Brazilian Portuguese catalog entries, explicit SwiftUI/AppKit/error/status localization, system-language selection, SwiftPM resource packaging and resource copies in exported apps. Persisted data tokens and external logs remain untouched.
- Added safe `games.rkt` compatibility export through the Racket serializer and a read-only CLI action. Includes validated unsaved drafts; refuses overwrites, preserves original constructor fields/ID types, emits explicit display profiles. Notes/extra JSON fields stay in JSON.
- Corrected Settings dependency/scope descriptions and Wine Use Default help. External Sikarugir/Heroic/Racket/live scripts remain external; no installed CLI backend is replaced.
- Added four Racket export tests (37 total), nine Swift XCTest methods (53 total), portable protocol timeout/cancel/refusal fixtures and localization coverage checks. Preserved quiet Wine output and verified existing Wine and nine Cancel fixtures.
- Source release 0.4.0/build 13. Swift/macOS build, XCTest, TCC and actual game-input behavior still require Mac verification.

## 0.3.5 — 2026-09-23

- Silenced Wine/Rosetta stderr at the shared adapter's final `exec`, closing the output leak left by the live-environment integration. Existing runner-side launch stdout suppression remains in place.
- Preserved live-script progress, configuration errors and existing store-tool output. No blanket GUI/stderr filter and no `WINEDEBUG` changes. Adapter stdout remains intact for internal version/path queries; exit codes and process replacement are unchanged.
- Added deliberate Wine/Rosetta stderr noise to fixtures. The regression fails before the fix and passes after it. Real Steam/direct/Epic/GOG/Amazon runner fixtures assert both Wine streams are quiet, while Racket/live-script progress and existing store-tool stderr remain visible. Query stdout, launch failures and cleanup still pass.
- Only production behavior change: two redirections in `wine-launch.sh` (plus explanatory comments). Racket, all runners, display/Cancel logic, library data, external environment contents and the cleanup helper are unchanged from 0.3.4. Release metadata: 0.3.5/build 12.



## 0.3.4 — 2026-09-23

- Corrected the 0.3.2 Wine integration regression: game records store renderer symbols, while the new shell-quoting function and `putenv` require strings. Shared private conversion now handles symbols and existing string callers at both boundaries; unrelated input types still fail validation.
- Reproduced both `string-replace` and `putenv` failures before the fix. Added six RackUnit cases covering every supported renderer, invalid types, the JSON-decoded Ender Magnolia record and all shipped Wine records.
- Expanded fake-Wine fixtures to exercise symbol/string arguments for all six renderers, and five real runner/JSON-record paths (Steam, direct, Epic, GOG and Amazon), including Ender Magnolia's PowerShell arguments and failure cleanup. Focus/process waits and store executables are stubbed; no real game, display or cloud operation runs.
- The only production behavior change is `wine.rkt`. Wine launch/cleanup shell adapters, live environment file, game library, native display/restoration, window placement and GUI Cancel behavior are unchanged from 0.3.3. Release metadata: 0.3.4/build 11.



## 0.3.3 — 2026-09-23

- Fixed false cleanup failures when Wine is already stopped. A silent `-k` exit 1 is accepted only after a quiet, successful same-prefix `-w` check within about two seconds. Diagnostics, other exit codes, failed/noisy waits and timeouts remain failures.
- Bounded timeout/interruption cleanup stops and reaps only the helper's own wait-command child; it does not escalate the signal sent to a running game/server. No GUI Cancel changes.
- Added idle/noisy/blocked/uncooperative-wait fixtures and a real Racket-to-fake-Wine already-stopped regression. Updated both standalone and bundled helper copies.
- Swift/UI logic, all Racket modules, Wine launch adapter, live environment setting, game records, native display and focus remain unchanged from 0.3.2. Only release metadata advances to version 0.3.3/build 10.



## 0.3.2 — 2026-09-23

- Corrected the supplied Wine cleanup helper for independent missing library copies and the no-LC_RPATH case, with per-invocation DYLD_LIBRARY_PATH and failure aggregation. Added read-only --check and explicit wrapper paths; no binary patching or -k9 escalation.
- Reverted speculative 0.3.1 Cancel strategy changes to 0.3.0; helper output stays visible. Retained horizontal-centering timing fix. Native display driver, pointer values, focus and game data unchanged.
- Added Settings → Live Wine environment (absolute path, browse/default buttons, open in default text editor with open -t). Live file content never copied. Export metadata optionally stores its path with backward-compatible default.
- Replaced the external wine_x87.sh dependency with a small backend-owned Wine adapter shared by Steam/direct and Heroic. Racket supplies renderer/Rosetta/DLL selections; the live file supplies actual environment/loader definitions. Shell-safe adapter paths and original argv preserved; failures exposed.
- Normal Racket cleanup now invokes the bundled corrected helper for the selected wrapper; Cancel uses the installed helper as before. Install the supplied top-level kill-wine-processes.sh first. No user scripts are installed/overwritten/deleted automatically.
- Added isolated fake-wrapper tests, including a compiled fake wineserver for environment delivery, plus four Swift XCTest methods (44 total; Mac execution pending). 27 RackUnit cases, 9 baseline cancellation fixtures, Wine fixtures and 21 Swift syntax parses pass in Linux. Real Mac dyld, build, editor opening and game sessions remain unverified.



## 0.3.1 — 2026-09-23

- Registered the game panel's screen observer before synchronous native switching. Re-anchor after launch and during a bounded AppKit settling interval; retain horizontal centering, the 4-point top gap, and non-activating behavior.
- Kept the live shell/Wine scripts and single SIGTERM-to-play route. The supervisor now allows up to five seconds for Racket cleanup, then explicitly runs and waits for installed Wine helpers regardless of pgrep matching. No signal is broadcast to an inherited process group.
- Exposed helper paths/stdout/stderr/exit status, tried installed Steam fallbacks on general-helper failure, and protected ongoing cleanup against repeated signals. The helper scripts themselves are not subject to the Racket grace-period cutoff.
- Normal Cancel returns 130; reported cleanup failure returns 75. Display/pointer restoration still proceeds, while the exported window remains open on a cancelled helper failure. The editor also exposes the failure. Missing helpers are logged; a successful helper exit is not proof that every Wine process disappeared.
- Extended isolated cancellation verification from 9 to 25 cases, including false-negative pgrep, cleanup of a real owned dummy process, Racket cleanup longer than one second, repeated signals, and missing/failing helpers. Added one Swift cleanup-error test (41 methods total, not run in the Linux sandbox).
- User reports native display testing and native game switching work in 0.3.0. Native display driver, profiles, pointer values, focus clicks, seed games and Racket Wine launch/cleanup code are unchanged here. Actual 0.3.1 centering and live Wine cleanup still require a Mac retest.

See **CANCEL-AND-POSITION.md**. Current private wine_env.sh / kill-helper contents were not available for inspection, so the exact cause of the user's Wine survival is not claimed as proven.

## 0.3.0 — 2026-09-23

- Added opt-in **native display switching** in Settings; RDM remains the default. New per-game exports snapshot this choice, and older configurations default to RDM.
- Shared a session-long native owner between the editor and GameRunner. It switches before backend spawn and restores after normal completion or Cancel cleanup, preserving the direct SIGTERM route to play. Launch/start failures roll back to the captured desktop; successful sessions retain the fixed 1440×900 at 2× restore profile.
- Added exact logical/framebuffer/scale matching, refresh preference, preflight of target/current/restore modes, a per-user owner lock, and conservative single-built-in/non-mirrored display support. Unsupported configurations fail without silent RDM fallback.
- Both display.rkt and play defer resolution changes to the app while a native lease is active. Pointer values, blackbars and focus clicks remain in the existing backend. Native Cancel restores pointer scale independently of the logical-resolution check.
- Restore errors retain the owner/session and offer **Retry Display Restore**. Updated-backend compatibility is checked before switching/exporting. Live profile mismatches stop the backend before the game body.
- Added **GameDisplayTest** and `test-native-display.sh`: explicitly confirmed 12-second experiment with captured-mode restoration, signal handling, and a separate 20/23-second watchdog. No games, Wine cleanup, clicks or pointer settings are touched by this diagnostic. The documented process-exit fallback is the permanent Displays setting, not a guaranteed captured-mode recovery.
- Added native driver/session, supervisor ordering/retry, export-compatibility and backend contract tests. Verification: 27 RackUnit cases, 9 isolated mocked signal cases, and Swift syntax parsing. **40 Swift XCTest methods require a Mac run; none switch real displays.** Source delivery only; no macOS compiler/SDK in this sandbox.

See **NATIVE-DEPENDENCIES.md** for the staged Mac test and enabling sequence. The user's working 0.2.3 remains a suitable fallback. Keep RDM installed for old apps and Terminal/Platypus launches. The seed's 118 games, focus settings, external Wine scripts and top-center window placement are unchanged.

## 0.2.3 — 2026-09-23

- Fixed the reported macOS build failure (`CGRect` has no `midX` / `minX` / `maxX` / `maxY`): explicitly import CoreGraphics in `StandaloneLauncher.swift`. Import it in `StandaloneLauncherTests.swift` as well for geometry construction/equality; do not rely on Foundation or XCTest to expose the Swift geometry overlay transitively.
- Added a targeted portable source check for those imports. This catches the specific omission, but does not replace Swift compilation. Existing 21 XCTest methods and their assertions are unchanged.
- Kept the top-center placement, 4-point gap, process supervisor, game library, backend, external dependencies and build/test command unchanged.
- Reviewed the user-supplied display report: the public API enumerates exact logical/framebuffer/scale matches for all five built-in game profiles and the 1440×900 at 2× restore profile, all at 60 Hz. The report also confirms that the read-only diagnostic ran on the user's Mac. It is not a switch/restore test. See NATIVE-DEPENDENCIES.md.

**Minimal fix in an existing 0.2.2 checkout:** add `import CoreGraphics` alongside the imports at the top of both `GameLauncherApp/Sources/LauncherCore/StandaloneLauncher.swift` and `GameLauncherApp/Tests/LauncherCoreTests/StandaloneLauncherTests.swift`, then rerun `sh GameLauncherApp/build-macos.sh --open`. No dependency install, geometry rewrite, test bypass or library migration is needed. Alternatively build from this corrected 0.2.3 source archive.

## 0.2.2 — 2026-09-23

- Centered the native per-game window horizontally on its launch display, with the top of the titlebar 4 macOS points below the visible menu-bar area instead of 12. Compact sizes and non-activating behavior are unchanged.
- Position is recomputed after display geometry changes and Show/Hide Details; a side Dock does not offset screen-centering unless clamping is needed to keep the window visible.
- Added 3 XCTest geometry cases: display resize, a negative-origin display with a side Dock, and horizontal clamping. There are now 21 Swift XCTest methods.
- Added an optional, read-only `scripts/display-report.swift` diagnostic and NATIVE-DEPENDENCIES.md explaining the native focus/display migration path. The diagnostic only queries CoreGraphics and prints JSON; it does not change modes or run automatically.
- Preserved the 0.2.1 streaming fix. RDM, cliclick, Cursorcerer, pointer settings, `play`, game runners and the library are unchanged. Neither dependency has been removed yet.

Rebuild the editor, then re-create any existing exported game apps to get the new window placement; exports contain their own runtime snapshot. `sh GameLauncherApp/build-macos.sh --open` remains the build command. macOS compilation, geometry tests and the diagnostic require a Mac rerun.

## 0.2.1 — 2026-09-23

- Fixed the shared runtime's pipe reader: `read(upToCount: 65_536)` in a readability callback could wait for the requested byte count or EOF, withholding short status lines. The cancellation test waited for a ready line before sending SIGTERM, so it timed out even though exit-only tests passed. The callback now uses `availableData`, as the earlier editor did.
- Added `testShortOutputArrivesBeforeProcessExit`: a harmless child emits one short line and waits for a release file. The test requires that line before allowing the child to exit, independently of cancellation.
- Kept the existing cancellation test, its five-second limit, SIGTERM behavior, and all backend cleanup unchanged. No test was skipped or weakened.
- The Mac build now runs 18 Swift XCTest methods. The user's 0.2.0 log confirmed a successful debug build and 16/17 passing tests; the corrected 0.2.1 runtime still needs a Mac rerun. Portable checks are recorded in VERIFICATION.md.

Rebuild from this source folder with `sh GameLauncherApp/build-macos.sh --open`. The previous failed build stopped before release packaging. No library migration or game-setting change is needed.

## 0.2.0 — 2026-09-23

- Added **Create Launcher…** to the Game menu and toolbar, with app name, editable sanitized bundle ID, progress/text output selection, and an `.icns` picker.
- Added a separate native GameRunner product, bundled in the editor and copied into generated `.app` bundles. Export is staged, ad-hoc signed and verified before publishing; existing destinations are never overwritten.
- Generated apps read the live library by path and alias, but snapshot the Racket backend and `play`. Wine scripts and other external helpers remain in place. No games are launched automatically by export.
- Added a compact, normal-level non-activating output panel near the menu bar. It reanchors after display geometry changes and supports Show/Hide Details and Cancel.
- Shared the process supervisor between editor and native runner. Cancel uses SIGTERM to the direct `play` child, retains the existing broad cleanup, and waits for completion. Output drains before final completion, with a one-second post-exit limit for inherited pipes.
- Native apps quit after backend completion, write a rolling log under `~/Library/Logs/Game Launcher`, and provide `GameRunner --check` for non-launching configuration checks. Pre-launch configuration errors stay visible until Close.
- Added 6 core export/configuration XCTest methods, 3 process-supervision XCTest methods, and 3 portable signal tests using isolated/mocked macOS and Wine helpers.
- The build script now builds and bundles both executables. Swift compilation, signing, export, window behavior and real sessions still need verification on macOS; they were not executed in Linux.

See **LAUNCHER-GENERATION.md** for upgrade, use and testing instructions. No changes were made to `play`, the Racket game runners, the seed library, per-game focus settings, or external Wine scripts in this release.

## 0.1.1 — 2026-09-23

### Added

- Built-in **2048×1280** display profile in the SwiftUI menu, JSON validation, Racket profile table and CLI info output.
- RDM scale **1**, mouse and trackpad scaling **2.0**: identical to the 2560×1600 profile except for width and height.
- Three Racket regression cases for the new profile, preservation of default aliases and JSON round trips; one Swift XCTest method; an integration check through `play --info`.

### Unchanged

- No existing games are switched to the new profile automatically. The seed and legacy game list are unchanged.
- Focus coordinates/delays, black-bar choices, renderers and Wine behavior are unchanged.
- `wine_env.sh` and `wine_x87.sh` remain external, using your existing files in `~/bin/libexec`. They are not copied or overwritten by this update.
- Display switching still uses RDM, skips the existing 1920×1080 case, and restores the existing 1440×900 / scale 2 / pointer 1.0 profile. This release does **not** implement native display switching yet.

### Upgrade from 0.1.0

1. Finish any active game session, save your edits, and quit the old app. Optionally export a library copy as an extra backup.
2. Extract the new source ZIP into a **separate folder** so any local source changes are preserved.
3. From that extracted folder, run:

   ```sh
   sh GameLauncherApp/build-macos.sh --open
   ```

4. The new app keeps the same bundle identifier and reads your existing selected library. It does not reseed or replace an existing Application Support `games.json`. No re-import is needed.
5. Select a game, choose **Display → Profile → 2048 × 1280 · 1× / pointer 2×**, Save, then run **Game → Check Configuration**. The log should include `2048x1280 @ escala 1, mouse 2x`.
6. Replace your installed `.app` with the new `GameLauncherApp/dist/Game Launcher.app` when ready. Keep the old source folder as a backup.

**If Settings uses an external backend folder:** either clear that override to use the new bundled backend, or update `display.rkt`, `library.rkt` and `main.rkt` in the external backend as well. The same applies to a separately installed Terminal/Platypus backend. Version 0.1.0 does not recognize the new named profile, so it will reject a library containing it.

If you maintain local source edits, the functional changes are deliberately small: one new Swift display choice, one JSON allowed value, one CLI display label and two Racket profile-table entries. Merge those changes instead of overwriting your own modifications.

**Compatibility option without updating:** version 0.1.0 already supports a Custom profile with Width 2048, Height 1280, RDM scale 1 and Pointer scale 2. That has the same behavior and is understood by both versions. To reopen a library with 0.1.0 after using the new preset, first switch those entries to that custom profile (or an older preset) using 0.1.1.

**Real-display caveats:** adding the preset does not create a hardware/macOS mode. RDM must actually support 2048×1280 at scale 1 on the connected display. This has not been tested in the Linux sandbox. Fixed focus-click coordinates are not resized; for example, x=2083 is outside a single 2048-wide display starting at x=0. Adjust such per-game coordinates if needed.

### Proposed next increment: native display switching (not implemented)

1. Add a read-only display diagnostic using CoreGraphics to list displays, the current mode, supported modes, logical and pixel dimensions, and refresh rates. Check the built-in display's 2048×1280 and HiDPI profiles before attempting replacement.
2. Add a native mode-selection layer shared by the GUI and Racket, preferably a small bundled Swift helper. It is part of the app, not another separately installed dependency. The process that owns a temporary mode must stay alive for the session; a fire-and-exit helper using `CGDisplaySetDisplayMode` is not sufficient.
3. Add a **Test mode → Keep / Revert** flow with a countdown and automatic rollback. Match an actual supported mode and report errors rather than guessing or claiming success. Keep an explicit RDM fallback for modes the native route cannot reproduce.
4. Integrate launch/exit/Stop Session restoration through the same display manager. Offer restoration of the actual previous mode and pointer settings, while retaining the existing fixed restore profile as an option. The current `play` cancellation trap must not undo native restoration with its hard-coded RDM reset.
5. Leave pointer scaling on the existing mechanism initially; CoreGraphics mode switching alone does not replace that separate policy. After native switching is tested, address cliclick with native event posting and process/window activation. Keep the current Wine focus sequence until its replacement is verified.

Public API references:

- [CGDisplayCopyAllDisplayModes](https://developer.apple.com/documentation/coregraphics/cgdisplaycopyalldisplaymodes(_:_:)) — enumerate available modes.
- [CGDisplaySetDisplayMode](https://developer.apple.com/documentation/coregraphics/cgdisplaysetdisplaymode(_:_:_:)) — switch modes; Apple documents process-lifetime behavior and mirroring considerations.

No native APIs can guarantee the creation of an arbitrary unsupported resolution. Mode enumeration on your Mac is the next useful diagnostic, not a promise that every RDM mode can be replaced unchanged.
