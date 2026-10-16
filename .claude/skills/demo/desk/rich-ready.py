#!/usr/bin/env python3
"""Bounded readiness and inventory checks for stage-rich.sh."""
from collections import Counter
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.request


EMPTY_NOTES_TITLE = 'Notes – No notes'
EXPECTED = Counter([
    ('Zed', 'winmux.ncl — winmux.ncl'),
    ('Ghostty', 'desk'), ('Ghostty', 'desk'),
    ('Safari', 'Lenses and Search'), ('Safari', 'Fixed Columns'),
    ('Safari', 'Subscription events'), ('Notes', EMPTY_NOTES_TITLE),
    ('TextEdit', 'Grievances.rtf'), ('TextEdit', 'Soft language.rtf'),
    ('TextEdit', 'Things I will get to.rtf'), ('Finder', 'desk'),
    ('Preview', 'wallpaper.jpg'), ('Calculator', 'Calculator'),
    ('Updater', 'A dialog that is not yours'),
])


class StageError(Exception):
    pass


class Readiness:
    def __init__(self):
        self.cli = os.environ.get('WINMUX_CLI', str(Path.home() / 'winmux/.build/debug/winmux'))
        self.bound = float(os.environ.get('STAGE_RICH_TIMEOUT', '60'))
        self.interval = float(os.environ.get('STAGE_RICH_INTERVAL', '.25'))
        if not all(math.isfinite(x) and x > 0 for x in (self.bound, self.interval)):
            raise StageError('timeout and interval must be positive finite seconds')
        self.deadline = time.monotonic() + self.bound

    def run(self, *args):
        remaining = max(.001, self.deadline - time.monotonic())
        return subprocess.run(args, capture_output=True, text=True,
                              timeout=min(5, remaining), check=True).stdout.strip()

    def winmux(self, *args):
        return self.run(self.cli, *args)

    def wait(self, description, probe):
        self.deadline = time.monotonic() + self.bound
        while True:
            try:
                result = probe()
                if result:
                    return result
            except (subprocess.SubprocessError, OSError, ValueError):
                pass
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise StageError(f'{description} after {self.bound:g}s')
            time.sleep(min(self.interval, remaining))

    def windows(self):
        text = self.winmux('list-windows', '--all', '--format',
                           '%{window-id}|%{app-name}|%{window-title}|%{workspace}')
        return [line.split('|', 3) for line in text.splitlines() if line]

    def window(self, app, title, occurrence='1'):
        def found():
            matches = [row[0] for row in self.windows() if row[1] == app and title in row[2]]
            return matches[int(occurrence) - 1] if len(matches) >= int(occurrence) else None
        return self.wait(f'no {app} window' + (f' titled "{title}"' if title else ''),
                         found)

    def front(self, app, title, occurrence='1'):
        def focused():
            matches = [row for row in self.windows() if row[1] == app and title in row[2]]
            if len(matches) < int(occurrence):
                self.run(str(Path.home() / 'desk/rich-app'), 'activate', app, title, occurrence)
                return False
            window = matches[int(occurrence) - 1][0]
            self.winmux('focus', '--window-id', window)
            return self.winmux('list-windows', '--focused', '--format', '%{window-id}') == window
        self.wait(f'no frontmost {app} window titled "{title}"', focused)

    def stopped(self, names, match=False):
        flag = '-f' if match else '-x'
        for name in names:
            subprocess.run(['pkill', flag, name], capture_output=True)

        def gone():
            return all(subprocess.run(['pgrep', flag, name], capture_output=True,
                                      timeout=max(.001, self.deadline - time.monotonic())).returncode == 1
                       for name in names)
        self.wait('processes still running: ' + ', '.join(names), gone)

    def workspace(self, name):
        def focused():
            self.winmux('workspace', name)
            return self.winmux('list-workspaces', '--focused') == name
        self.wait(f'workspace {name} not ready', focused)

    def put(self, window, workspace):
        if not window:
            raise StageError(f'missing window id for workspace {workspace}')
        def placed():
            self.winmux('move-node-to-workspace', '--window-id', window, workspace)
            return any(row[0] == window and row[3] == workspace for row in self.windows())
        self.wait(f'window {window} not on workspace {workspace}', placed)

    def layout(self, window, command, acceptable):
        try:
            self.winmux('layout', command, '--window-id', window)
        except subprocess.CalledProcessError as error:
            # layout returns 1 without a diagnostic when it already matches.
            if error.returncode != 1 or error.stdout or error.stderr:
                raise
        layouts = self.winmux('list-windows', '--all', '--format', '%{window-id}|%{window-layout}')
        return any(line.split('|') == [window, layout] for line in layouts.splitlines()
                   for layout in acceptable)

    def horizontal(self, window):
        self.wait(f'window {window} not in horizontal tiles',
                  lambda: self.layout(window, 'h_tiles', ('h_tiles',)))

    def column(self, window, workspace, slot):
        label = next((f'{row[1]} window "{row[2]}"' for row in self.windows()
                      if row[0] == window), f'window {window}')
        self.put(window, workspace)
        self.workspace(workspace)

        def placed():
            columns = json.loads(self.winmux('list-columns', '--json'))
            if not any(str(c['index']) == slot for c in columns):
                return False
            if not self.layout(window, 'tiling', ('h_tiles', 'v_tiles', 'h_tab_group', 'v_tab_group')):
                return False
            self.winmux('move-node-to-column', slot, '--window-id', window)
            columns = json.loads(self.winmux('list-columns', '--json'))
            return any(str(c['index']) == slot and int(window) in c['window-ids'] for c in columns)
        self.wait(f'no {label} in Column {slot} on workspace {workspace}', placed)

    def columns(self, workspace, count):
        self.workspace(workspace)
        self.wait(f'workspace {workspace} does not have {count} Columns',
                  lambda: len(json.loads(self.winmux('list-columns', '--json'))) == int(count))

    def notes(self):
        # Notes Automation is granted in the image; Safari Automation is never used.
        def note_count():
            value = self.run('osascript', '-e',
                             'tell application "Notes" to count notes of folder "Notes" of account "On My Mac"')
            return value if value.isdecimal() else None
        count = int(self.wait('Notes local note list not ready', note_count))
        title = EMPTY_NOTES_TITLE if count == 0 else f'Notes – {count} ' + ('note' if count == 1 else 'notes')
        self.front('Notes', title)
        return title

    def http(self):
        def served():
            with urllib.request.urlopen('http://localhost:8765/lenses.html',
                                        timeout=min(2, max(.001, self.deadline - time.monotonic()))) as page:
                return b'Lenses and Search' in page.read()
        self.wait('docs page not served at localhost:8765/lenses.html', served)

    def inventory(self, notes_title=EMPTY_NOTES_TITLE):
        expected = EXPECTED.copy()
        del expected[('Notes', EMPTY_NOTES_TITLE)]
        expected[('Notes', notes_title)] = 1
        actual = Counter((row[1], row[2]) for row in self.windows())
        differences = []
        for kind, windows in [('missing', expected - actual), ('extra', actual - expected)]:
            for (app, title), count in windows.items():
                differences.extend([f'{kind} {app} window titled "{title}"'] * count)
        if differences:
            raise StageError('\n'.join(differences))


def main(args):
    ready = Readiness()
    command, *args = args
    if command == 'display':
        match = re.fullmatch(r'(\d+)x(\d+)@\d+', args[0])
        if not match or int(match[1]) < 1920 or int(match[2]) < 1080:
            raise StageError(f'rich desk needs at least 1920x1080 points; got {args[0]}')
    elif command == 'window':
        print(ready.window(*args))
    elif command == 'notes':
        print(ready.notes())
    elif command == 'ready':
        ready.wait('WinMux CLI not ready', lambda: ready.winmux('list-workspaces', '--focused'))
    elif command == 'stop':
        ready.stopped(args)
    elif command == 'stop-server':
        ready.stopped(['http.server 8765'], match=True)
    else:
        getattr(ready, command)(*args)


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (StageError, subprocess.SubprocessError, OSError, ValueError) as error:
        print('stage-rich: ' + str(error), file=sys.stderr)
        sys.exit(1)
