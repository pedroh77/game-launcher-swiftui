# Native per-game launchers — version 0.3.1

**0.4.0 update:** native focus/cursor is now a separate opt-in setting, and new exports include both language catalogs and the chosen input setting. Racket still owns focus timing; cliclick/Cursorcerer remain the legacy option. Re-create exports to adopt the changes. See [NATIVE-INPUT-AND-LANGUAGE.md](NATIVE-INPUT-AND-LANGUAGE.md). The versioned details below describe earlier releases.

**0.3.2 update:** re-create exports to get the bundled Wine adapter, corrected prefix-cleanup helper and selected live environment path. The file contents stay external; edits need no rebuild. Changing the path requires re-export. The 0.3.1 cancellation exit-75/UI policy is reverted; centering timing is retained. See **WINE-INTEGRATION.md** (supersedes older cancellation/Wine details below).


This implements the native design in PLATYPUS-RESEARCH.md. It does **not** generate a Platypus app or require Platypus to be installed. The exported app has its own small AppKit window and runs the same Racket/backend supervisor as the editor.

## Build and create a launcher

1. Quit the previous Game Launcher after any game session finishes. Extract this source version into a separate folder to preserve local source changes.
2. From the extracted folder:

   ```sh
   sh GameLauncherApp/build-macos.sh --open
   ```

   This runs the Swift tests, builds both the editor and `GameRunner`, bundles the runner in the editor, and ad-hoc signs the editor. Output remains `GameLauncherApp/dist/Game Launcher.app`. Your existing library and settings are retained.
3. Select a game and choose **Game → Create Launcher…** or the toolbar button. Resolve any unsaved changes first.
4. Choose:
   - **App name:** defaults to the game title. The title can contain a colon; the generated filesystem name removes colons and replaces slashes to avoid Finder filename ambiguities.
   - **Bundle identifier:** defaults to `org.<username>.<sanitized-title>`. Spaces, colons and unsupported punctuation are removed; accented Latin letters are normalized. Non-Latin titles fall back to the game alias. If the current library contains another game with the same generated identifier, the alias is appended. You can edit the identifier; keep it unique.
   - **Output:** Progress bar + current message, or Text output. Both include Cancel and can show/hide details. The bar is indeterminate: the existing backend does not report a reliable completion percentage.
   - **Icon:** use **Choose .icns…** to select an Apple icon file. Without an icon, Finder uses a generic application icon.
5. Click **Create…**, choose a new `.app` destination and wait for signing. The generator **never overwrites an existing app**. Nothing is launched automatically. Use **Show in Finder** and open the exported app when ready.

No developer account, Platypus install or separate compilation step is needed when exporting from the built editor. A compiler is needed only to build the editor source delivery. Export itself uses the native runner already bundled in the editor and macOS's `/usr/bin/codesign`.

For source/Xcode development, `swift run` alone does not prepare the runner resource. Use `build-macos.sh` and the resulting editor `.app` to test export.

## Native display option in 0.3.0

First follow the guarded test in **NATIVE-DEPENDENCIES.md**. RDM is the default. After successful testing, enable **Settings → Display manager → Use native display switching instead of RDM**, then create a new per-game app. The export form shows the selected manager. This selection is saved in `launcher.json`; changing the editor preference does not change an existing exported app. Old configuration files without the optional `nativeDisplay` field use RDM.

Native exports require the updated bundled/compatible backend and include `native-display.rkt`. Their embedded runtime owns mode changes from before backend spawn until `play` cleanup finishes. Both game completion and Cancel use that same owner to restore 1440×900 at 2×; the backend retains pointer/blackbar cleanup but skips RDM calls. Failed restoration leaves the window/session open with **Retry Display Restore** instead of automatically quitting. Restore the display topology before retrying. One built-in, non-mirrored online display is supported initially.

CoreGraphics mode changes last for the program's lifetime; after the app exits, macOS reverts to the permanent Displays setting. Verify your desktop remains correct **after the diagnostic worker and exported app exit**, as well as while they are alive. No permanent display settings are written. Keep the working RDM app/export as fallback until both normal and cancelled native sessions have passed.

The diagnostic executable is bundled in the editor only, not copied into game apps. Its separate worker/watchdog and 12-second timer never limit the length of an actual game session.

## Window behavior

- The output window is an **NSPanel with non-activating style at normal window level**, not an always-on-top window. It uses `orderFront`, not `makeKeyAndOrderFront`, and never requests application activation during startup, output updates, errors, or display changes.
- The window is **horizontally centered on the launch display**, with its titlebar **4 macOS points below the visible menu-bar area** (8 backing pixels on a 2× display). It remembers that display during the session and recomputes the position after a display-geometry change or Show/Hide Details. Horizontal placement is clamped to the usable area if a Dock inset or narrow screen would otherwise hide part of the window. If the display disappears, it falls back to an available screen.
- Content size is **560×160 points** for progress mode, **560×330 points** with details/text output, plus the native titlebar. You can drag the panel away temporarily; the next display change or details toggle reanchors it.
- The standalone app is an accessory app: **no extra Dock icon or menu-bar app menu while running**. Its `.icns` remains visible in Finder and in any Dock shortcut you add. Cancel is available in the window, not through a separate menu.
- It does not join every Space or float over fullscreen games. If the game covers it, switch back to the desktop containing the panel to cancel, as with other ordinary windows.

