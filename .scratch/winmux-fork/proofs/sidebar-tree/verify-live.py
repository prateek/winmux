#!/usr/bin/env python3
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
fixture = root if (root / 'original.agent.json').exists() else root.parent
wanted = set(sys.argv[2:])


def load(name, suffix='agent.json', directory=root):
    return json.loads((directory / f'{name}.{suffix}').read_text())


def tree(name, workspace):
    return next(row['tree'] for row in load(name)['reasoning']['rawTrees'] if row['workspace'] == workspace)


def leaves(node):
    if node['kind'] == 'window':
        return [node['windowId']]
    if node['kind'] == 'tabGroup':
        return node['tabs']
    return [window for child in node.get('children', []) for window in leaves(child)]


def tabs(name, workspace):
    def walk(node):
        if node['kind'] == 'tabGroup':
            return [node['tabs']]
        return [group for child in node.get('children', []) for group in walk(child)]
    return walk(tree(name, workspace))


def windows(name):
    return {int(row[0]): row[1:] for row in
            [line.split('|') for line in (root / f'{name}.windows.txt').read_text().splitlines()]}


original = load('original', directory=fixture)
ids = {row['title']: row['windowId'] for row in original['inventory']['windows']}
zed = ids['winmux.ncl — winmux.ncl']
notes = ids['Notes – No notes']
calculator = ids['Calculator']
original_root = next(row['tree'] for row in original['reasoning']['rawTrees'] if row['workspace'] == '1')
tiling = leaves(original_root)
ghosts = [window for window in tiling if window != zed]
source = ghosts[-1]
safari = load('original', 'columns-2.json', fixture)[1]['window-ids']
textedit = load('original', 'columns-3.json', fixture)[0]['window-ids']
checked = []


def check(name, test):
    if wanted and name not in wanted:
        return
    test()
    assert len(windows(name)) == 14, name
    checked.append(name)


def equal(actual, expected):
    assert actual == expected, (actual, expected)


for name in ['flat-before', 'levels-before']:
    check(name, lambda n=name: equal(leaves(tree(n, '1')), [source, zed, ghosts[0]]))
for name in ['flat-after', 'levels-after']:
    check(name, lambda n=name: equal(leaves(tree(n, '1')), [zed, source, ghosts[0]]))
check('tab-after', lambda: equal(tabs('tab-after', '2'), [[safari[0], safari[1], notes, safari[2]]]))


def direct(name, after):
    split = tree(name, '2')['children'][0]
    equal((split['kind'], split['direction'], leaves(split)),
          ('split', 'vertical', [notes, source] if after else [source, notes]))
    equal([column['width'] for column in load(name, 'columns-2.json')], [.28, .44, .28])


check('direct-column-before', lambda: direct('direct-column-before', False))
check('direct-column-after', lambda: direct('direct-column-after', True))
check('column-row', lambda: equal(load('column-row', 'columns-2.json')[0]['window-ids'], [notes, source]))
check('column-mark', lambda: equal(load('column-mark', 'columns-2.json')[1]['window-ids'], safari + [source]))
check('group-join', lambda: equal(tabs('group-join', '3'), [textedit + safari]))
check('split-target', lambda: equal(leaves(tree('split-target', '1')), tiling + [notes]))
check('split-source', lambda: equal(tabs('split-source', '3'), [textedit + tiling]))
check('own-workspace', lambda: equal(load('own-workspace')['reasoning']['rawTrees'], load('own-workspace-before')['reasoning']['rawTrees']))
for name in ['floating-workspace', 'floating-window', 'floating-group']:
    check(name, lambda n=name: equal(windows(n)[calculator][-2:], ['1', 'floating']))
check('floating-tiled', lambda: equal(leaves(tree('floating-tiled', '1')), [zed, calculator] + ghosts))
check('group-floats', lambda: equal([windows('group-floats')[window][-2:] for window in safari], [['1', 'floating']] * 3))


def refusal(name, text):
    equal(load(name)['reasoning']['rawTrees'], load('refusals-before')['reasoning']['rawTrees'])
    ui = load(name + '-preview', 'ui.json')
    assert any(text in row['value'] for row in ui), name


for name in ['self-refusal', 'descendant-refusal', 'split-descendant-refusal']:
    check(name, lambda n=name: refusal(n, 'Cannot drop'))
for name in ['workspace-heading-refusal', 'column-heading-refusal']:
    check(name, lambda n=name: refusal(n, 'Workspaces and Columns'))
check('invariant-empty-workspace', lambda: equal(load('invariant-empty-workspace', 'columns-2.json')[0]['window-ids'], [source]))
check('invariant-occupied-workspace', lambda: equal(load('invariant-occupied-workspace', 'columns-2.json')[1]['window-ids'], safari + [source]))
check('invariant-group-workspace', lambda: equal(tabs('invariant-group-workspace', '3'), [textedit + safari]))
print(json.dumps({'checked': checked, 'count': len(checked)}, indent=2))
