"""Guest-only evidence helpers; invoke through vm ssh on the standing desk."""
import json
import os
from pathlib import Path
import subprocess
import time

HOME = Path.home()
TREE = Path(os.environ.get('WINMUX_TREE', HOME / 'winmux'))
OUT = HOME / 'takes' / os.environ.get('PROBE_NAME', 'shipped-lenses')
OUT.mkdir(parents=True, exist_ok=True)
W = str(TREE / '.build/debug/winmux')
os.environ['WINMUX_NICKEL_HELPER'] = str(TREE / 'nickel-helper/target/release/winmux-nickel')


def command(*args):
    result = subprocess.run([W, *args], text=True, capture_output=True)
    with (OUT / 'transcript.txt').open('a') as log:
        log.write('$ winmux ' + ' '.join(args) + '\n' + result.stdout + result.stderr + '\n')
    result.check_returncode()
    return result.stdout


def data(*args):
    return json.loads(command(*args))


def trace(label):
    value = data('debug-lens-trace', '--json', '--last', '1')[-1]
    (OUT / (label + '.json')).write_text(json.dumps(value, indent=2))
    (OUT / (label + '.txt')).write_text(command('debug-lens-trace', '--last', '1'))
    return value


def keys(*steps, background=False):
    args = [str(HOME / 'desk/keys'), str(time.time()), str(OUT / 'keys.events.json'), *steps]
    if background:
        return subprocess.Popen(args)
    subprocess.run(args, check=True)


def capture(label):
    subprocess.run(['/opt/homebrew/bin/cliclick', 'm:1240,714'], check=True)
    subprocess.run(['screencapture', '-x', str(OUT / (label + '.png'))], check=True)


def close():
    keys('tap:escape', 'wait:0.15', 'tap:escape', 'wait:0.3')


def readback(label):
    (OUT / (label + '-windows.json')).write_text(command('list-windows', '--all', '--json'))
    (OUT / (label + '-focused.json')).write_text(command('list-windows', '--focused', '--json'))
    (OUT / (label + '-workspace.txt')).write_text(command('list-workspaces', '--focused'))
    (OUT / (label + '-locations.txt')).write_text(command('list-windows', '--all', '--format', '%{window-id}|%{workspace}|%{app-name}|%{window-title}'))


def leader(letter):
    keys('down:alt', 'tap:semicolon', 'up:alt', 'wait:0.3', 'tap:' + letter, 'wait:1')


def unchanged():
    """Run unchanged actions against both actual trees, without named-Lens overrides."""
    for letter in ['a', 'r']:
        leader(letter)
        state = trace('leader-' + letter)['session']
        assert state['active'] and state['presentation'] == 'list', state
        lens = 'app-windows' if letter == 'a' else 'recent'
        (OUT / ('leader-' + letter + '-matches.json')).write_text(command('list-windows', '--lens', lens, '--json'))
        (OUT / ('leader-' + letter + '-matches-locations.txt')).write_text(command('list-windows', '--lens', lens, '--format', '%{window-id}|%{workspace}|%{app-name}|%{window-title}'))
        capture('leader-' + letter)
        readback('leader-' + letter)
        close()
    command('lens', 'search', '--search', 'Lenses')
    time.sleep(1)
    matches = data('list-windows', '--search', 'Lenses', '--json')
    (OUT / 'search-matches.json').write_text(json.dumps(matches, indent=2))
    (OUT / 'search-matches-locations.txt').write_text(command('list-windows', '--search', 'Lenses', '--format', '%{window-id}|%{workspace}|%{app-name}|%{window-title}'))
    assert len(matches) == 1, matches
    state = trace('search')['session']
    assert state['presentation'] == 'list' and state['search'] == 'Lenses', state
    capture('search')
    keys('tap:return', 'wait:0.5')
    focused = data('list-windows', '--focused', '--json')
    assert focused[0]['window-id'] == matches[0]['window-id'], (focused, matches)
    readback('search-focus')
    command('lens', 'overview')
    time.sleep(1)
    assert trace('overview')['session']['presentation'] == 'miniatures'
    capture('overview')
    close()
    held = keys('down:cmd', 'tap:tab', 'wait:1.5', 'tap:backtick', 'wait:1.5',
                'tap:tab', 'wait:1.5', 'down:shift', 'tap:tab', 'up:shift',
                'wait:1.5', 'up:cmd', 'wait:0.5', background=True)
    time.sleep(1)
    first = trace('recent-first')['session']
    assert first['active'] and first['presentation'] == 'strip' and first['hold'], first
    capture('recent-held')
    time.sleep(1.5)
    inert = trace('recent-backtick')['session']
    assert inert['selectedId'] == first['selectedId'], (first, inert)
    time.sleep(1.5)
    stepped = trace('recent-step')['session']
    assert stepped['selectedId'] != first['selectedId'], (first, stepped)
    time.sleep(1.5)
    reverse = trace('recent-reverse')['session']
    assert reverse['selectedId'] == first['selectedId'], (first, reverse)
    held.wait(timeout=10)
    assert data('list-windows', '--focused', '--json')[0]['window-id'] == reverse['selectedId']
    readback('recent-release')
    (OUT / 'result.txt').write_text('PASS: a/r lists, Search ranking and Focus, overview miniatures, recent strip forward/reverse/release and inert backtick\n')


if __name__ == '__main__':
    unchanged()
