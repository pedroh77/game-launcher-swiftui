#!/usr/bin/env python3
"""Isolated helper/adapter tests. Compiles a fake wineserver; never runs Wine.
Requires a C compiler (the Mac's Command Line Tools suffice).
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CLEANUP = ROOT / "game-launcher/wine-cleanup.sh"
ADAPTER = ROOT / "game-launcher/wine-launch.sh"


def main():
    cc = shutil.which("cc")
    assert cc, "C compiler required for a non-shell fake wineserver (avoids macOS SIP shell environment filtering)"
    with tempfile.TemporaryDirectory(prefix="wine-fixtures-") as directory:
        home = Path(directory)
        env = os.environ.copy()
        for key in list(env):
            if key.startswith(("DYLD_", "WINE", "GAME_LAUNCHER_", "ROSETTA_")):
                env.pop(key)
        log = home / "calls"
        env.update(HOME=str(home), TEST_CALLS=str(log))
        source = home / "fake.c"
        source.write_text(r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
int main(int argc, char **argv) {
    const char *path = getenv("TEST_CALLS");
    if (!path) return 80;
    FILE *out = fopen(path, "a"); if (!out) return 81;
    const char *keys[] = {"WINEPREFIX", "DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH",
                         "WRAPPER", "RENDERER", "FUTURE_VARIABLE", "WINEDLLOVERRIDES", NULL};
    fprintf(out, "CALL=%s\n", argv[0]);
    for (int i=0; keys[i]; i++) fprintf(out, "%s=%s\n", keys[i], getenv(keys[i]) ? getenv(keys[i]) : "");
    for (int i=1; i<argc; i++) fprintf(out, "ARG=%s\n", argv[i]);
    fclose(out);
    int is_kill = argc > 1 && !strcmp(argv[1], "-k");
    int is_wait = argc > 1 && !strcmp(argv[1], "-w");
    if (!is_kill && !is_wait) {
        puts("fake-wine-version");
        fputs("FAKE-WINE-STDERR\n", stderr);
    }
    const char *diagnostic = getenv(is_wait ? "TEST_WAIT_DIAGNOSTIC" : "TEST_KILL_DIAGNOSTIC");
    if (diagnostic && *diagnostic) fprintf(stderr, "%s\n", diagnostic);
    if (is_wait && getenv("TEST_WAIT_IGNORE_TERM")) signal(SIGTERM, SIG_IGN);
    if (is_wait && getenv("TEST_WAIT_PID_FILE")) {
        FILE *pid = fopen(getenv("TEST_WAIT_PID_FILE"), "w");
        if (!pid) return 82;
        fprintf(pid, "%ld\n", (long)getpid()); fclose(pid);
    }
    if (is_wait && getenv("TEST_WAIT_MS")) usleep(atoi(getenv("TEST_WAIT_MS")) * 1000);
    const char *result = getenv(is_wait ? "TEST_WAIT_RESULT" : "TEST_KILL_RESULT");
    if ((is_kill || is_wait) && result) return atoi(result);
    return getenv("TEST_RESULT") ? atoi(getenv("TEST_RESULT")) : 0;
}
''')
        binary = home / "fake-wineserver"
        subprocess.run([cc, str(source), "-o", str(binary)], check=True)

        def wrapper(name):
            contents = home / "Applications" / (name + ".app") / "Contents"
            for relative in ["Frameworks", "SharedSupport/wine/bin", "SharedSupport/prefix"]:
                (contents / relative).mkdir(parents=True)
            (contents / "Frameworks/libinotify.0.dylib").write_bytes(b"fake dylib fixture, not Mach-O")
            for name in ["wine", "wineserver"]:
                shutil.copy2(binary, contents / "SharedSupport/wine/bin" / name)
            return contents

        dxvk = wrapper("Steam_DXVK")
        sk = wrapper("Steam_SK")
        # Reproduce the old guard bug: support copy exists, wine/lib copy doesn't.
        (sk / "SharedSupport/libinotify.0.dylib").write_bytes(b"keep existing copy")

        def run(program, args=(), expected=0, extra=None):
            effective = dict(env, **(extra or {}))
            result = subprocess.run([str(program), *map(str, args)], env=effective,
                                    capture_output=True, text=True, timeout=20)
            assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
            return result

        before = sorted(str(p) for p in home.rglob("*"))
        run(CLEANUP, ["--check"])
        assert not log.exists() and before == sorted(str(p) for p in home.rglob("*"))
        print("PASS: --check never copies or invokes wineserver")
        run(CLEANUP)
        calls = log.read_text()
        assert calls.count("ARG=-k\n") == 2
        for contents in [dxvk, sk]:
            assert (contents / "SharedSupport/wine/lib/libinotify.0.dylib").read_bytes().startswith(b"fake dylib")
            assert f"WINEPREFIX={contents}/SharedSupport/prefix\n" in calls
            assert f"DYLD_LIBRARY_PATH={contents}/Frameworks:" in calls
        assert (sk / "SharedSupport/libinotify.0.dylib").read_bytes() == b"keep existing copy"
        print("PASS: both copies repaired independently; existing copy retained; per-wrapper DYLD and prefix reach binary")
        log.write_text("")
        run(CLEANUP, ["Steam_DXVK.app"], expected=1, extra={"TEST_RESULT": "9"})
        assert log.read_text().count("ARG=-k") == 1
        log.write_text("")
        run(CLEANUP, expected=1, extra={"TEST_RESULT": "134"})
        assert log.read_text().count("ARG=-k") == 2
        print("PASS: nonzero/abort-like results propagate; failure of first wrapper does not skip the second")
        # A quiet exit 1 is expected when both prefixes are already idle.
        log.write_text("")
        idle = {"TEST_KILL_RESULT": "1", "TEST_WAIT_RESULT": "0"}
        result = run(CLEANUP, extra=idle)
        assert result.stdout.count("Already stopped:") == 2 and "ERROR:" not in result.stderr
        assert log.read_text().count("ARG=-w") == 2
        print("PASS: empty prefixes return success only after a quiet same-prefix wait check")
        log.write_text("")
        result = run(CLEANUP, ["Steam_SK"], expected=1,
                     extra=dict(idle, TEST_KILL_DIAGNOSTIC="wineserver: permission denied"))
        assert "permission denied" in result.stdout and "ARG=-w" not in log.read_text()
        run(CLEANUP, ["Steam_SK"], expected=1, extra=dict(idle, TEST_WAIT_RESULT="1"))
        result = run(CLEANUP, ["Steam_SK"], expected=1,
                     extra=dict(idle, TEST_WAIT_DIAGNOSTIC="wait diagnostic"))
        assert "wait diagnostic" in result.stdout
        run(CLEANUP, ["Steam_SK"], expected=1, extra={"TEST_RESULT": "1"})
        print("PASS: noisy exit 1, failed/noisy wait, and generic exit 1 are not silently accepted")
        wait_pid_file = home / "wait-pid"
        result = run(CLEANUP, ["Steam_SK"], expected=1,
                     extra=dict(idle, TEST_WAIT_MS="10000", TEST_WAIT_PID_FILE=str(wait_pid_file)))
        assert "did not finish within 2s" in result.stderr
        wait_pid = int(wait_pid_file.read_text())
        try:
            os.kill(wait_pid, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("Timed-out -w child was left running")
        run(CLEANUP, ["Steam_SK"], expected=1,
            extra=dict(idle, TEST_WAIT_MS="10000", TEST_WAIT_PID_FILE=str(wait_pid_file), TEST_WAIT_IGNORE_TERM="1"))
        try:
            os.kill(int(wait_pid_file.read_text()), 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("Uncooperative wait child was left running")
        print("PASS: active/blocked prefix remains a failure; only the owned wait child is stopped and reaped")
        quoted = wrapper("Game's Other Wrapper")
        run(CLEANUP, [str(quoted.parent) + "/"])
        run(CLEANUP, [quoted])
        run(CLEANUP, ["does-not-exist"], expected=1)
        (quoted / "Frameworks/libinotify.0.dylib").unlink()
        (quoted / "SharedSupport/libinotify.0.dylib").unlink()
        (quoted / "SharedSupport/wine/lib/libinotify.0.dylib").unlink()
        run(CLEANUP, [quoted], expected=1)
        (quoted / "Frameworks/libinotify.0.dylib").write_bytes(b"fixture")
        (quoted / "SharedSupport/wine/lib/libinotify.0.dylib").symlink_to(home / "missing-target")
        run(CLEANUP, [quoted], expected=1)
        assert not (home / "missing-target").exists()
        print("PASS: named/absolute/spaced paths, missing files, and dangling destination symlink")

        live = home / "live config's environment.sh"
        loader = home / "chosen runtime loader"
        loader.write_text('#!/bin/sh\necho ROSETTA >> "$TEST_CALLS"\necho FAKE-ROSETTA-STDERR >&2\nexec "$@"\n')
        loader.chmod(0o755)
        def environment(version):
            live.write_text('export WINE_BIN="$WRAPPER/SharedSupport/wine/bin/wine"\n'
                            'export WINEPREFIX="$WRAPPER/SharedSupport/prefix"\n'
                            'export RUNTIME_LOADER="$TEST_LOADER"\n'
                            f'export FUTURE_VARIABLE="{version}"\n'
                            'echo ENVIRONMENT-STATUS\n')
        environment("first")
        adapter_env = {"WRAPPER": str(sk), "RENDERER": "dxvk", "WINEDLLOVERRIDES": "abc=n,b",
                       "GAME_LAUNCHER_WINE_ENV": str(live), "GAME_LAUNCHER_USE_ROSETTA": "1",
                       "TEST_LOADER": str(loader)}
        log.write_text("")
        result = run(ADAPTER, ["--version", "space and 'quote'", "$not-expanded"], extra=adapter_env)
        assert result.stdout == "fake-wine-version\n" and "ENVIRONMENT-STATUS" in result.stderr
        assert "FAKE-WINE-STDERR" not in result.stderr, result.stderr
        assert "FAKE-ROSETTA-STDERR" not in result.stderr, result.stderr
        calls = log.read_text()
        for text in ["ROSETTA", "FUTURE_VARIABLE=first", "RENDERER=dxvk", "WINEDLLOVERRIDES=abc=n,b",
                     "ARG=space and 'quote'", "ARG=$not-expanded"]:
            assert text in calls, calls
        for rosetta in ["0", "1"]:
            quiet = run(ADAPTER, ["fixture-game.exe"],
                        extra=dict(adapter_env, GAME_LAUNCHER_USE_ROSETTA=rosetta))
            # stdout remains usable for store-tool data queries. The runners
            # already suppress launch stdout; only Wine/loader stderr was leaking.
            assert quiet.stdout == "fake-wine-version\n"
            assert quiet.stderr == "ENVIRONMENT-STATUS\n", quiet.stderr
            probe = run(ADAPTER, ["--version"],
                        extra=dict(adapter_env, GAME_LAUNCHER_USE_ROSETTA=rosetta))
            assert probe.stdout == "fake-wine-version\n"
            assert probe.stderr == "ENVIRONMENT-STATUS\n", probe.stderr
        print("PASS: Wine/Rosetta stderr is quiet; live-script statuses and probe stdout remain intact")
        environment("edited-live")
        log.write_text("")
        adapter_env["GAME_LAUNCHER_USE_ROSETTA"] = "0"
        run(ADAPTER, extra=adapter_env)
        assert "FUTURE_VARIABLE=edited-live" in log.read_text() and "ROSETTA" not in log.read_text()
        run(ADAPTER, expected=9, extra=dict(adapter_env, TEST_RESULT="9"))
        missing = run(ADAPTER, expected=66,
                      extra=dict(adapter_env, GAME_LAUNCHER_WINE_ENV=str(home / "missing")))
        assert "ERROR: Wine environment file is not readable" in missing.stderr
        live.write_text('return 1\n')
        run(ADAPTER, expected=70, extra=adapter_env)
        environment("restored")
        run(ADAPTER, expected=69, extra=dict(adapter_env, GAME_LAUNCHER_USE_ROSETTA="1", TEST_LOADER=str(home / "absent")))
        print("PASS: live edits, custom env/loader paths, Rosetta toggle, argv, stdout, errors and Wine exit status")

        # Real Racket command construction/setup, but only fake Wine binaries.
        racket = shutil.which("racket")
        assert racket
        def rq(value):
            import json
            return json.dumps(str(value))
        driver = home / "adapter-test.rkt"
        driver.write_text(f'''#lang racket
(require racket/system (file {rq(ROOT / 'game-launcher/wine.rkt')}))
(setup-wine-environment {rq(sk)} "dxvk" "xyz=n" #f)
(unless (system (string-append (build-wine-invocation {rq(sk)} "dxvk" "xyz=n" #f) " 'argument with spaces'")) (exit 1))
''')
        log.write_text("")
        run(racket, [driver], extra=adapter_env)
        assert "ARG=argument with spaces" in log.read_text() and "WINEDLLOVERRIDES=xyz=n" in log.read_text()
        # Exercise all actual game-record symbol types, retaining string callers.
        driver.write_text(f'''#lang racket
(require racket/system (file {rq(ROOT / 'game-launcher/wine.rkt')}))
(for* ([name '(d3dmetal dxvk dxmt mtld3d d9mt none)] [symbol-input? '(#t #f)])
  (define renderer (if symbol-input? name (symbol->string name)))
  (setup-wine-environment {rq(sk)} renderer "xyz=n" #f)
  (unless (system (string-append (build-wine-invocation {rq(sk)} renderer "xyz=n" #f)
                                " renderer-boundary")) (exit 1)))
''')
        log.write_text("")
        run(racket, [driver], extra=adapter_env)
        calls = log.read_text()
        assert calls.count("ARG=renderer-boundary\n") == 12
        for renderer in ["d3dmetal", "dxvk", "dxmt", "mtld3d", "d9mt", "none"]:
            assert calls.count(f"RENDERER={renderer}\n") == 2, calls
        print("PASS: all six supported renderers reach fake Wine as both record symbols and strings")
        # The embedded adapter path can contain app-name quotes/$ characters.
        # Check both direct command construction and the Heroic --wine argument.
        bundled = home / "Bundle's $literal adapters"
        bundled.mkdir()
        for name in ["wine.rkt", "config.rkt", "wine-launch.sh", "wine-cleanup.sh"]:
            shutil.copy2(ROOT / "game-launcher" / name, bundled / name)
        driver.write_text(f'''#lang racket
(require racket/system (file {rq(bundled / 'wine.rkt')}))
(setup-wine-environment {rq(sk)} "dxvk" #f #f)
(unless (system (string-append (build-wine-invocation {rq(sk)} "dxvk" #f #f) " --version")) (exit 1))
(displayln wine-launch-argument)
''')
        result = run(racket, [driver], extra=adapter_env)
        import shlex
        assert shlex.split(result.stdout.splitlines()[-1]) == [str(bundled / "wine-launch.sh")]
        print("PASS: embedded adapter paths with apostrophes/$ remain one literal shell argument")
        # Normal Racket cleanup uses the bundled corrected helper for this prefix.
        driver.write_text(f'#lang racket\n(require (file {rq(ROOT / "game-launcher/wine.rkt")}))\n(cleanup-wine {rq(sk)})\n')
        log.write_text("")
        run(racket, [driver])
        assert log.read_text().count("ARG=-k") == 1
        log.write_text("")
        run(racket, [driver], extra=idle)
        assert log.read_text().count("ARG=-w") == 1
        print("PASS: actual Racket invocation and targeted cleanup handle both successful and already-stopped sessions")
        # Real JSON decoder, game records, runner code, Wine adapter and cleanup.
        # Only focus/process monitoring and store tools are stubbed. Never invoke
        # main.rkt/display management, real Heroic/comet, or a host Wine wrapper.
        runner_backend = home / "isolated runner backend"
        runner_backend.mkdir()
        for name in ["library.rkt", "types.rkt", "wine.rkt", "config.rkt", "wine-launch.sh", "wine-cleanup.sh"]:
            shutil.copy2(ROOT / "game-launcher" / name, runner_backend / name)
        shutil.copytree(ROOT / "game-launcher/runners", runner_backend / "runners",
                        ignore=shutil.ignore_patterns("compiled", ".DS_Store"))
        (runner_backend / "focus.rkt").write_text('''#lang racket
(provide start-focus-thread wait-for-process wait-for-process-exit)
(define (record label)
  (call-with-output-file (getenv "TEST_CALLS")
    (lambda (out) (fprintf out "~a\n" label)) #:exists 'append))
(define (start-focus-thread . args) (record "FOCUS-STUB"))
(define (wait-for-process name) (record (string-append "WAIT-STUB=" name)))
(define (wait-for-process-exit name) (record (string-append "EXIT-STUB=" name)))
''')
        store_bin = home / "fake store tools"
        store_bin.mkdir()
        config = runner_backend / "config.rkt"
        text = config.read_text()
        original_store = '"/Applications/Heroic.app/Contents/Resources/app.asar.unpacked/build/bin/arm64/darwin"'
        assert text.count(original_store) == 1
        config.write_text(text.replace(original_store, rq(store_bin), 1))
        for name in ["legendary", "gogdl", "nile"]:
            tool = store_bin / name
            tool.write_text('''#!/bin/sh
printf 'STORE-STUB=%s\n' "${0##*/}" >> "$TEST_CALLS"
printf 'STORE-PROGRESS=%s\n' "${0##*/}" >&2
adapter=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = --wine ]; then adapter="$2"; shift 2; else shift; fi
done
# A save-sync request is logged only: no network/file access.
[ -n "$adapter" ] || exit 0
exec "$adapter" fixture-store-game.exe
''')
            tool.chmod(0o755)
        guards = home / "bin"
        guards.mkdir(exist_ok=True)
        for name in ["which", "comet", "pkill"]:
            guard = guards / name
            guard.write_text("#!/bin/sh\nexit 1\n")
            guard.chmod(0o755)
        # Exercise PowerShell's space-containing path as one Wine argument.
        pwsh = sk / "SharedSupport/prefix/drive_c/Program Files/PowerShell/7/pwsh.exe"
        pwsh.parent.mkdir(parents=True)
        pwsh.write_text("fixture, not executable")
        runner_env = {"GAME_LAUNCHER_WINE_ENV": str(live), "TEST_LOADER": str(loader),
                      "PATH": str(guards) + os.pathsep + os.environ.get("PATH", "/usr/bin:/bin"),
                      "TEST_KILL_RESULT": "1", "TEST_WAIT_RESULT": "0"}
        cases = [("endermagnolia", "steam-wine", "run-steam-wine", "d3dmetal"),
                 ("am2r", "direct", "run-direct", "dxvk"),
                 ("beaconpines", "epic", "run-epic-wine", "dxmt"),
                 ("bo", "gog", "run-gog-wine", "d3dmetal"),
                 ("dexterstardust", "amazon", "run-amazon", "d3dmetal")]
        for alias, module, entry, renderer in cases:
            driver.write_text(f'''#lang racket
(require (file {rq(runner_backend / 'library.rkt')})
         (file {rq(runner_backend / 'runners' / (module + '.rkt'))}))
(define original (hash-ref (read-library {rq(ROOT / 'game-launcher/games.seed.json')}) '{alias}))
(unless (symbol? (game-renderer original)) (error 'fixture "Record renderer must be a symbol"))
(define g (struct-copy game-record original [wrapper {rq(sk)}]))
({entry} g)
''')
            log.write_text("")
            result = run(racket, [driver], extra=runner_env)
            calls = log.read_text()
            assert f"RENDERER={renderer}\n" in calls
            assert calls.count(f"CALL={sk}/SharedSupport/wine/bin/wine\n") == 1, calls
            assert calls.count("ARG=-k\n") == 1 and calls.count("ARG=-w\n") == 1, calls
            assert "FOCUS-STUB" in calls and "ROSETTA" in calls
            assert "Already stopped:" in result.stdout
            # Real runners must hide both Wine streams while keeping host script
            # progress and existing store-tool stderr visible (not a GUI filter).
            assert "Lançando" in result.stdout and "ENVIRONMENT-STATUS" in result.stderr
            for noise in ["fake-wine-version", "FAKE-WINE-STDERR", "FAKE-ROSETTA-STDERR"]:
                assert noise not in result.stdout + result.stderr, (module, result)
            store = {"epic": "legendary", "gog": "gogdl", "amazon": "nile"}.get(module)
            if store:
                assert f"STORE-PROGRESS={store}" in result.stderr, result.stderr
            if module == "steam-wine":
                for arg in ["start", "C:/Program Files/PowerShell/7/pwsh.exe",
                            "C:/Scripts/steam_runner.ps1", "-AppId", "2725260",
                            "-ProcessName", "EnderMagnoliaSteam-Win64-Shipping.exe"]:
                    assert f"ARG={arg}\n" in calls, calls
                assert "WAIT-STUB=steam.exe" in calls and "EXIT-STUB=steam.exe" in calls
                log.write_text("")
                failed = run(racket, [driver], expected=1, extra=dict(runner_env, TEST_RESULT="9"))
                assert "Wine adapter failed" in failed.stderr
                assert "Already stopped:" in failed.stdout
                assert "FAKE-WINE-STDERR" not in failed.stderr
                assert "FAKE-ROSETTA-STDERR" not in failed.stderr
                assert log.read_text().count("ARG=-w\n") == 1
            print(f"PASS: real {module} runner / {alias}: quiet Wine, visible progress, {renderer} and cleanup")
        print("PASS: isolated Wine fixtures completed; no real Wine, dyld loading, or user wrappers were exercised")


if __name__ == "__main__":
    main()
