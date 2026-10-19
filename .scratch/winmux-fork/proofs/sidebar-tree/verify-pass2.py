#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])


def load(name, suffix='agent.json'):
    return json.loads((root / f'{name}.{suffix}').read_text())


def labels(name):
    return [row['description'] for row in load(name, 'ui.json')
            if row['role'] == 'AXButton' and 0 <= row['x'] < 320]


core = ['flat-before', 'flat-after', 'levels-before', 'levels-after',
        'direct-column-before', 'direct-column-after', 'group-join', 'split-source', 'floating-tiled']
subprocess.run([sys.executable, str(Path(__file__).with_name('verify-live.py')), str(root), *core], check=True)
for name in ['split-screen-cancel', 'split-new-workspace-cancel']:
    assert load(name)['reasoning']['rawTrees'] == load(name + '-start')['reasoning']['rawTrees'], name
    assert (root / f'{name}.windows.txt').read_text() == (root / f'{name}-start.windows.txt').read_text(), name
    print(name + ': unchanged trees and inventory')

queries = {
    'search-safari': (['Lenses and Search', 'Fixed Columns', 'Subscription events'], 'Workspace 2', 'Column 2 · 44%'),
    'search-grievances': (['Grievances.rtf'], 'Workspace 3', 'Column 1 · 67%'),
    'search-none': ([], None, None),
}
window_titles = {window['title'] for window in load('original')['inventory']['windows']}
for name, (expected, workspace, column) in queries.items():
    found = [label for label in labels(name) if label in window_titles]
    assert sorted(found) == sorted(expected), (name, found)
    if expected:
        assert workspace in labels(name) and column in labels(name), name
    print(f'{name}: {len(found)} windows, {workspace or "no workspace"} / {column or "no Column"}')
for name in ['clear-safari', 'clear-grievances', 'clear-none']:
    assert labels(name) == labels('both-tabs-collapsed'), name
print('Search clearing restores both disclosures')

ghost = next(window['windowId'] for window in load('native-size-remembered')['inventory']['windows']
             if window['appName'] == 'Ghostty' and window['layout'] == 'floating')
sizes = []
for name in ['native-size-remembered', 'native-size-tiled', 'native-size-restored']:
    frame = next(row['frame'] for row in load(name, 'frames.json') if row['id'] == ghost)
    sizes.append((frame['Width'], frame['Height']))
assert sizes[0] == sizes[2] == (500, 320) and sizes[1] != sizes[0], sizes
print(f'Independent native sizes: {sizes}')
assert 'Pin sidebar' in labels('scrolled-unpin')
assert 'Unpin sidebar' in labels('scrolled-repin')
calculator = next(window for window in load('scrolled-new-workspace')['inventory']['windows'] if window['appName'] == 'Calculator')
assert calculator['workspace'] == '5' and calculator['layout'] == 'floating', calculator
print('Scrolled pin/unpin and New Workspace target work')
assert load('original')['reasoning']['rawTrees'] == load('pass2-final-restored')['reasoning']['rawTrees']
assert sorted((root / 'original.windows.txt').read_text().splitlines()) == sorted((root / 'pass2-final-restored.windows.txt').read_text().splitlines())
assert load('window-row-screen')['reasoning']['rawTrees'] != load('original')['reasoning']['rawTrees']
assert len(load('window-row-screen')['inventory']['windows']) == 14
print('Window-row on-screen commit changes the layout; final reset restores all fourteen windows and four trees')
