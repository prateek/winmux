#!/usr/bin/env python3
import json
from pathlib import Path
import re
import sys

captures = Path(sys.argv[1])
final = captures / 'final'
for pane in ['overview', 'lenses', 'shortcuts', 'columns', 'hooks', 'behavior', 'appearance', 'config-file', 'reference']:
    text = (final / f'{pane}.ax').read_text()
    window = re.search(r'^ AXWindow[^\n]*\.shortcutSettings[^\n]*\n(.*?)(?=^ AX(?:Window|MenuBar)|\Z)', text, re.M | re.S)
    assert window, pane
    content = window.group(1)
    for role in ['AXCheckBox', 'AXSwitch', 'AXPopUpButton', 'AXSlider', 'AXStepper', 'AXComboBox', 'AXTextArea']:
        assert not re.search(rf'^ +{role} \|', content, re.M), (pane, role)
    fields = len(re.findall(r'^ +AXTextField \|', content, re.M))
    assert fields == (1 if pane == 'shortcuts' else 0), (pane, fields)
    print(f'{pane}: {fields} editable text fields; no setting editors')

assert (final / 'before.txt').read_bytes() == (final / 'after.txt').read_bytes()
print('config hash, mtime and defaults: unchanged')
# The four searches read-only.zsh runs on the shipped config.
for name, count in [('lens', 8), ('glyph', 16), ('window', 45), ('empty', 0)]:
    text = (final / f'search-{name}.ax').read_text()
    actual = re.search(r'AXStaticText \| (\d+) bindings \| settings-shortcut-count', text)
    assert actual and int(actual[1]) == count, (name, actual)
    print(f'search {name}: {count} matches')
for name in ['lenses.json', 'main-bindings.json', 'window-bindings.json']:
    base = json.loads((captures / 'base-unchanged' / name).read_text())
    head = json.loads((captures / 'head-unchanged' / name).read_text())
    assert base == head, name
    print(f'base/head {name}: identical ({len(head)} entries)')
for build in ['base-unchanged', 'head-unchanged']:
    take = captures / build
    assert (take / 'before.txt').read_bytes() == (take / 'after-disk.txt').read_bytes()
    assert (take / 'before.txt').read_bytes() == (take / 'after-open.txt').read_bytes()
    print(f'{build}: both file buttons preserved file and defaults')
