#!/usr/bin/env python3
"""Portable checks; never posts input, changes a display or launches a game."""
from pathlib import Path
import json
import os
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'GameLauncherApp'


def catalog(language):
    path = APP / 'Sources/LauncherCore/Resources' / (language + '.lproj') / 'Localizable.strings'
    values = {}
    for line in path.read_text().splitlines():
        if line.startswith('/*') or not line.strip(): continue
        match = re.fullmatch(r'("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");', line)
        assert match, line
        key, value = map(json.loads, match.groups())
        assert key not in values, key
        values[key] = value
    return values


def localization():
    en, pt = catalog('en'), catalog('pt-BR')
    assert en.keys() == pt.keys()
    for key in en:
        assert en[key] == key
        assert re.findall(r'%(?:@|%)', key) == re.findall(r'%(?:@|%)', pt[key]), key
    assert pt['Ready'] == 'Pronto' and pt['Running: %@'] == 'Em execução: %@'
    assert 'L10n.copyResources(to: resources)' in (APP / 'Sources/LauncherCore/StandaloneLauncher.swift').read_text()
    assert 'GameLauncher_LauncherCore.bundle' in (APP / 'build-macos.sh').read_text()
    print('PASS: both localization catalogs,', len(en), 'keys, placeholders and resource-copy wiring')
    try:
        from tree_sitter import Language, Parser
        import tree_sitter_swift
    except ImportError:
        print('SKIP: optional Swift parser coverage check'); return
    parser = Parser(Language(tree_sitter_swift.language()))
    used = set()
    for file in (APP / 'Sources').rglob('*.swift'):
        data = file.read_bytes(); tree = parser.parse(data)
        assert not tree.root_node.has_error, file
        def walk(node):
            if node.type == 'call_expression':
                # Only the direct L(argument) call, not enclosing call chains.
                children = node.named_children
                if children and children[0].type == 'simple_identifier' and data[children[0].start_byte:children[0].end_byte] == b'L':
                    suffix = next((c for c in children if c.type == 'call_suffix'), None)
                    if suffix:
                        def find_literal(n):
                            if n.type == 'line_string_literal': return n
                            for c in n.named_children:
                                found = find_literal(c)
                                if found: return found
                        literal = find_literal(suffix)
                        if literal:
                            parts = []
                            for c in literal.children:
                                raw = data[c.start_byte:c.end_byte].decode()
                                if c.type == 'line_str_text': parts.append(raw.replace('%', '%%'))
                                elif c.type == 'interpolated_expression': parts.append('%@')
                                elif c.type == 'str_escaped_char': parts.append(json.loads('"' + raw + '"').replace('%', '%%'))
                            used.add(''.join(parts))
            for child in node.children: walk(child)
        walk(tree.root_node)
    assert used <= en.keys(), sorted(used - en.keys())
    # Data keys and shortcuts must never be replaced with translated strings.
    for file in (APP / 'Sources').rglob('*.swift'):
        source = file.read_text()
        assert not re.search(r'keyboardShortcut\(L\(', source), file
        assert not re.search(r'(?:==|tag\()\s*L\("(?:off|custom|steam-wine|direct)"', source), file
    print('PASS: Swift syntax and localization coverage for', len(used), 'actual source keys (not compilation)')


def protocol():
    module = ROOT / 'game-launcher/focus.rkt'
    expression = '(begin (require (file ' + json.dumps(str(module)) + ')) (click "12,34") (click "12,34") (hide-cursor) (click "12,34"))'
    command = ['racket', '-e', expression]
    subprocess.run(['raco', 'make', str(module)], check=True)
    for mode in ['success', 'negative', 'cancel', 'timeout', 'stale-reply']:
        with tempfile.TemporaryDirectory(prefix='input-protocol-') as temporary:
            folder = Path(temporary)
            env = os.environ.copy()
            env['GAME_LAUNCHER_NATIVE_INPUT'] = json.dumps({'directory': temporary, 'token': 'fixture-token'})
            child = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            seen = []
            deadline = time.monotonic() + 9
            try:
                while child.poll() is None and time.monotonic() < deadline:
                    path = folder / 'request.json'
                    if path.exists():
                        req = json.loads(path.read_text())
                        sequence = req['sequence']
                        if sequence not in [row['sequence'] for row in seen]:
                            seen.append(req)
                            assert req['token'] == 'fixture-token'
                            assert req['createdAt'] > time.time() - 3
                            if mode == 'cancel': (folder / 'cancelled').touch()
                            elif mode != 'timeout':
                                reply = {'sequence': sequence if mode != 'stale-reply' else 0,
                                         'ok': mode != 'negative', 'error': 'fixture refusal'}
                                tmp = folder / 'reply.tmp'; tmp.write_text(json.dumps(reply))
                                tmp.replace(folder / 'response.json')
                    time.sleep(.01)
                stdout, stderr = child.communicate(timeout=1)
            finally:
                if child.poll() is None: child.kill(); child.wait()
            if mode == 'success':
                assert child.returncode == 0, stderr
                assert [r['action'] for r in seen] == ['click', 'click', 'hide', 'click']
                assert [r['sequence'] for r in seen] == [1, 2, 3, 4]
                assert seen[2]['coords'] is None
            else:
                assert child.returncode != 0 and len(seen) == 1, (mode, stderr, seen)
                if mode in ['timeout', 'stale-reply']: assert (folder / 'cancelled').exists()
            print('PASS: actual Racket focus bridge —', mode)
    env = os.environ.copy(); env['GAME_LAUNCHER_NATIVE_INPUT'] = 'invalid owner'
    result = subprocess.run(command, env=env, capture_output=True, timeout=5)
    assert result.returncode != 0
    print('PASS: malformed owner rejected, no legacy fallback')


def export():
    with tempfile.TemporaryDirectory(prefix='racket-export-cli-') as tmp:
        folder = Path(tmp); output = folder / 'games.rkt'
        env = os.environ.copy()
        fixture = json.loads((ROOT / 'game-launcher/games.seed.json').read_text())
        fixture['games'][0]['displayMode'] = '2048x1280'
        library = folder / 'games.json'; library.write_text(json.dumps(fixture))
        env['GAME_LAUNCHER_LIBRARY'] = str(library)
        env['GAME_LAUNCHER_SCRIPT'] = str(ROOT / 'game-launcher/main.rkt')
        # A read-only action must ignore native-input ownership entirely.
        env['GAME_LAUNCHER_NATIVE_INPUT'] = 'deliberately invalid'
        command = ['sh', str(ROOT / 'play'), '--export-racket', str(output)]
        subprocess.run(command, env=env, check=True, capture_output=True, timeout=30)
        before = output.read_bytes()
        assert b'(provide GAMES)' in before and b'2048 1280' in before
        retry = subprocess.run(command, env=env, capture_output=True, timeout=30)
        assert retry.returncode != 0 and output.read_bytes() == before
        print('PASS: read-only CLI games.rkt export and overwrite refusal')


if __name__ == '__main__':
    localization(); protocol(); export()
    print('Mac Swift compilation/XCTest, TCC, UI layout and actual game clicks still require a Mac.')