This removes the launcher's deliberate focus requests. It does **not** prove that every Wine game focuses itself correctly. Existing focus-click delays and coordinates are unchanged. Test a game with focus automation disabled before deciding whether to remove its workaround.

## Cancel, close and automatic exit

**0.3.1:** installed Wine cleanup scripts are explicitly awaited without a process-name gate. Script errors remain visible; a cancelled export stays open on cleanup-failure exit 75. Re-create exports to get both this behavior and the native display centering timing fix. See **CANCEL-AND-POSITION.md**.

Platypus's Cancel sends **SIGTERM**, not Ctrl+C / SIGINT. The native runner does the same by starting **`/bin/sh play <alias>` directly as its Process** and calling `Process.terminate()`. There is no extra shell between the runner and `play` to swallow the signal.

- Cancel, the red close button, and a normal application quit request all use this path.
- During cancellation the button is disabled and the window remains open until `play` exits. Repeated cancellation does not send another SIGTERM halfway through cleanup.
- The existing `play` trap performs cleanup. Its broad Wine/helper cleanup and fixed restore profile are retained. In native mode, the runtime performs the resolution restore after this cleanup, instead of RDM. **Other Wine sessions can be terminated too. Save in the game before cancelling and use one launcher session at a time.** Separate generated apps do not share a global session lock with each other or with the editor.
- On ordinary completion, the backend's normal game monitoring, Steam sync waits and display restoration still run. The exported app automatically exits after the supervised process completes and output is drained. A one-second drain limit prevents a detached process holding stdout open from keeping the launcher alive forever; it does not impose a timeout on the game or cleanup.
- A configuration error detected **before starting the backend** stays visible until you click Close, so a missing library or renamed alias can be diagnosed. Once the backend has run, even a nonzero exit closes the app; consult its saved log.
- Force Quit, SIGKILL, power loss and crashes cannot guarantee cleanup. Use Cancel or normal close instead.

## What is bundled, and what stays live

Each exported app bundles:

- The native `GameRunner` executable for the same architecture as your editor build.
- The current `play` supervisor from the editor.
- A snapshot of the selected backend's `.rkt` source files, including runner modules; no compiled caches or tests.
- Launcher metadata (alias, library path, selected Racket path, window style and title), plus the optional `.icns`.

It does **not** copy or reseed your game library. It reads the **same absolute `games.json` path and alias** on every launch. Saved renderer, resolution, focus and other game-setting changes therefore apply to the existing shortcut. Changing the alias or moving the library requires recreating the launcher. The shortcut's name/icon/style are export-time choices, not live library fields.

`wine_env.sh`, `wine_x87.sh`, Wine wrappers, Racket, RDM (for the default/legacy path), cliclick, Cursorcerer, store tools and game installations stay external. Changes to your Wine scripts still apply without recreating the shortcut. Recreate exported apps when updating the launcher engine itself, changing the selected Racket executable, or moving between CPU architectures. Moving the main editor app does not break generated apps.

If you selected a custom backend folder in Settings, its Racket source is snapshotted. Custom non-Racket assets are **not** bundled automatically; keep those at their established external paths. The generator is designed for this project's backend layout, not arbitrary third-party script packages.

These are personal local apps, not notarized/distributable game packages. They depend on paths, permissions and installed tools on your Mac. macOS may request Automation or Accessibility approval for the generated app or its helpers; existing permission for Platypus/the editor does not necessarily cover each new bundle identifier. The native panel itself does not require Accessibility permission to position or display itself.

## Logs and safe configuration checks

After a session (or startup error), the app saves its bounded output log to:

```text
~/Library/Logs/Game Launcher/<bundle-identifier>.log
```

This is the most recent session only, with up to approximately 256 KB of captured output. Show Details → Save Log can save another copy during the session.

A generated app also supports a **non-launching** check from Terminal:

```sh
"/path/to/Your Game.app/Contents/MacOS/GameRunner" --check
```

This runs the bundled `play --info <alias>`, prints configuration and returns its exit status. It does not open a window, launch a game, change resolution or invoke cancellation cleanup.

## Mac verification checklist

This source was syntax-checked in Linux, not compiled against AppKit/SwiftUI here. On your Mac:

1. Build with the command above; all Swift tests must pass before using the resulting app.
2. Export a test game to a new location, using a title with a colon and a chosen `.icns`. Verify its Finder icon, title, bundle ID and `--check` output.
3. Try both progress and text modes. Start with no other Wine sessions running. Confirm the panel begins near the menu bar and stays near it when RDM changes the resolution.
4. Confirm ordinary game exit closes the launcher only after normal backend cleanup/sync. Then test Cancel separately, after saving in the game, and check display restoration and Wine cleanup.
5. Test the red close button during a session: it should show cancelling and wait, not discard the supervisor.
6. Save a harmless game-setting change in the editor and run the same shortcut's `--check`; it should read the new settings. Do not rename the alias during this test.
7. Only then try disabling a particular game's focus clicks. No focus presets have been removed automatically.
