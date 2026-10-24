# Verification — 0.4.1 source delivery

## 0.4.1 Mac build failure resolved (2026-09-24)

**Outcome: the corrected source builds, tests, packages and signs on macOS.** The user reran `build-macos.sh` against the fix and `dist/Game Launcher.app` was produced — the first Mac-side confirmation of the 0.4.0 Swift integration, which had previously been delivered uncompiled. Evidence inspected in this sandbox after that run:

- All three release products built: `GameLauncher` (1,384,816 bytes), `GameRunner` (716,152), `GameDisplayTest` (604,528), each a Mach-O 64-bit little-endian binary (`cffaedfe`), with `.dSYM` companions.
- Both `.xctest` bundles were built and executed (`LauncherCoreTests.xctest`, `LauncherRuntimeTests.xctest`), so the test gate that had aborted 0.4.0 passed.
- The app bundle is complete and ad-hoc signed: `Contents/MacOS/GameLauncher`, `Contents/PkgInfo` (`APPL????`), and `Contents/_CodeSignature/CodeResources` (9,416 bytes).
- Localization shipped correctly: `Contents/Resources/GameLauncher_LauncherCore.bundle/Contents/Resources/` contains both `en.lproj` and `pt-BR.lproj`, with all 282 pt-BR keys present — confirming the catalogs reach the packaged app, not just the test bundle.
- `.build` no longer contains any reference to the old `/Users/pedro/.osaurus/artifacts/…` path, so the rebuild happened cleanly at the new location.

The original 0.4.0 failure was **not** a compilation failure. `swift build` succeeded (`Build complete! (0,56 seg)`), all 53 XCTest methods ran, and exactly one failed. Because `build-macos.sh` starts with `set -eu` and runs `swift test` before any release build, that single failure aborted the script before packaging, signing and verification — so no `dist/Game Launcher.app` was produced. 0.3.5 has a `dist` because its tests all passed.

The one failure, verbatim from the user's log:

```
LibraryTests.swift:72: error: XCTAssertEqual failed:
("Optional("2048 × 1280 · 1× / ponteiro 2×")") is not equal to
("Optional("2048 × 1280 · 1× / pointer 2×")")
```

Root cause: the assertion hardcodes an **English** expected label, but the value it compares against is localized. `GameRecord.displays` builds each label with `L(…)`, which resolves through `L10n.language`, itself derived from `Locale.preferredLanguages`. The user's macOS system language is Brazilian Portuguese, so the pt-BR catalog supplied `ponteiro` and the English literal could never match. This is a defect in the *test*, introduced by the very localization feature 0.4.0 adds: the label was written before translation existed and its assertion was not updated. The 0.3.5 test suite predates localization, which is why it passed there.

Fix (test only, `Tests/LauncherCoreTests/LibraryTests.swift`): compare against `L10n.lookup("2048 × 1280 · 1× / pointer 2×")`, the same lookup the UI performs, so the assertion is correct under any system language. Two additional language-pinned assertions (`L10n.render(…, language: "en")` and `"pt-BR"`) keep the intended wording of each catalog verified, matching the existing style of `LocalizationTests`. No production code, persisted data or catalog entry changed.

Verification performed here (Linux, no Swift compiler):

- **Audit for other locale-dependent assertions.** Parsed every string literal in `Tests/**/*.swift` and cross-referenced both catalogs. Of 282 keys, exactly two have a translation differing from the key and appear in tests: the display label above, and `"Ready"`. Every `"Ready"` use in `LocalizationTests` already pins `language:` explicitly or reads a specific `pt-BR.lproj` bundle. No other test can fail on a Portuguese system.
- **Reproduced the failure and confirmed the fix.** Re-implemented `L10n.selectedLanguage` and `render` faithfully (including the `_`→`-` normalization, the `pt`/`en` prefix matching and the English fallback) against the real catalogs. Old assertion: FAIL under `pt-BR` and `pt_BR`, PASS under `en-US` and `ja-JP` — exactly matching the user's reported error text. New assertion: PASS under all four. Both language-pinned catalog assertions: PASS.
- **Full portable suite re-run.** `verify.py --swift-syntax`: 37 RackUnit cases, all 118 seed entries through read-only `--list`/`--info`, exporter round-trip and overwrite refusal, 2048×1280 profile through `play --info`, resource/shell/plist checks, 25 Swift syntax parses. `verify-input-localization.py`: 282 keys per language, identical placeholders, actual-source catalog coverage, and the real Racket focus bridge across success/negative/cancel/timeout/stale-reply/malformed-owner. `verify-wine.py` and `verify-cancel.py`: all Wine and nine Cancel fixtures. Syntax parsing is not type checking.

Still requires a Mac, now narrowed by the successful build above: real English/Portuguese layout, TCC grants for the editor and each exported app, focus clicks in a real game, cursor restoration, and no-late-click behavior on Cancel. The release build and XCTest run itself are no longer outstanding.

