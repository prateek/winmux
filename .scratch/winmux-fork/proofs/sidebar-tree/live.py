#!/usr/bin/env python3
"""Guest-only pointer takes and native readbacks; no source or config rewriting."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HOME = Path.home()
OUT = HOME / 'takes/sidebar-tree'
CLI = Path(os.environ.get('WINMUX_CLI', str(HOME / 'winmux/.build/debug/winmux')))
CLICK = '/opt/homebrew/bin/cliclick'


def run(*args):
    return subprocess.run([str(arg) for arg in args], check=True, text=True, capture_output=True).stdout


def capture(name):
    run('screencapture', '-x', OUT / (name + '.png'))
    pid = run('pgrep', '-x', 'WinMuxApp').strip().splitlines()[0]
    (OUT / (name + '.ui.json')).write_text(run(HOME / 'sidebar-tree-proof/ui', pid))


def find_row(label, occurrence=0):
    pid = run('pgrep', '-x', 'WinMuxApp').strip().splitlines()[0]
    rows = json.loads(run(HOME / 'sidebar-tree-proof/ui', pid))
    def matches_label(row):
        if label.startswith('@tabs:'):
            return row['role'] == 'AXButton' and row['description'].endswith(', ' + label.split(':')[1])
        return label in (row['description'], row['value'], row['title'])
    matches = [row for row in rows if row['x'] < 330 and 0 < row['height'] < 40 and matches_label(row)]
    if len(matches) <= occurrence:
        raise RuntimeError((label, occurrence, matches))
    return matches[occurrence]


def find(label, occurrence=0):
    row = find_row(label, occurrence)
    return round(row['x'] + row['width'] / 2), round(row['y'] + row['height'] / 2), row['height']


def drag(name, sx, sy, tx, ty):
    capture(name + '-before')
    run(CLICK, f'm:{sx},{sy}', 'w:350', f'dd:{sx},{sy}', 'w:300', f'dm:{sx + 7},{sy + 4}', 'w:300', f'dm:{tx},{ty}', 'w:900')
    capture(name + '-preview')
    run(CLICK, f'du:{tx},{ty}', 'w:500')
    time.sleep(2)
    capture(name + '-after')
    readback(name)


def readback(name):
    time.sleep(4)
    (OUT / (name + '.windows.txt')).write_text(run(CLI, 'list-windows', '--all', '--format',
        '%{window-id}|%{app-name}|%{window-title}|%{workspace}|%{window-layout}'))
    (OUT / (name + '.agent.json')).write_text(run(CLI, 'agent', 'query'))
    (OUT / (name + '.columns-2.json')).write_text(run(CLI, 'list-columns', '--workspace', '2', '--json'))
    (OUT / (name + '.columns-3.json')).write_text(run(CLI, 'list-columns', '--workspace', '3', '--json'))


OUT.mkdir(parents=True, exist_ok=True)
mode, name, *args = sys.argv[1:]
if mode == 'snapshot':
    capture(name)
    readback(name)
elif mode == 'drag':
    sx, sy, tx, ty = map(int, args)
    drag(name, sx, sy, tx, ty)
elif mode == 'draglabel':
    source, target, half, *occurrences = args
    source_index, target_index = list(map(int, occurrences)) if occurrences else (0, 0)
    sx, sy, _ = find(source, source_index)
    tx, ty, height = find(target, target_index)
    ty += round(height * (-.3 if half == 'before' else .3 if half == 'after' else 0))
    drag(name, sx, sy, tx, ty)
elif mode == 'draglabelpoint':
    source, tx, ty, *occurrences = args
    sx, sy, _ = find(source, int(occurrences[0]) if occurrences else 0)
    drag(name, sx, sy, int(tx), int(ty))
elif mode == 'dragmark':
    source, workspace, slot, occurrence = args
    sx, sy, _ = find(source, int(occurrence))
    cx, ty, _ = find('Show Columns', 0 if workspace == '2' else 1)
    widths = [column['width'] for column in json.loads((OUT / f'original.columns-{workspace}.json').read_text())]
    index = int(slot) - 1
    available = 45 - 2 * (len(widths) - 1)
    tx = round(cx - 92 + available * (sum(widths[:index]) + widths[index] / 2) + 2 * index)
    drag(name, sx, sy, tx, ty)
elif mode == 'disclose':
    row = find_row(args[0])
    x, y = round(row['x'] - 6), round(row['y'] + row['height'] / 2)
    run(CLICK, f'm:{x},{y}', 'w:350', f'c:{x},{y}', 'w:500')
    capture(name)
    readback(name)
elif mode in ('clicklabel', 'hoverlabel'):
    label, *occurrences = args
    x, y, _ = find(label, int(occurrences[0]) if occurrences else 0)
    run(CLICK, f'm:{x},{y}', 'w:1200' if mode == 'hoverlabel' else 'w:350')
    if mode == 'clicklabel':
        run(CLICK, f'c:{x},{y}', 'w:500')
    capture(name)
    readback(name)
elif mode == 'click':
    run(CLICK, 'c:' + args[0], 'w:500')
    capture(name)
    readback(name)
elif mode == 'readback':
    readback(name)
else:
    raise SystemExit('snapshot, drag, click or readback')
