# Game Launcher — SwiftUI

## Current release: 0.4.1

**Native focus/cursor integration, Brazilian Portuguese + English, and `games.rkt` export** — now building and packaging cleanly on macOS. 0.4.0 shipped the same features but its test suite contained one locale-dependent assertion, which aborted `build-macos.sh` before packaging on a Portuguese system; 0.4.1 fixes that test and bumps metadata to build 14. See [VERIFICATION.md](VERIFICATION.md). Start with [NATIVE-INPUT-AND-LANGUAGE.md](NATIVE-INPUT-AND-LANGUAGE.md) for setup, permissions, coordinate checks and the Mac test sequence.

- Native input is **off by default**. Racket retains the process wait/delay and original click/hide sequence; the shared Swift runtime posts clicks and owns background cursor hiding for the editor and newly exported apps. Cancel stops pending input immediately; existing backend cleanup and display restoration ordering are retained. No silent legacy fallback after an input error.
- Portuguese is selected from the preferred system/app language; English remains available. Both catalogs are included in exported launchers. User game data and external logs are not translated.
- File → Export games.rkt writes a new compatibility file, including the current validated draft. It never installs/replaces scripts; JSON remains the master library.
- Settings help now describes actual dependencies and what Use Default changes (the Wine environment path only, never its contents).

Quit the old editor, extract this source and run:

```sh
sh GameLauncherApp/build-macos.sh --open
```

Keep the backend override blank for the bundled implementation. **Leave your installed `~/bin/game-launcher`, live `wine_env.sh`, Sikarugir and Heroic tools alone.** No new cleanup-helper installation is needed for this update if your 0.3.5 setup already works. After testing the editor, re-create exported apps; existing exports do not gain these features automatically.

Portable backend/Wine/Cancel/input-protocol/catalog checks and Swift syntax checks pass in the Linux sandbox. **Swift compilation and all 53 XCTest methods have now also passed on the user's Mac** (see [VERIFICATION.md](VERIFICATION.md)); the build script runs them before building the app. What still needs a Mac is real behavior: the successful macOS 27 cursor diagnostic does not verify global clicking in Wine games. First test a noncritical game with coordinates inside its active logical display bounds.

Earlier release notes below are historical.

## Previous release: 0.3.5

**Quiet Wine output:** the user reports that 0.3.4 seems to work, but Wine noise drowns out script progress. The runners already suppressed launch stdout; the shared adapter was still passing through Wine/Rosetta stderr. Two exec redirections now silence that stream at the Wine boundary only. Live `wine_env.sh` progress, adapter validation errors, Racket progress and existing store-tool messages remain visible. Adapter stdout remains available for internal version/path queries. Existing store-tool stdout/Comet redirections and cleanup diagnostics are unchanged; this release does not newly enable previously hidden output.

No global log filter, `WINEDEBUG` override, added supervisor process or change to exit statuses/signals. The only functional edit is `game-launcher/wine-launch.sh` (and its bundled copy). No `wine_env.sh`, library, renderer, display or Cancel changes. Keep the installed 0.3.3 cleanup helper unchanged.

Quit the old editor, extract this source and run `sh GameLauncherApp/build-macos.sh --open`. Use the newly built `GameLauncherApp/dist/Game Launcher.app`, updating any copy kept elsewhere. Leave the backend override blank for the bundled fix, or update your intentionally external backend. Re-create exported game apps to update their embedded adapter. You do not need to repeat the guarded display test for this output-only patch.

Regression fixtures deliberately emit Wine/Rosetta noise on stderr and Wine output on stdout. The old adapter fails the new assertion; the fix passes for Rosetta on/off and all five Wine runner paths, preserving script/store progress, version-query stdout and failure statuses. Full portable checks pass; actual 0.3.5 Mac log behavior remains to be tested. Earlier release notes below are historical.


## Previous release: 0.3.4

