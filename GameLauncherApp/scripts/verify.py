#!/usr/bin/env python3
"""Portable checks. No games, Wine, clicks, display changes or cleanup are run."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent
BACKEND = ROOT / "game-launcher"


def run(args, *, env=None, expected=0):
    result = subprocess.run([str(x) for x in args], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
    if result.returncode != expected:
        raise AssertionError(f"{args}: exit {result.returncode}, expected {expected}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--swift-syntax", action="store_true",
                        help="Also parse Swift using tree-sitter; NOT Swift type checking.")
    args = parser.parse_args()
    # Targeted source guard: Foundation/XCTest transitive imports do not guarantee
    # the CoreGraphics Swift geometry overlay. This is NOT Swift type checking.
    for relative in ["Sources/LauncherCore/StandaloneLauncher.swift",
                     "Tests/LauncherCoreTests/StandaloneLauncherTests.swift"]:
        assert "import CoreGraphics" in (APP / relative).read_text().splitlines(), relative
    print("PASS: explicit CoreGraphics imports in window geometry source and tests (source check only)")
    runner = (APP / "Sources/GameRunner/GameRunner.swift").read_text()
    assert runner.index("NotificationCenter.default.addObserver") < runner.index("try launcher.start"), "Register before native switching"
    assert "defer { scheduleAnchorWindow() }" in runner, "Refresh placement after synchronous launch/switch"
    assert "for delay in [0.0, 0.1, 0.5, 1.0]" in runner and "self.anchorGeneration == generation" in runner
    print("PASS: early screen observer, bounded deferred placement, and preserved centering (source checks only)")
    racket = shutil.which("racket")
    raco = shutil.which("raco")
    if not racket or not raco:
        raise SystemExit("Install Racket first. A full installation includes raco make/test and RackUnit.")
    env = os.environ.copy()
    env["GAME_LAUNCHER_LIBRARY"] = str(BACKEND / "games.seed.json")
    env["GAME_LAUNCHER_SCRIPT"] = str(BACKEND / "main.rkt")
    env["GAME_LAUNCHER_RACKET"] = racket
    sources = sorted(BACKEND.glob("*.rkt")) + sorted((BACKEND / "runners").glob("*.rkt"))
    run([raco, "make", *sources])
    print("PASS: compiled Racket backend modules")
    print(run([raco, "test", *sorted((BACKEND / "tests").glob("*-test.rkt"))]).strip())

    seed_bytes = (BACKEND / "games.seed.json").read_bytes()
    seed = json.loads(seed_bytes)
    assert len(seed["games"]) == 118
    listed = run(["/bin/sh", ROOT / "play", "--list"], env=env)
    assert "Total: 118" in listed
    for game in seed["games"]:
        info = run([racket, BACKEND / "main.rkt", "--info", game["alias"]], env=env)
        assert game["title"] in info, game["alias"]
    print("PASS: play --list and --info for all 118 entries (no launches)")

    with tempfile.TemporaryDirectory(prefix="launcher-verification-") as temp:
        temp = Path(temp)
        # An isolated HOME avoids reading or writing a real user library.
        isolated = env.copy()
        isolated["HOME"] = str(temp)
        isolated.pop("GAME_LAUNCHER_LIBRARY")
        assert "Total: 118" in run([racket, BACKEND / "main.rkt", "--list"], env=isolated)
        default = temp / "Library/Application Support/Game Launcher/games.json"
        default.parent.mkdir(parents=True)
        default.write_text(json.dumps({"schemaVersion": 1, "games": seed["games"][:1]}))
        assert "Total: 1 jogos" in run([racket, BACKEND / "main.rkt", "--list"], env=isolated)
        isolated["GAME_LAUNCHER_LIBRARY"] = str(temp / "missing.json")
        run([racket, BACKEND / "main.rkt", "--list"], env=isolated, expected=1)
        print("PASS: legacy fallback, default shared library, missing explicit path")

        exported = temp / "export.json"
        run([racket, BACKEND / "export-library.rkt", exported])
        assert json.loads(exported.read_bytes()) == seed
        run([racket, BACKEND / "export-library.rkt", exported], expected=1)
        assert json.loads(exported.read_bytes()) == seed
        print("PASS: exporter matches seed and refuses to overwrite")

        profile_game = dict(seed["games"][0], displayMode="2048x1280")
        profile_library = temp / "2048-profile.json"
        profile_library.write_text(json.dumps({"schemaVersion": 1, "games": [profile_game]}))
        profile_env = env.copy()
        profile_env["GAME_LAUNCHER_LIBRARY"] = str(profile_library)
        info = run(["/bin/sh", ROOT / "play", "--info", profile_game["alias"]], env=profile_env)
        assert "2048x1280 @ escala 1, mouse 2x" in info
        print("PASS: 2048x1280 profile loads through play --info with scale 1 and pointer 2x")

        # Exercise play's normal supervisor path with a harmless fake Racket entry.
        # No signal is sent, so the legacy cleanup is never invoked.
        fake = temp / "mock entry.rkt"
        fake.write_text('#lang racket\n(displayln "mock backend reached")\n(exit 7)\n')
        mocked = env.copy()
        mocked["GAME_LAUNCHER_SCRIPT"] = str(fake)
        output = run(["/bin/sh", ROOT / "play", "test-alias"], env=mocked, expected=7)
        assert "mock backend reached" in output and "Cancelamento" not in output
        print("PASS: play passes through mock-backend output and exit code")

    for script in [ROOT / "play", APP / "prepare-resources.sh", APP / "build-macos.sh", APP / "test-native-display.sh", BACKEND / "wine-launch.sh", BACKEND / "wine-cleanup.sh"]:
        run(["/bin/sh", "-n", script])
    plist = plistlib.loads((APP / "Info.plist").read_bytes())
    assert plist["LSMinimumSystemVersion"] == "13.0"
    assert plist.get("CFBundleIconFile") == "AppIcon"
    run(["/bin/sh", APP / "prepare-resources.sh"])
    for source in sources:
        relative = source.relative_to(BACKEND)
        assert source.read_bytes() == (APP / "Resources/Backend" / relative).read_bytes()
    for name in ["wine-launch.sh", "wine-cleanup.sh", "blackbars", "runtime_loader", "libRuntimeRosettax87"]:
        assert (BACKEND / name).read_bytes() == (APP / "Resources/Backend" / name).read_bytes()
        assert os.access(APP / "Resources/Backend" / name, os.X_OK)
    assert seed_bytes == (APP / "Resources/games.seed.json").read_bytes()
    assert (ROOT / "play").read_bytes() == (APP / "Resources/Backend/play").read_bytes()
    assert (APP / "Resources/AppIcon.icns").is_file()
    print("PASS: shell syntax, Info.plist, and all bundled resources")

    if args.swift_syntax:
        from tree_sitter import Language, Parser
        import tree_sitter_swift
        swift = Parser(Language(tree_sitter_swift.language()))
        files = [p for p in APP.rglob("*.swift") if ".build" not in p.parts]
        for path in files:
            tree = swift.parse(path.read_bytes())
            assert not tree.root_node.has_error, f"Swift syntax error in {path}"
        print(f"PASS: parsed {len(files)} Swift files; this is NOT type checking or compilation")
    print("Mac-only checks still required: Swift compilation/tests, GUI, and real game sessions.")


if __name__ == "__main__":
    main()
