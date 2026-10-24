# Wine integration — 0.3.2

**Current source: 0.3.5.** Wine launch stdout remains suppressed by the runners, and Wine/Rosetta stderr is now silenced at the adapter's final exec. Live environment-script progress and validation errors remain visible, as do existing store-tool messages. The adapter still preserves stdout for internal queries such as `--version`; do not redirect all adapter stdout globally. Existing store stdout/Comet policies and cleanup diagnostics are unchanged. No live environment edits or cleanup-helper reinstall are required for this patch. Rebuild the editor and recreate exported apps to update their bundled `wine-launch.sh`.


**0.3.4 renderer fix (retained).** Fixes a Racket type-conversion regression in both Wine command construction and environment setup. Real game records use symbols such as `'d3dmetal`; both boundaries now convert them to strings. No `wine_env.sh`/library edits are needed. The 0.3.3 shell cleanup helper is unchanged and need not be reinstalled if already updated. Build this source and replace/re-create apps containing older backend copies. The integration instructions below still apply; earlier version references are historical.


**0.3.3 correction:** the user's subsequent test was made with no Wine sessions running. Silent `-k` exit 1 is expected in that case; the helper now checks the prefix with a bounded `-w` call and reports **Already stopped** instead of an unconditional error. See **WINE-IDLE-STATUS.md**. Install the supplied 0.3.3 helper and use the 0.3.3 source for the build; the environment/adapter/editor integration described below is unchanged.


## What the supplied scripts establish

The user's log shows both `wineserver` binaries aborting during **dyld loading**, before `-k` can do cleanup. This is not evidence that the GUI chose the wrong signal.

- Steam_SK searches `SharedSupport/wine/bin/../lib/libinotify.0.dylib`. The original script only copied to that location when the separate `SharedSupport/libinotify.0.dylib` copy was missing. If the first copy already existed, the needed second copy was never repaired.
- Steam_DXVK reports **no LC_RPATH**. Copying the library into an arbitrary directory cannot create a missing run path. The rewritten helper supplies an explicit **DYLD_LIBRARY_PATH** for the direct wineserver invocation.
- The original script ends with `echo "Done!"`, returning success even after both commands abort. The rewrite collects failures and exits nonzero if any requested wrapper fails.
- Neither supplied `wine_env.sh` nor `wine_x87.sh` installs a cleanup trap. The first defines an environment/functions; the second sources it and uses `exec`. Keeping the environment file is valuable for shared configuration, not because these particular files implement a SIGTERM/SIGINT cleanup handler.

The dyld manual documents leaf-name lookup in DYLD_LIBRARY_PATH and warns that protected binaries can ignore DYLD variables: https://keith.github.io/xcode-man-pages/dyld.1.html . The replacement has not been exercised against the user's actual Mach-O binaries in this Linux sandbox.

## Install the replacement terminal/Cancel helper first

The archive's top-level **kill-wine-processes.sh** is byte-for-byte the same implementation as `game-launcher/wine-cleanup.sh`. A standalone download is supplied too. No Mac files were changed automatically.

From the extracted parent folder, back up the old file and install:

```sh
cp -p "$HOME/bin/kill-wine-processes.sh" \
  "$HOME/bin/kill-wine-processes.sh.backup-$(date +%Y%m%d-%H%M%S)"
install -m 755 kill-wine-processes.sh "$HOME/bin/kill-wine-processes.sh"
```

Read-only inspection (does not copy files or start wineserver):

```sh
"$HOME/bin/kill-wine-processes.sh" --check
```

Then, **after saving/closing work in that prefix**, test one wrapper:

```sh
"$HOME/bin/kill-wine-processes.sh" Steam_SK
"$HOME/bin/kill-wine-processes.sh" Steam_DXVK
```

A real invocation can end every Windows program in each selected prefix, not just one game. No arguments selects both wrappers as before. Names with `.app`, absolute `.app` paths, and absolute `.app/Contents` paths are also accepted, including paths with spaces.

### Repair behavior

- Defaults to `$HOME/Applications/Steam_DXVK.app` and `Steam_SK.app`, rather than hard-coding a username.
- Uses a readable `Contents/Frameworks/libinotify.0.dylib` from **the same wrapper**, with existing local copies as fallbacks. Never copies a library from the other wrapper.
- Repairs missing `SharedSupport/libinotify.0.dylib` and `SharedSupport/wine/lib/libinotify.0.dylib` **independently**. Existing readable copies are retained; a dangling destination symlink is reported instead of followed.
- Uses a temporary file and no-clobber rename to avoid publishing partial copies.
- Sets WINEPREFIX and wrapper-local DYLD_LIBRARY_PATH / DYLD_FALLBACK_LIBRARY_PATH only for the direct wineserver call. This covers the missing-RPATH case without rewriting the executable's load commands or re-signing it. Adding files can still affect an app bundle's resource seal, as with the user's existing copy-based repair.
- Reports missing files/prefixes, attempts all requested wrappers even after a failure, and returns a nonzero aggregate status on error.
- Uses ordinary `wineserver -k`, not `-k9` or global Wine process-name kills. Success means the kill request returned successfully; it is not an independent assertion that all Wine clients have exited.

`--check` validates paths and reports planned copies; it cannot verify architecture, dyld loading, signature policy or Wine shutdown. If a real run still fails, provide its output plus read-only diagnostics for the affected wrapper:

