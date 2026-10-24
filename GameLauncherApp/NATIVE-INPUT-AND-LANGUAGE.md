# 0.4.0 — Native input, Portuguese and compatibility export

## Install this source update

Finish game sessions and quit the old editor. Extract this archive into a new folder, keep 0.3.5 as a fallback, and run from the extracted parent folder:

```sh
sh GameLauncherApp/build-macos.sh --open
```

The script runs Swift XCTest, builds and ad-hoc signs the editor, GameRunner and display diagnostic, and includes the localization resource bundle. Use `GameLauncherApp/dist/Game Launcher.app`; update any older copy you launch elsewhere. Leave **Backend folder** blank to use the updated bundled backend. Do not copy this backend over `~/bin/game-launcher` for this update.

Build preparation never replaces your live library, Wine environment or installed CLI scripts. Racket, Sikarugir Creator/Configuration.app, wrappers, Heroic tools, pointer/black-bars helpers and existing cleanup/save-sync scripts remain external. Wine output suppression from 0.3.5 is retained. There is no replacement for Sikarugir or Heroic here.

## Native focus and cursor — default in 0.4.2

In **Settings → Native focus and cursor**, **Use native clicks and cursor handling** is enabled by default (Portuguese: **Ajustes → Foco e cursor nativos → Usar cliques e cursor nativos**).

This applies to launches from the editor and newly exported per-game apps. It only performs input for games with delayed focus enabled. The Racket backend still waits for the game process and its configured delay, then requests:

1. One single click at the configured coordinates.
2. Another single click.
3. Cursor hiding.
4. After the existing 3-second delay, one final single click.
5. A second cursor hiding to ensure the pointer remains hidden after the final click.

The Swift runtime owns event posting and the cursor state. Requests use a private, acknowledged mailbox separate from console output. Only the five expected actions and configured coordinates are accepted. Repeated/stale/mismatched requests cannot cause extra clicks. Game stdout, Wine messages and log text are never treated as commands.

The original process wait, delay and order remain in Racket; mailbox acknowledgement introduces a small scheduling overhead (normally tens of milliseconds). No new game-window activation, process-name heuristic or automatic coordinate adjustment was added.

### Permissions and scope

- Requires **Accessibility** permission for the actual app posting events. Use the explicit permission button, grant access in **System Settings → Privacy & Security → Accessibility**, then reopen the app if necessary. A grant to the standalone diagnostic or Terminal does not establish a grant to the editor or exported apps. Rebuilding/ad-hoc signing may require reauthorization.
- Initially restricted to **one built-in, non-mirrored display**. No Screen Recording permission or global event-monitor tap is used.
- These are **global coordinate clicks**: whatever is at the configured location receives them. They are not verified as belonging to a Wine game. Test a noncritical game and do not interact with unrelated windows during delayed focus.
- Coordinates are Quartz screen coordinates (logical points), not HiDPI framebuffer pixels. Out-of-bounds coordinates stop input automation, without a silent legacy fallback or ending the game.
- Two original seed entries use `1919,1079` with a `1680×1050` profile. Those coordinates do not fit. Set appropriate per-game coordinates after checking the actual game window, or leave native input disabled. This update does not rewrite your records.
- Cursor hiding uses the same private WindowServer property validated by your standalone macOS 27.0 / 26A428 test. It hides once; movement can reveal it, and the final focus click may also reveal it. No repeated hiding or movement interception is added. Future macOS releases may change this private API.

### Cleanup and fallback

**Show Cursor / Mostrar cursor** restores the owned cursor state and cancels remaining native focus actions without stopping the game. Normal backend completion and Cancel also restore it. Failed restoration retains its owner and offers **Retry Cursor Restore**. Display restoration still follows backend cleanup, using the existing shared display manager; its Retry control remains separate.

The diagnostic's 20/23-second process-kill watchdog is intentionally NOT part of a multi-hour game session. App Force Quit, crashes and system shutdown cannot be guaranteed to execute cleanup; recovery after forced process death was not established by the timed diagnostic. No global persistent cursor preference is changed.

To go back, disable native input in Settings; existing Racket `cliclick` and Cursorcerer behavior is retained. There is **no automatic fallback after a native request fails**, to avoid duplicate/late clicks. Plain Terminal scripts receive no native owner and keep the original path. Native mode rejects an old backend lacking the bridge. RDM/native display selection is independent of native input.

## Brazilian Portuguese and English

The editor, game form, Settings/help, dialogs, validation, session status and exported-runner controls have both `en` and `pt-BR` catalogs. Portuguese is selected when it is the preferred supported system/app language; English is the fallback. Language is chosen at launch. macOS per-app language preferences can be used to select English or Portuguese explicitly; reopen the app after changing them.

The localization bundle is copied into exported apps, so it does not depend on the editor remaining installed. Game titles, notes, paths, JSON keys, renderer tokens, aliases and script content are not translated. Technical native diagnostics and external Racket/Wine/store-tool logs remain as produced; there is no output translation/filtering layer. Portuguese display labels do not alter stored values.

## Export `games.rkt`

Use **File → Export games.rkt…**, or the button under Settings → Library. Portuguese: **Arquivo → Exportar games.rkt…**.

- Includes the current validated draft, even if it has not been saved to JSON.
- Writes a **new** file only; even confirming replacement in the save panel will not overwrite an existing script.
- Generated `games.rkt` requires your existing `types.rkt` alongside it. It exports `GAMES` in the original constructor format, with explicit display profiles (including `2048×1280`).
- JSON-only notes and unknown extra fields are not representable in the legacy format and stay in JSON. Keep JSON as the master library.
- Exporting does not install a backend, alter the open library or change which file the updated backend reads. The updated backend reads the selected/default JSON first; only an absent default JSON falls back to legacy `games.rkt`.

**Use Default / Usar padrão** under Live Wine environment changes only the selected path to `~/bin/libexec/wine_env.sh`. It never restores or modifies the script's contents.

## Test order on your Mac

1. Build successfully, open the editor, check Portuguese labels and inspect the live library without editing it.
2. Export `games.rkt` to a new temporary destination; inspect it, keeping installed scripts untouched.
3. Grant Accessibility to the editor. Enable native input and check the game's coordinates against its selected logical resolution. Keep other automatic cursor hiders disabled for the first native test to avoid confounding the result.
4. Launch a noncritical game. Confirm focus, cursor behavior on movement and normal completion. Inspect the log for all four `Native input:` actions or a specific refusal.
5. Test Cancel during the initial delay (no later clicks), then after hiding (cursor restored, backend cleanup completes, then display restoration). Do not test Cancel with unsaved game progress.
6. After the editor works, re-create one exported launcher with native input enabled. Grant its own permission as needed; test normal completion and Cancel before re-creating the rest.

Available portable checks pass, but **actual 0.4.0 Swift compilation/XCTest, GUI layout, TCC attribution and game click delivery remain Mac-only checks**. The standalone cursor observation is not evidence that global clicks work in every Wine game.
