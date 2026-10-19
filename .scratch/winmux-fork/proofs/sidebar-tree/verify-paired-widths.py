#!/usr/bin/env python3
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])


def load(name):
    return json.loads((root / name).read_text())


for name in ('before.txt', 'moved.txt', 'after.txt', 'focus.txt', 'columns-2.json'):
    assert (root / 'base-unchanged' / name).read_text() == (root / 'feature-unchanged' / name).read_text(), name
base = load('base-unchanged/layout-after.json')
feature = load('feature-unchanged/layout-after.json')
assert base['reasoning']['rawTrees'] == feature['reasoning']['rawTrees']
assert base['inventory']['windows'] == feature['inventory']['windows']
for variant in ('base', 'feature'):
    hook = load(f'{variant}-hook-preview.json')
    assert hook['column'] == 3 and hook['overflow'] == 'split' and hook['hook'] == 'workspace.2.columns.place', hook
    inventory = load(f'{variant}-hook-end.agent.json')['inventory']['windows']
    notes = next(row['windowId'] for row in inventory if row['appName'] == 'Notes')
    columns = load(f'{variant}-hook-end.columns-2.json')
    assert notes in columns[2]['window-ids'] and not columns[0]['window-ids']
    moved = load(f'{variant}-sidebar-workspace.agent.json')['inventory']['windows']
    calculator = next(row for row in moved if row['appName'] == 'Calculator')
    assert calculator['workspace'] == '1' and calculator['layout'] == 'floating'
print('Base/feature native inventory, frames, layout, focus, Columns, sidebar move and Place hook agree')

for action in ('column-command', 'strip-reorder', 'screen-drop'):
    base = load(f'base-{action}.agent.json')
    feature = load(f'feature-{action}.agent.json')
    assert base['reasoning']['rawTrees'] == feature['reasoning']['rawTrees'], action
    assert base['inventory']['windows'] == feature['inventory']['windows'], action
    assert len(base['inventory']['windows']) == 14, action
fixture_columns = load('final-native.columns-2.json')
notes = fixture_columns[0]['window-ids'][0]
assert notes in load('feature-column-command.columns-2.json')[2]['window-ids']
safari = fixture_columns[1]['window-ids']
assert load('feature-strip-reorder.columns-2.json')[1]['window-ids'] == [safari[-1], *safari[:-1]]
screen = next(row['tree'] for row in load('feature-screen-drop.agent.json')['reasoning']['rawTrees'] if row['workspace'] == '1')
assert screen['direction'] == 'vertical' and len(screen['children']) == 3
print('Native Column command, tab-strip reorder and on-screen split agree, including native frames')

for theme in ('light', 'dark'):
    for width in (240, 280, 320):
        for levels in ('flat', 'both'):
            name = f'width-{theme}-{width}-{levels}.measure.json'
            measured = load(name)
            clipped = [row['title'] for row in measured['rows'] if row['clipped']]
            if width == 240:
                assert 'Workspace 2' in clipped and 'Workspace 3' in clipped and 'Subscription events' in clipped, name
            else:
                assert not clipped, (name, clipped)
            threshold = max(row['requiredSidebarWidth'] for row in measured['rows'])
            print(f'{name}: clipped={clipped}; estimated minimum={threshold}')