Note for rebuilding from an extracted archive: a `.build` directory carries absolute paths to the location where it was produced. If the folder is moved, delete `.build` before rebuilding so SwiftPM does not reuse stale paths. The 0.4.1 source archives exclude `.build`, `dist`, Racket `compiled` caches and `.DS_Store`.

## 0.4.0 input, localization and export


Environment: Linux aarch64, Racket 9.0, Python/tree-sitter Swift and a C compiler. **No Swift compiler or macOS SDK.** The existing C private-cursor bridge was copied from the diagnostic that compiled/ran on the user's macOS 27.0 / 26A428; the new Swift integration has not been compiled here.

Passed portable checks:

- `python3 GameLauncherApp/scripts/verify.py --swift-syntax`: 37 RackUnit cases, all 118 seed entries through read-only list/info, JSON/legacy fallback/export, 2048×1280 display profile, resource equality, shell/plist/source checks, 25 Swift syntax parses. Syntax parsing is not type checking.
- `python3 GameLauncherApp/scripts/verify-input-localization.py`: 282 keys in each language, identical placeholders and actual-source catalog coverage, packaging/technical-token checks; actual Racket focus client/bridge with acknowledged click/click/hide/click, negative response, cancellation, timeout, stale reply and invalid owner. No events posted. Actual `play --export-racket` on an isolated JSON fixture, including explicit 2048×1280 and overwrite refusal; input ownership ignored for read-only export.
- `python3 GameLauncherApp/scripts/verify-wine.py`: fake Wine/store/live-environment, renderer, quiet-output and cleanup fixtures all pass; no real Wine or user files used.
- `python3 GameLauncherApp/scripts/verify-cancel.py`: all nine signal/display-owner combinations pass; no actual display or Wine operations.

53 Swift XCTest methods are provided but **not executed in this environment**. New tests use an injected fake input driver for sequencing, replay/stale/mismatch refusal, cancellation, retryable restoration and controller cleanup ordering; localization tests cover language choice, interpolation, resource copying and older-export defaults. They perform no real global input. `build-macos.sh` runs Swift tests, builds all products and signs/verifies the app on the Mac.

Still required: Mac compilation/XCTest, actual English/Portuguese layout and language selection, TCC grant/regrant behavior for editor and each exported app, focus clicks in a real Wine/native game, cursor restoration and no-late-click behavior on Cancel, and normal session cleanup. Private API stability and recovery after Force Quit are not guaranteed. The user's earlier timed diagnostic verified background hiding and visual restoration on movement/normal timed completion only.

See [NATIVE-INPUT-AND-LANGUAGE.md](NATIVE-INPUT-AND-LANGUAGE.md) for the guarded first-use sequence. Earlier verification sections below are historical.


## 0.3.5 Wine output suppression

User reports 0.3.4 seems to work correctly, except Wine output is now visible and too noisy. No broader claim about every platform or Cancel is inferred from that report.

The shared adapter had no Wine stderr redirection; existing runners suppress launch stdout. Added `2>/dev/null` to its Rosetta and non-Rosetta exec paths only. Live-script status/error output and existing store-tool streams are not newly redirected; adapter stdout remains available for queries. No extra process/trap/supervisor or environment-variable override is introduced.

Before the fix, the new fixture assertion reproduced leaked Wine and loader stderr next to the intended environment status. After the fix, Rosetta on/off and version probes retain only the intended status on stderr, with query stdout unchanged. All five real runner/JSON fixtures (fake Wine/store tools, stubbed focus/waits) assert no Wine noise in either displayed stream. Existing Racket/live-script progress and store stderr remain visible; nonzero Wine status still produces the existing launch error and cleanup. The Wine cleanup helper and its diagnostics are unchanged.

Full portable checks pass: 33 RackUnit cases, expanded Wine fixtures, 9 baseline Cancel cases, resource/shell checks and 21 Swift syntax parses. 44 Swift XCTest methods were not run in this Linux sandbox. Actual 0.3.5 Mac log behavior remains to be checked; this is an output-only change. Earlier verification notes below are historical.


## 0.3.4 renderer regression fix

User ran the built 0.3.3 Mac app; Ender Magnolia failed before Wine launch with `string-replace: expected string?, given 'd3dmetal`. The log reports successful native restoration afterward. This demonstrates the error/restore path, not successful Wine game startup or cleanup.

Reproduced locally before patching: four of six new RackUnit cases failed, including the same error for the JSON-decoded Ender Magnolia record and the separate `putenv` symbol failure. All six pass after converting symbols to strings at both Wine boundaries. Total RackUnit count: 33.

Expanded `verify-wine.py` passes both symbol and string inputs for all six renderers through actual Racket command/environment setup and a compiled fake Wine binary. It also runs the unchanged Steam/direct/Epic/GOG/Amazon runner code with real JSON-decoded records, an isolated fixture wrapper/live environment, fake store/Wine executables, and stubbed focus/process waits. Ender Magnolia's PowerShell argument vector and failure cleanup are asserted. No actual Wine, Rosetta translation, Steam, cloud sync, pointer, display or host process cleanup is tested here.

