#!/usr/bin/env python3
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])


def ui(name):
    return json.loads((root / f'{name}.ui.json').read_text())


def buttons(name):
    return [row for row in ui(name) if row['role'] == 'AXButton' and 0 <= row['x'] < 320]


titles = ['Lenses and Search', 'Fixed Columns', 'Subscription events', 'Grievances.rtf', 'Soft language.rtf']
queries = {
    'search-safari': (titles[:3], 'workspace 2 / Column 2 / Safari tabs'),
    'search-grievances': ([titles[3]], 'workspace 3 / Column 1 / TextEdit tabs'),
    'search-none': ([], 'no matching paths'),
}
for name, (expected, path) in queries.items():
    found = sorted(row['description'] for row in buttons(name) if row['description'] in titles)
    assert found == sorted(expected), (name, found, expected)
    print(f'{name}: {len(found)} matches; {path}')

collapsed = [row['description'] for row in buttons('both-tabs-collapsed')]
for name in ['clear-safari', 'clear-grievances', 'clear-none']:
    assert [row['description'] for row in buttons(name)] == collapsed, name
assert 'Notes – No notes' not in [row['description'] for row in buttons('column-collapsed')]
assert 'Notes – No notes' in [row['description'] for row in buttons('column-reopened')]

cases = {
    'defaults-flat': ([False] * 4, [False, False]),
    'override-both-2': ([False, True, False, False], [True, False]),
    'defaults-unchanged-reload': ([False, True, False, False], [True, False]),
    'defaults-only-splits-changed': ([True] * 4, [True, False]),
    'defaults-both-reload': ([True] * 4, [True, True]),
    'defaults-both-restart': ([True] * 4, [True, True]),
    'defaults-columns-reload': ([False] * 4, [True, True]),
    'defaults-columns-restart': ([False] * 4, [True, True]),
    'defaults-splits-reload': ([True] * 4, [False, False]),
    'defaults-splits-restart': ([True] * 4, [False, False]),
    'defaults-only-columns-changed': ([True, False, True, True], [True, True]),
    'defaults-final-both': ([True] * 4, [True, True]),
}
for name, (splits, columns) in cases.items():
    rows = buttons(name)
    actual_splits = [row['value'] == 'Shown' for row in sorted(rows, key=lambda row: row['y']) if row['description'] == 'Show splits']
    actual_columns = [row['value'] == 'Shown' for row in sorted(rows, key=lambda row: row['y']) if row['description'] == 'Show Columns']
    assert actual_splits == splits, (name, actual_splits, splits)
    assert actual_columns == columns, (name, actual_columns, columns)
    labels = [row['description'] for row in rows]
    assert ('Column 1 · 28%' in labels) == columns[0], name
    assert ('Column 1 · 67%' in labels) == columns[1], name
    print(f'{name}: splits={actual_splits}, columns={actual_columns}')
