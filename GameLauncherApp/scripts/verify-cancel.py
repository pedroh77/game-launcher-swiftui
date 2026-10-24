#!/usr/bin/env python3
"""Exercise play's real signal trap with isolated HOME and mocked macOS/Wine helpers.
No installed games, Wine processes, display settings or user helpers are touched.
"""
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    racket = shutil.which("racket")
    if not racket:
        raise SystemExit("Racket is required for the harmless test child.")
    with tempfile.TemporaryDirectory(prefix="launcher-cancel-test-") as temp:
        home = Path(temp)
        bin_dir = home / "bin"
        bin_dir.mkdir()
        calls = home / "helper-calls.txt"
        for name in ["killall", "pkill", "pgrep", "osascript", "defaults", "activateSettings", "kill-wine-processes.sh"]:
            body = '#!/bin/sh\nprintf "%s\\n" "' + name + ' $*" >> "$TEST_HELPER_LOG"\n'
            if name == "osascript":
                # Forces the existing 1080p skip branch, so absolute RDM/private
                # framework commands can never execute, even on a developer Mac.
                body += 'echo "0, 0, 1920, 1080"\n'
            body += 'exit 0\n'
            path = bin_dir / name
            path.write_text(body)
            path.chmod(0o755)
        child = home / "harmless.rkt"
        child.write_text('#lang racket\n(displayln "READY")\n(flush-output)\n(sync never-evt)\n')
        env = os.environ.copy()
        env.update(HOME=str(home), PATH=str(bin_dir) + os.pathsep + env.get("PATH", "/usr/bin:/bin"),
                   GAME_LAUNCHER_RACKET=racket, GAME_LAUNCHER_SCRIPT=str(child), TEST_HELPER_LOG=str(calls))
        env["GAME_LAUNCHER_ACTIVATE_SETTINGS"] = str(bin_dir / "activateSettings")
        cases = [(sig, owner) for owner in [None, "skip", "2048,1280,1"]
                 for sig in [signal.SIGTERM, signal.SIGINT, signal.SIGHUP]]
        for sig, owner in cases:
            env.pop("GAME_LAUNCHER_NATIVE_DISPLAY", None)
            if owner is not None:
                env["GAME_LAUNCHER_NATIVE_DISPLAY"] = owner
            calls.write_text("")
            proc = subprocess.Popen(["/bin/sh", str(ROOT / "play"), "mock-game"], env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                readable, _, _ = select.select([proc.stdout], [], [], 10)
                assert readable, "Test child did not start"
                assert proc.stdout.readline().strip() == b"READY"
                proc.send_signal(sig)
                output = proc.communicate(timeout=10)[0].decode("utf-8", "replace")
                assert output.count("Cancelamento solicitado") == 1, output
                log = calls.read_text()
                for action in ["killall caffeinate", "pkill -f blackbars", "kill-wine-processes.sh"]:
                    assert action in log, (sig, action, log)
                if owner is None:
                    assert "osascript" in log and "defaults" not in log and "activateSettings" not in log, log
                elif owner == "skip":
                    assert "osascript" not in log and "defaults" not in log and "activateSettings" not in log, log
                else:
                    assert "osascript" not in log, "Native Cancel must not use Finder/RDM"
                    assert log.count("defaults write NSGlobalDomain") == 2, log
                    assert "com.apple.trackpad.scaling -float 1" in log, log
                    assert "com.apple.mouse.scaling -float 1" in log, log
                    assert log.count("activateSettings -u") == 1, log
                print(f"PASS: {sig.name}, display owner {owner or 'legacy'}; one cleanup, mocked pointer restoration, no real display/Wine actions")
            finally:
                # Only the isolated process group created above; never broad pkill.
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()


if __name__ == "__main__":
    main()