```sh
w="$HOME/Applications/Steam_DXVK.app/Contents"
file "$w/SharedSupport/wine/bin/wineserver" "$w/Frameworks/libinotify.0.dylib"
otool -L "$w/SharedSupport/wine/bin/wineserver"
otool -l "$w/SharedSupport/wine/bin/wineserver" | grep -A3 LC_RPATH
```

No automatic binary patch or security-setting change is included.

## Cancellation rollback and normal cleanup

The speculative **0.3.1** cancellation changes are reverted: no five-second grace change, unconditional helper invocation, extra fallback-on-failure sequence, new exit-75 protocol, or cancellation-error window policy. The original 0.3.0 SIGTERM-to-play supervisor flow is restored, including its original Racket grace and process-name gate. Helper output is no longer discarded, so an actual loader failure can be seen in the session log.

The **window-centering timing fix is retained**. Native display implementation, profiles, pointer values, focus clicks and game records are unchanged.

Normal Racket Wine cleanup now calls the **bundled fixed helper for the selected wrapper** instead of the old Steam-specific scripts/raw wineserver call. This applies the actual dylib fix on normal exit as well. Cancel retains the original external-helper route: install the replacement in `~/bin` as shown above. The bundled normal-exit helper is a backend snapshot; future edits to the external kill helper alone do not modify that bundled snapshot.

## Live wine_env.sh setting

After building 0.3.2, open **Settings → Live Wine environment**:

- Absolute file path including filename; defaults to `~/bin/libexec/wine_env.sh` expanded to your home directory.
- **Browse…**, **Use Default**, and **Open in Text Editor** buttons.
- The editor button uses `/usr/bin/open -t`, selecting the default text editor rather than the `.sh` file association, which could otherwise execute the script. It does not execute, rewrite or replace the environment file.
- The script is trusted executable shell configuration. Only select files you trust.

Every Wine launch sources this **live file**, so changes to Sikarugir detection, renderer settings or new environment variables apply on the next launch without rebuilding. The app never bundles `wine_env.sh` or duplicates its renderer/loader variable definitions.

New exported apps retain the selected **file path**, not its contents. Changing the file's contents requires no re-export. Changing its location in Settings affects the editor and future exports; re-create existing exported apps to give them the new path. Old configurations without the setting use the original default.

### One path in Terminal and the app

The user's supplied wrapper sources `~/bin/libexec/wine_env.sh`, while the shown Terminal alias sources **`~/.local/libexec/wine_env.sh`**. Unless these resolve to the same file through a symlink, they are separate configurations. Choose one canonical file and use its path in both places. For the app default, the existing alias can be changed to:

```sh
alias wine-env='function _wine_env() { WRAPPER="$1" RENDERER="${2:-d3dmetal}" source "$HOME/bin/libexec/wine_env.sh"; }; _wine_env'
```

The supplied environment file's contents are not changed by this release.

## Removing the external wine_x87.sh dependency

Heroic/Legendary/GOGDL/Nile's `--wine` argument needs an **executable path**, not a Racket function. Instead of maintaining a separate personal wrapper, 0.3.2 bundles a small **wine-launch.sh** adapter with the backend:

1. Racket supplies WRAPPER, RENDERER, optional DLL overrides and the Rosetta choice.
2. The adapter sources the configured live file, forwarding its status messages to stderr so Wine's stdout stays usable for probes such as `--version`.
3. It executes the file's **RUNTIME_LOADER and WINE_BIN** when Rosetta is enabled, or WINE_BIN directly when disabled, preserving all original arguments and the final exit status.

This adapter is shared by Steam/direct Wine and the Heroic stores. The old external `wine_x87.sh` is no longer referenced by the new backend. RUNTIME_LOADER now comes from the live environment instead of being re-hard-coded after sourcing it. Requested Rosetta with a missing loader fails explicitly rather than silently switching execution modes. Adapter/source errors are exposed; Steam/direct do not wait forever for a game after a failed launch command.

Keep the old `wine_x87.sh` until old exports/other personal scripts no longer depend on it. It is not deleted or overwritten by the build.

## Build and retest

```sh
sh GameLauncherApp/build-macos.sh --open
```

Use the bundled backend (override blank). **Re-create exported game apps** to get the updated adapter, cleanup helper, live-path setting and retained centering fix. Retest normal exit and Cancel with one saved game; check actual Wine process exit. For Heroic, also check one store launch with the requested renderer/Rosetta settings.

The script alone can be tested before rebuilding the app. Keep previous source/app copies and the backup helper while testing.

## Verification limits

Linux checks pass: 27 RackUnit cases, 9 baseline mocked cancellation cases, and the new isolated Wine fixture suite. The latter compiles a fake executable to verify actual environment/argv delivery, copy policy, failed status propagation, live file edits, Rosetta selection, shell-safe paths, and real Racket-to-adapter invocation. No real Wine, dylib loading, game, display setting or installed wrapper is exercised.

21 Swift files syntax-parse; 44 XCTest methods are present but cannot run here without Swift/macOS SDK. Build/signing, default-editor opening, UI sizing, real Wine/SDK behavior and the dyld fix require the user's Mac. Tree-sitter parsing is not Swift compilation.
