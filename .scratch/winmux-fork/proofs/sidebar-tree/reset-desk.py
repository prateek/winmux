#!/usr/bin/env python3
"""Restage the same fourteen managed windows without reopening their apps."""
import json
import os
from pathlib import Path
import subprocess
import time

home = Path.home()
out = home / 'takes/sidebar-tree'
cli = Path(os.environ.get('WINMUX_CLI', str(home / 'winmux/.build/debug/winmux')))
fixture = os.environ.get('SIDEBAR_FIXTURE', 'original')
records = [line.split('|') for line in (out / f'{fixture}.windows.txt').read_text().splitlines()]


def command(*args, allow_failure=False, allow_noop=False):
    result = subprocess.run([str(cli), *map(str, args)], capture_output=True, text=True)
    noop = allow_noop and result.returncode == 1 and not result.stdout and not result.stderr
    if result.returncode and not allow_failure and not noop:
        raise RuntimeError((args, result.stdout, result.stderr))
    return result.stdout


for window, app, title, workspace, layout in records:
    command('move-node-to-workspace', '--window-id', window, workspace)
    command('layout', 'floating' if layout == 'floating' else 'tiling', '--window-id', window, allow_noop=True)

for workspace in ['2', '3']:
    columns = json.loads((out / f'{fixture}.columns-{workspace}.json').read_text())
    for column in columns:
        for window in column['window-ids']:
            command('move-node-to-column', column['index'], '--window-id', window)

zed = next(row[0] for row in records if row[1] == 'Zed')
ghosts = [row[0] for row in records if row[1] == 'Ghostty']
command('flatten-workspace-tree', '--workspace', '1')
command('layout', 'h_tiles', '--window-id', zed, allow_noop=True)
for _ in range(3):
    command('move', 'left', '--window-id', zed, '--boundaries-action', 'stop', allow_failure=True)
    command('move', 'right', '--window-id', ghosts[-1], '--boundaries-action', 'stop', allow_failure=True)
command('join-with', 'left', '--window-id', ghosts[-1])
for group in json.loads((out / f'{fixture}.agent.json').read_text())['inventory']['tabGroups']:
    for window in group['tabs']:
        command('focus', '--window-id', window)
        time.sleep(.8)
    command('focus', '--window-id', group['activeWindowId'])
    time.sleep(.8)
command('workspace', '1')
command('focus', '--window-id', zed)
time.sleep(4)
actual = command('list-windows', '--all', '--format', '%{window-id}|%{app-name}|%{window-title}|%{workspace}|%{window-layout}')
(out / 'restaged.windows.txt').write_text(actual)
assert sorted(actual.splitlines()) == sorted('|'.join(row) for row in records), actual
print('Restaged all fourteen windows with original workspace/layout inventory')