**Fix for games switching resolution and immediately returning without launching:** 0.3.2's Wine integration failed to convert game-record renderer symbols (such as `'d3dmetal`) into strings. Both the command builder and environment setup now perform that conversion. The second resolution switch in the reported Ender Magnolia log was the existing restoration after the error, not a second attempt to launch.

The functional patch is limited to `game-launcher/wine.rkt` and its bundled copy. No edits to `games.json`, `wine_env.sh`, renderer selections, display management or GUI Cancel are needed. **The cleanup shell script is unchanged from 0.3.3; keep your installed replacement.**

Quit the old editor, then build from this extracted folder with `sh GameLauncherApp/build-macos.sh --open`. Use the newly built `GameLauncherApp/dist/Game Launcher.app` (and update any copy you keep elsewhere). Leave the backend override blank to use this bundled fix; an intentional external backend must also be updated. Re-create exported per-game apps after confirming the editor launch works: they embed their own backend copy. Do not patch only an older built `.app` or edit the live renderer value to work around the error.

The regression was reproduced locally before the patch. 33 RackUnit cases now pass, including six new symbol/string tests using the actual JSON-decoded Ender Magnolia record and all shipped Wine records. Extended fixtures pass through all six supported renderers and the real Steam/direct/Epic/GOG/Amazon runners with fake Wine/store tools and stubbed focus/waits. This verifies the reported Racket error, not actual Mac game startup. Earlier release notes below are historical.


## Previous release: 0.3.3

**Already-stopped Wine cleanup fix:** the user confirmed both prefixes were idle during the reported silent exit-1 test. The helper now distinguishes that expected case using a bounded same-prefix `-w` check, while preserving diagnostic/active-server failures. See **[WINE-IDLE-STATUS.md](WINE-IDLE-STATUS.md)**. Use 0.3.3 instead of the not-yet-tested 0.3.2 package: the helper is fixed both as a standalone download and in the bundled normal-exit path. GUI cancellation, display switching and Wine environment features are otherwise unchanged. Older release notes below are historical.


## Previous release: 0.3.2

**Start with [WINE-INTEGRATION.md](WINE-INTEGRATION.md).** It contains the replacement `kill-wine-processes.sh` installation/test procedure and the new **Settings → Live Wine environment** path/editor control. The original 0.3.0 Cancel strategy is restored (the extra 0.3.1 workarounds below are superseded); window-centering timing remains fixed. Native display code is unchanged.

The new backend bundles its Wine adapter, so it no longer needs the user's external `wine_x87.sh`. All Wine launches read the selected **live** `wine_env.sh`; it is never copied into the app. Normal Wine cleanup uses the bundled dylib-corrected helper. Cancel still uses the installed `~/bin/kill-wine-processes.sh` — install the supplied replacement first.

Build: `sh GameLauncherApp/build-macos.sh --open`. Re-create exported apps for the new backend and file-path setting. Mac dyld/UI behavior and compilation still require testing. Older release notes below are historical; current behavior is described in WINE-INTEGRATION.md and VERIFICATION.md.


A personal macOS game-library editor and launcher over the existing Racket/Sikarugir backend.

**Version 0.3.1:** includes **Game → Create Launcher…**: native per-game `.app` export with a disk-selected `.icns`, sanitized bundle identifier, progress/text output, a compact non-activating window near the menu bar, Cancel and automatic exit. No Platypus installation is required. See **[LAUNCHER-GENERATION.md](LAUNCHER-GENERATION.md)** for usage and important cleanup/permission details.

**0.3.1 corrects the timing of window centering after native display changes, and makes Cancel explicitly run and wait for the existing live Wine cleanup scripts without a process-name gate.** Cleanup failures are visible rather than silent. Re-create exported apps after rebuilding. See **[CANCEL-AND-POSITION.md](CANCEL-AND-POSITION.md)** for signal details and the retest procedure. The user confirmed native switching works in 0.3.0; this patch leaves that implementation unchanged.

**0.3.0 adds opt-in native display management and a guarded 12-second switch-and-restore test.** RDM stays the default. Test first with `sh GameLauncherApp/test-native-display.sh 2048x1280` after building; only then enable the native toggle in Settings. The editor and newly exported apps share a display owner for normal completion and Cancel. See **[NATIVE-DEPENDENCIES.md](NATIVE-DEPENDENCIES.md)** for the safe sequence, scope and recovery limitations. Mac compilation/runtime verification is still required.

**0.2.3 fixes the geometry compile failure with explicit CoreGraphics imports.** The window positioning and 21 XCTest methods are unchanged. The user's display report confirms native mode availability for the built-in profiles; actual switching/restoration and RDM removal remain a follow-up. See `CHANGELOG.md` for a two-import fix that can also be applied to an existing 0.2.2 checkout.

**0.2.2 centers the per-game window horizontally with a 4-point gap below the menu-bar area.** Rebuild the editor and re-create existing game launchers to update their bundled runtime. A read-only display diagnostic and the plan for removing cliclick/RDM are in `NATIVE-DEPENDENCIES.md`; neither dependency is removed in this patch.

**0.2.1 fixes live-output buffering that caused the cancellation test to time out on macOS.** The cancellation test is unchanged; a new regression test requires short output to arrive before the child exits. See `CHANGELOG.md`.

The 2048×1280 preset from 0.1.1 remains available (scale 1 / pointer 2×). Existing game settings and external Wine scripts are unchanged. RDM remains available as the default/legacy path; native mode is a per-editor preference and an export-time selection for new per-game apps.

**Delivery status:** source code, not a compiled `.app`. The sandbox is Linux and has no Swift compiler or macOS SDK. The Racket backend and portable checks have been run; Swift syntax parsing is not a substitute for compilation. The build script runs the Swift tests before creating the app on your Mac.

## Build on your Mac

Keep `GameLauncherApp`, `game-launcher`, and `play` together as supplied in the archive. From the extracted folder:

```sh
sh GameLauncherApp/build-macos.sh --open
```

Requirements:

- macOS **13 or newer** to run the app.
- Xcode **15+** or matching Command Line Tools (Swift 5.9+ and a macOS SDK) to build it. The toolchain itself may require a newer macOS version.
- An installed **Racket** to use the backend. The GUI discovers the same common locations as `play`; you can select a different executable in Settings.
- Your existing Wine wrappers, games, store tools, external scripts and helper apps remain necessary for the launch methods that use them.

If no developer tools are installed, run `xcode-select --install` first. If you use full Xcode, open it once to complete setup and accept its license.

The script prepares bundled resources, runs `swift test`, builds all three release executables (editor, game runner and guarded display diagnostic) for your Mac's architecture, creates the application bundle, and ad-hoc signs it for local use. It does not require a developer account and does not install or overwrite anything in `~/bin` or `/Applications`.

Output:

```text
GameLauncherApp/dist/Game Launcher.app
```

You can move that `.app` to `/Applications` or `~/Applications`. It includes a copy of the Racket backend, **not** Racket itself or any third-party game/helper binaries. No App Sandbox or hardened-runtime restrictions are added to this personal local build.

To work in Xcode, open `GameLauncherApp/Package.swift` and choose the `GameLauncher` executable scheme / My Mac. Use the build script for the distributable `.app`. For development with SwiftPM:

```sh
sh GameLauncherApp/prepare-resources.sh
swift run --package-path GameLauncherApp GameLauncher
```

## First run

The app seeds the library with the **118 entries exported from the supplied `games.rkt`**, including their effective constructor defaults. It only seeds a missing default file; it does not overwrite an existing library.

The default library is:

```text
~/Library/Application Support/Game Launcher/games.json
```

Select a game in the sidebar, edit its fields, and click **Save**. Available actions:

- Search by title, alias or runner.
- New game (`⌘N`), duplicate (`⌘D`), edit, and remove an entry.
- Platform-aware launch methods: Steam, Epic/Legendary, GOG, Amazon/Nile, and direct executables, with native/Wine variants where supported.
- Wrapper browser/presets, renderer, Rosetta x87 toggle and DLL overrides.
- Display-profile selector, custom dimensions/scales and black bars.
- Delayed focus clicks, delay and coordinates.
- Game/save directories, Steam Wine PowerShell script and notes.
- Launch (`⌘L`), live backend output, log export and Stop Session.
- **Game → Check Configuration** runs `play --info`: it validates/prints the saved record without launching a game. It is not a dependency or connectivity test.
- File → Open Library, Export Library Copy and Reload Library.

Settings (`⌘,`) includes the Racket executable, an optional backend-folder override and whether to hide the launcher when launching. Leave the executable/backend paths blank for automatic discovery and the bundled backend.

The app supervises one launch at a time. Editing is disabled during a launch. It asks about unsaved changes before switching records or quitting, and prevents normal app termination while a launcher session is still active. Closing its window does not stop the session; reopen it from the Dock.

### Saving and backups

Save validates the entire library and writes it atomically. The previous disk contents are saved to `games.json.backup` (or `<custom filename>.backup`). This is one rolling backup, not a history.

If the library changed externally since it was loaded, Save refuses to overwrite it. Use **Export Library Copy** to preserve your draft, then reload the original. Unknown JSON fields are retained by the editor; unsupported schema versions are rejected rather than silently converted. Avoid simultaneous editors: change detection is a guard, not a distributed locking system.

Removing an entry only removes configuration. It does not delete installed games or save files.

## Sharing the library with Terminal / Platypus

The **updated** `main.rkt` loads configuration in this order:

1. `GAME_LAUNCHER_LIBRARY`, when explicitly set. A missing/invalid explicit file is an error.
2. The default Application Support `games.json`, if it exists.
3. The original `games.rkt`, if no shared file has been created.

Your existing installed backend is not automatically updated. The GUI uses its bundled copy, so it can be tried without replacing your installed scripts.

For a read-only check using the supplied backend, from the extracted folder:

```sh
GAME_LAUNCHER_SCRIPT="$PWD/game-launcher/main.rkt" sh ./play --info afterimage
```

After the GUI creates the default library, this command reads that same file. To launch instead, replace `--info afterimage` with the desired alias.

For a custom library selected with Open Library, explicitly point Terminal at that same file:

```sh
GAME_LAUNCHER_LIBRARY="/absolute/path/to/games.json" \
GAME_LAUNCHER_SCRIPT="$PWD/game-launcher/main.rkt" \
sh ./play --info afterimage
```

To make your usual installed `play` use the new library, first back up your installed `play` and backend. Then install the supplied `main.rkt`, new `library.rkt`, corrected `wine.rkt`, and updated `play` into the corresponding locations. Keep your installed game definitions and other custom files. The default backend path in `play` remains `~/bin/game-launcher/main.rkt`.

The original `play` shebang is retained. The app and these examples explicitly use `/bin/sh`, so they do not require `/bin/dash` to exist. For direct executable use of `play` on a Mac without `/bin/dash`, use `/bin/sh` in its shebang.

Optional overrides understood by the supplied `play`:

```text
GAME_LAUNCHER_RACKET   Absolute path to a particular Racket executable
GAME_LAUNCHER_SCRIPT   Absolute path to main.rkt
GAME_LAUNCHER_LIBRARY  Absolute path to the JSON library (read by main.rkt)
```

## Migrating later changes to games.rkt

The supplied seed is a snapshot. Once the shared JSON file exists, editing `games.rkt` no longer updates that library automatically. Normally, edit games in the GUI instead.

To export another snapshot:

```sh
racket game-launcher/export-library.rkt /path/to/new-library.json
```

The exporter validates the result and refuses to overwrite an existing destination. Open the resulting file in the GUI. Custom procedure-valued focus routines cannot be serialized and produce an explicit export error; named hooks are a later feature. None of the 118 active imported entries requires one.

## Important version-1 boundaries

This release concentrates on configuration editing. It intentionally retains the existing launch behavior:

- **RDM, cliclick and Cursorcerer have not been replaced.** Display switching and clicks still use those tools. Hide-on-launch may help avoid the launcher covering a game, but it is not a new Wine window-focus implementation.
- Display changes still skip the current `1920×1080` case and restore the existing **1440×900 / pointer 1×** profile, not a snapshot of your previous settings. Custom profiles must correspond to modes RDM actually supports.
- **Stop Session uses the old broad cleanup.** It can affect other Wine sessions and helper processes. The UI warns before doing this. Close games normally when possible, and test cancellation without unrelated Wine sessions running.
- Process detection and waiting remain the existing implementation. A game that never starts can leave the backend waiting; there is no new launch timeout.
- Some runners suppress their child program output and do not propagate all failures. “Finished” means the backend exited successfully, not proof that a game ran correctly. The log shows what the backend emits.
- Store authentication is still managed by your existing tools. GOG save-sync and the other scripts keep their existing side effects.
- Paths such as RDM, cliclick, Heroic binaries and the Rosetta loader remain in `config.rkt`. This release does not provide a GUI for every global backend constant.
- `wine_env.sh`, `wine_x87.sh`, the PowerShell runner scripts, Wine wrappers, cleanup scripts, blackbars and store credentials are **not included**. They stay at their existing paths on your Mac. These need real-machine testing.
- Directory fields should preferably use absolute paths. Existing leading `$HOME/` and `$WRAPPER/` forms are allowed, with behavior depending on the runner; relative GOG Wine save paths are interpreted under `drive_c`.
- The existing runners build shell commands. The new JSON boundary rejects double quotes, backticks, backslashes, newlines and unsupported `$` substitutions in launch-relevant strings. Use forward slashes in Wine paths. This is conservative validation, not a rewrite of the shell runners.

**Imported settings were not guessed or corrected.** For example, `thefallepic` retains its inherited Wine wrapper, and an entry whose wrapper is only `Contents` remains as supplied. Choose the appropriate native/Wine method or wrapper in the GUI if those entries were unintended. Selecting a *new* Direct → macOS launch method explicitly clears the Wine wrapper.

The one runner-related correction is wrapper-path resolution: absolute `.app` paths selected by the file picker retain their leading slash, and trailing slashes on `.app`/`Contents` paths are normalized.

macOS may request Automation or Accessibility permissions when the existing AppleScript/click helpers run from the new app. Grant permissions to the application/helper identified by macOS if you want those features. RDM replacement and native focus APIs are not part of this release.

## Verification

Portable checks, requiring Python 3 and a full Racket installation:

```sh
python3 GameLauncherApp/scripts/verify.py
```

They compile the Racket modules, run the RackUnit suites, inspect all 118 entries through the CLI, test library selection and export safety, and exercise `play` with a harmless mock backend. They do **not** launch games or invoke display/focus/cleanup actions. Temporary library-selection tests use an isolated HOME. Resource preparation updates only the source tree's `Resources` directory.

Optional Swift grammar parsing (not compilation):

```sh
python3 -m pip install tree-sitter tree-sitter-swift
python3 GameLauncherApp/scripts/verify.py --swift-syntax
```

On macOS, `build-macos.sh` runs the included Swift XCTest suite for decoding, 118-game round trips, unknown metadata, native/Wine selection, validation, backups and external-file conflict detection. Those Swift tests could not be executed in the Linux sandbox.

### Suggested first Mac test

1. Build and open the app. Confirm the sidebar contains 118 games and Settings finds Racket.
2. Choose an existing game and run **Check Configuration**. Verify its details in the log.
3. Duplicate an entry, change settings and save. Reload the library and check that the changes persist. Remove only the test entry when finished.
4. Choose a known-working native game. For the first launch, consider **Keep current display** and disabled focus clicks. Close the game normally and inspect the log.
5. Test a known-working Wine game. Confirm the wrapper path and your external scripts first.
6. Only then test resolution switching, focus automation and cancellation, without other Wine sessions running.

## Source layout

```text
GameLauncherApp/
  Package.swift                 Swift package; no external Swift dependencies
  Sources/LauncherCore/         JSON model, validation and safe library writes
  Sources/GameLauncherUI/       SwiftUI editor, settings, session supervisor, logs
  Tests/LauncherCoreTests/      Swift XCTest suite
  Resources/Backend/            Bundled copy, refreshed from ../game-launcher and ../play
  Resources/games.seed.json     Bundled snapshot, refreshed from ../game-launcher/games.seed.json
  scripts/verify.py             Portable verification
  prepare-resources.sh          Refreshes resource copies, not the exported seed itself
  build-macos.sh                Runs Swift tests/build, bundles and signs the app
  Info.plist

game-launcher/                  Canonical Racket source
  library.rkt                   Versioned JSON reader and migration helpers
  export-library.rkt            Safe legacy-to-JSON exporter
  games.seed.json               Export of the 118 supplied active entries
  tests/                        Library/migration and wrapper-path regression tests
play                            Existing supervisor with explicit path overrides
```

Edit the canonical Racket files under `game-launcher/`, not the generated copies under `Resources/Backend/`. The build script refreshes those copies. Runtime edits in the GUI go to Application Support, never back into the source seed.
