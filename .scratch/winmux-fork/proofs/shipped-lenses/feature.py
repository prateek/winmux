"""Guest-only checks of the shipped defaults, on the demo standing desk."""
from probe import *
import sys


def windows():
    plain = command('list-lenses')
    lenses = data('list-lenses', '--json')
    expected = {'windows', 'app-windows', 'floating', 'overview', 'search', 'recent'}
    assert set(lenses) == expected and len(plain.strip().splitlines()) == 6, (plain, lenses)
    all_windows = data('list-windows', '--all', '--json')
    matches = data('list-windows', '--lens', 'windows', '--json')
    assert len(all_windows) == 4, all_windows
    assert {w['window-id'] for w in all_windows} == {w['window-id'] for w in matches}
    assert lenses['windows']['sections'] == 'workspace'
    leader('w')
    session = trace('windows')['session']
    assert session['active'] and session['presentation'] == 'grid' and not session['hold'], session
    capture('windows')
    readback('windows')
    close()
    (OUT / 'result.txt').write_text('PASS: six Lenses; window mode w opens all four desk windows in a workspace grid\n')


def pictures():
    for name, presentation in [('windows', 'grid'), ('search', 'list'), ('recent', 'strip'), ('overview', 'miniatures')]:
        command('lens', name)
        time.sleep(2)
        session = trace(presentation)['session']
        assert session['active'] and session['presentation'] == presentation, session
        capture(presentation)
        readback(presentation)
        if name == 'search':
            matches = data('list-windows', '--lens', 'search', '--json')
            (OUT / 'search-matches.json').write_text(json.dumps(matches, indent=2))
            (OUT / 'search-matches-locations.txt').write_text(command('list-windows', '--lens', 'search', '--format', '%{window-id}|%{workspace}|%{app-name}|%{window-title}'))
        close()
    converted = command('config', 'convert', str(TREE / 'nickel-helper/tests/fixtures/upstream-default-config.toml'))
    assert 'six Lenses' in converted, converted
    (OUT / 'converted.ncl').write_text(converted)
    command('config', 'check', str(OUT / 'converted.ncl'))
    (OUT / 'result.txt').write_text('PASS: four shipped Presentations captured; upstream config conversion loads and describes six Lenses\n')


def app_windows():
    all_windows = data('list-windows', '--all', '--json')
    staged = [w for w in all_windows if w['app-name'] == 'stage']
    assert len(staged) == 3, staged
    focused = staged[0]['window-id']
    command('focus', '--window-id', str(focused))
    time.sleep(.5)
    same_app = data('list-windows', '--lens', 'app-windows', '--json')
    assert {w['window-id'] for w in same_app} == {w['window-id'] for w in staged}, same_app
    (OUT / 'same-app-matches.json').write_text(json.dumps(same_app, indent=2))
    start = time.monotonic()
    held = keys('down:cmd', 'tap:backtick', 'wait:2.5', 'tap:backtick', 'wait:2.5',
                'down:shift', 'tap:backtick', 'up:shift', 'wait:2.5',
                'tap:tab', 'wait:2.5', 'up:cmd', 'wait:.5', background=True)
    states = []
    for offset, label in [(1, 'app-first'), (3.5, 'app-forward'), (6, 'app-reverse'), (8.5, 'app-tab')]:
        time.sleep(max(0, start + offset - time.monotonic()))
        states.append(trace(label)['session'])
        capture('app-grid-held' if label == 'app-first' else label)
    first, forward, reverse, tab = states
    assert all(s['presentation'] == 'grid' and s['hold'] and s['active'] for s in states), states
    assert first['selectedId'] != focused, states
    assert forward['selectedId'] != first['selectedId'], states
    assert reverse['selectedId'] == first['selectedId'] == tab['selectedId'], states
    held.wait(timeout=10)
    assert data('list-windows', '--focused', '--json')[0]['window-id'] == tab['selectedId']
    readback('app-release')
    capture('app-release')
    with (OUT / 'quick-lens-events.jsonl').open('w') as events:
        subscription = subprocess.Popen([W, 'subscribe', 'lens-opened', 'lens-closed', '--no-send-initial'], stdout=events)
        movie = OUT / 'quick-tap.mov'
        clock_file = Path(str(movie) + '.clock.json')
        movie.unlink(missing_ok=True)
        clock_file.unlink(missing_ok=True)
        recorder = subprocess.Popen([str(HOME / 'desk/trace-recorder'), str(movie), '4'])
        try:
            deadline = time.monotonic() + 10
            while not clock_file.exists():
                assert recorder.poll() is None, 'recorder exited before its first sample'
                assert time.monotonic() < deadline, 'recorder produced no first sample'
                time.sleep(.05)
            time.sleep(1)
            before = data('list-windows', '--focused', '--json')[0]['window-id']
            keys('delay:0.003', 'down:cmd', 'tap:backtick', 'up:cmd', 'wait:.5')
            after = data('list-windows', '--focused', '--json')[0]['window-id']
            (OUT / 'quick-focus-transition.json').write_text(json.dumps({'before': before, 'after': after}, indent=2))
            readback('quick-tap')
            recorder.wait(timeout=15)
            assert recorder.returncode == 0, recorder.returncode
        finally:
            if recorder.poll() is None:
                recorder.terminate()
                recorder.wait(timeout=5)
            subscription.terminate()
            subscription.wait(timeout=5)
    assert before != after, (before, after)
    assert (OUT / 'quick-lens-events.jsonl').read_text() == ''
    quick = trace('quick-tap')
    assert quick['signal'] == 'cancelled before first frame', quick
    assert not quick['session']['active'], quick
    readback('quick-tap')
    (OUT / 'result.txt').write_text('PASS: same-app grid; held forward/reverse; inert Tab; focus on release; silent quick tap focuses another window\n')


def floating():
    rows = data('list-windows', '--all', '--json')
    staged_rows = [w for w in rows if w['app-name'] == 'stage']
    already_floating = {w['window-id'] for w in data('list-windows', '--lens', 'floating', '--json')}
    staged = next((w for w in staged_rows if w['window-id'] not in already_floating), staged_rows[0])
    command('focus', '--window-id', str(staged['window-id']))
    if staged['window-id'] not in already_floating:
        command('layout', 'floating')
    time.sleep(.5)
    matches = data('list-windows', '--lens', 'floating', '--json')
    assert staged['window-id'] in {w['window-id'] for w in matches}, matches
    leader('f')
    state = trace('floating')['session']
    assert state['active'] and state['presentation'] == 'grid', state
    capture('floating')
    readback('floating')
    close()
    (OUT / 'result.txt').write_text('PASS: window mode f opens floating grid containing a floated stage window\n')


if __name__ == '__main__':
    {'windows': windows, 'pictures': pictures, 'app-windows': app_windows, 'floating': floating}[sys.argv[1]]()