Full portable suite, existing Wine fixtures and 9 baseline Cancel cases pass. 21 Swift files syntax-parse; the 44 Swift XCTest methods were not executed here. Swift logic and native display/GUI Cancel remain byte-identical to 0.3.3 apart from version metadata. Actual 0.3.4 Mac launch remains to be tested. Earlier verification notes below describe historical revisions.


## 0.3.3 follow-up

User confirmed neither wrapper was running during the reported silent exit-1 result; 0.3.2 app has not been tested yet. Fixed the helper's already-stopped classification and added fixtures for idle prefixes, diagnostic/nonzero wait failure, bounded active/blocked checks, an uncooperative wait child, and normal Racket cleanup after Wine has exited. Expanded Wine fixture suite passes, as do 27 RackUnit cases, 9 baseline Cancel cases and 21 Swift syntax parses. 44 Swift XCTest methods remain unexecuted here. No new Swift/Racket/GUI Cancel behavior; only helper/tests/docs and release metadata (0.3.3/build 10) differ from 0.3.2. Actual 0.3.3 Mac execution remains to be tested. See WINE-IDLE-STATUS.md. The original 0.3.2 verification below remains applicable to unchanged features.


2026-09-23. Linux sandbox with Racket, Python/tree-sitter and a C compiler; **no Swift compiler/macOS SDK**.

## Evidence and scope

The user supplied wine_env.sh, wine_x87.sh, kill-wine-processes.sh and real dyld errors. Neither environment/adapter script has cleanup traps. The kill helper's library-copy condition can skip the needed wine/lib copy; the DXVK binary reports no LC_RPATH; a final echo hides failures. This release targets those concrete problems rather than changing GUI signals again.

- Rewritten helper repairs missing copies independently, supplies wrapper-local DYLD search paths and aggregates failure status. Read-only --check and absolute wrapper paths supported. No install_name_tool, binary patch, re-signing or force-kill escalation.
- 0.3.1 speculative Cancel changes reverted to the 0.3.0 supervisor flow. Wine helper output remains visible. Window-centering timing fix retained; native display implementation and focus/pointer policy unchanged.
- New backend-owned Wine adapter replaces the external wine_x87.sh dependency. Sources selected live wine_env.sh, honors Rosetta/renderer/DLL input, preserves arguments/status and uses the file's RUNTIME_LOADER definition. Normal Racket cleanup uses the bundled fixed helper for the selected wrapper.
- App setting stores the live environment file path and opens it using the default text editor (open -t), not the .sh execution association. New exports retain the path, not file contents. Supplied private wine_env.sh is not rewritten or bundled.

## Executed checks

```sh
python3 GameLauncherApp/scripts/verify.py --swift-syntax
python3 GameLauncherApp/scripts/verify-cancel.py
python3 GameLauncherApp/scripts/verify-wine.py
```

- Racket modules compile; **27 RackUnit cases pass**.
- List/info tests cover all **118 games**, library fallback, export/overwrite protection and harmless supervisor output/exit propagation.
- **9 baseline isolated cancellation cases pass**, covering TERM/INT/HUP with legacy/native-skip/native-managed restoration. All macOS/Wine helpers are mocked.
- New Wine fixture suite passes. It compiles a non-shell fake wineserver to observe actual env/argument delivery, verifies independent copies when SharedSupport already has a copy, read-only preflight, preserved existing files, missing inputs/dangling symlinks, per-wrapper isolation, nonzero/abort-like status aggregation, live environment edits, custom loader, Rosetta on/off, shell-safe paths, stderr/stdout separation and actual Racket invocation/normal cleanup. **It never loads libinotify or runs real Wine.**
- Shell syntax, prepared resource bytes and adapter executable permissions pass.
- **21 Swift files syntax-parse**; explicit source guards retain early observer registration and bounded positioning. This is not Swift type checking or AppKit testing.

## Mac checks required

**44 XCTest methods** (23 core, 21 runtime) are authored but not run here. New tests cover path validation/readability/symlinks, export compatibility/adapter copying/live-file exclusion, and literal environment propagation. The Mac build runs the Swift tests before packaging.

Test the replacement kill helper first (--check, then a saved single-prefix session). Build 0.3.2 and re-create exports, select the correct live environment path, test editor opening, normal exit and Cancel, and one Heroic launch. Confirm real Wine processes stop. --check does not validate dyld loading, architecture or hardened-runtime restrictions; a successful mock cannot establish those properties.

Follow **WINE-INTEGRATION.md** for installation/rollback and diagnostics. Native switching success in 0.3.0 is user-reported; 0.3.2 Mac build, dyld and UI behavior remain unverified. Source version **0.3.2 / build 9**; archive excludes caches and contains the standalone helper as well as the app project.
