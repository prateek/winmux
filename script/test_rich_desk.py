import json
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / '.claude/skills/demo/desk/rich-ready.py'


class RichDeskTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.fixture = self.directory / 'fixture.json'
        self.stub = self.directory / 'winmux'
        self.stub.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys, time
p = pathlib.Path(os.environ['DESK_FIXTURE'])
data = json.loads(p.read_text())
args = sys.argv[1:]
if data.get('hang'): time.sleep(10)
if pathlib.Path(sys.argv[0]).name == 'pkill':
    data['gone_at'] = time.time() + data.get('exit_delay', 0)
    p.write_text(json.dumps(data))
elif pathlib.Path(sys.argv[0]).name == 'pgrep':
    sys.exit(0 if time.time() < data.get('gone_at', 0) else 1)
elif pathlib.Path(sys.argv[0]).name == 'osascript':
    print('0')
elif pathlib.Path(sys.argv[0]).name == 'rich-app':
    pass
elif args[0] == 'list-windows':
    if 'appear_delay' in data and 'appears' not in data:
        data['appears'] = time.time() + data['appear_delay']
        p.write_text(json.dumps(data))
    if time.time() >= data.get('appears', 0):
        if args[-1] == '%{window-id}|%{window-layout}':
            for row in data.get('windows', '').splitlines():
                print(row.split('|')[0] + '|' + data.get('layout', 'h_tiles'))
        elif '--focused' in args:
            print(data.get('focused', ''))
        else:
            print(data.get('windows', ''), end='')
elif args[0] == 'focus':
    data['focused'] = args[2]
    p.write_text(json.dumps(data))
elif args[0] == 'list-workspaces':
    print(data.get('workspace', '2'))
elif args[0] == 'list-columns':
    print(json.dumps(data.get('columns', [])))
elif args[0] == 'move-node-to-column':
    data['moves'] = data.get('moves', 0) + 1
    if data['moves'] >= data.get('succeed_on', 1):
        data['columns'] = [{'index': int(args[1]), 'window-ids': [int(args[3])]}]
    p.write_text(json.dumps(data))
elif args[0] == 'workspace':
    data['workspace'] = args[1]
    p.write_text(json.dumps(data))
elif args[0] == 'layout' and data.get('already_tiled'):
    sys.exit(1)
''')
        self.stub.write_text(self.stub.read_text().replace('#!/usr/bin/env python3', '#!' + sys.executable))
        self.stub.chmod(0o755)
        for command in ('pgrep', 'pkill', 'osascript'):
            (self.directory / command).symlink_to(self.stub)
        (self.directory / 'desk').mkdir()
        (self.directory / 'desk/rich-app').symlink_to(self.stub)
        self.env = dict(os.environ, WINMUX_CLI=str(self.stub),
                        DESK_FIXTURE=str(self.fixture), STAGE_RICH_TIMEOUT='2',
                        STAGE_RICH_INTERVAL='.02', HOME=str(self.directory),
                        PATH=str(self.directory) + os.pathsep + os.environ['PATH'])

    def run_helper(self, *args, wait_bound='2', **data):
        self.fixture.write_text(json.dumps(data))
        start = time.monotonic()
        result = subprocess.run([sys.executable, str(HELPER), *args],
                                env=dict(self.env, STAGE_RICH_TIMEOUT=wait_bound),
                                capture_output=True, text=True, timeout=float(wait_bound) * 3 + 2)
        self.assertLess(time.monotonic() - start, float(wait_bound) * 3 + 1)
        return result

    def test_existing_window_title_fragment_returns_its_id(self):
        result = self.run_helper('window', 'Safari', 'Lenses',
                                 windows='7|Safari|Lenses and Search|1\n')
        self.assertEqual((result.returncode, result.stdout), (0, '7\n'))

    def test_window_appears_after_delay(self):
        result = self.run_helper('window', 'Safari', 'Lenses',
                                 appear_delay=.04,
                                 windows='7|Safari|Lenses and Search|1\n')
        self.assertEqual((result.returncode, result.stdout), (0, '7\n'))

    def test_missing_window_is_named_and_bounded(self):
        result = self.run_helper('window', 'Safari', 'Lenses',
                                 windows='7|Safari|Fixed Columns|1\n', wait_bound='.35')
        self.assertEqual(result.returncode, 1)
        self.assertIn('no Safari window titled "Lenses" after 0.35s', result.stderr)
        self.assertEqual(result.stdout, '')

    def test_unresponsive_cli_is_also_bounded(self):
        result = self.run_helper('window', 'Safari', 'Lenses', hang=True, wait_bound='.35')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Lenses', result.stderr)

    def test_missing_window_deadline_excludes_interpreter_startup(self):
        spec = importlib.util.spec_from_file_location('rich_ready', HELPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.fixture.write_text(json.dumps({'windows': ''}))
        with patch.dict(os.environ, dict(self.env, STAGE_RICH_TIMEOUT='.35')):
            ready = module.Readiness()
            start = time.monotonic()
            with self.assertRaisesRegex(module.StageError, 'no Safari window titled "Lenses" after 0.35s'):
                ready.window('Safari', 'Lenses')
            self.assertGreaterEqual(time.monotonic() - start, .35)
            self.assertLess(time.monotonic() - start, .6)

    def test_window_wait_does_not_accept_another_app(self):
        result = self.run_helper('window', 'Safari', 'Lenses',
                                 windows='7|Ghostty|Lenses|1\n', wait_bound='.35')
        self.assertEqual(result.returncode, 1)

    def test_second_terminal_waits_for_distinct_window(self):
        result = self.run_helper('window', 'Ghostty', 'desk', '2',
                                 windows='7|Ghostty|desk|1\n', wait_bound='.35')
        self.assertEqual(result.returncode, 1)

    def test_frontmost_wait_targets_the_second_terminal(self):
        result = self.run_helper('front', 'Ghostty', 'desk', '2',
                                 windows='7|Ghostty|desk|1\n8|Ghostty|desk|1\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.fixture.read_text())['focused'], '8')

    def test_frontmost_wait_names_missing_target(self):
        result = self.run_helper('front', 'Safari', 'Lenses', windows='', wait_bound='.35')
        self.assertEqual(result.returncode, 1)
        self.assertIn('no frontmost Safari window titled "Lenses"', result.stderr)

    def test_stop_waits_for_delayed_process_exit(self):
        result = self.run_helper('stop', 'ghostty', exit_delay=.15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertGreaterEqual(time.time(), json.loads(self.fixture.read_text())['gone_at'])

    def test_still_running_process_is_named(self):
        result = self.run_helper('stop', 'ghostty', exit_delay=5, wait_bound='.35')
        self.assertEqual(result.returncode, 1)
        self.assertIn('processes still running: ghostty', result.stderr)

    def test_notes_waits_for_window_as_well_as_local_note_list(self):
        result = self.run_helper('notes', windows='7|Notes|Notes – No notes|1\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper('notes', windows='', wait_bound='1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('no frontmost Notes window', result.stderr)

    def test_column_wait_checks_membership_and_retries_only_that_placement(self):
        result = self.run_helper('column', '7', '2', '2',
                                 windows='7|Safari|Lenses and Search|2\n',
                                 columns=[{'index': 1, 'window-ids': [7]},
                                          {'index': 2, 'window-ids': []}], succeed_on=2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.fixture.read_text())['moves'], 2)

    def test_failed_column_names_window_and_column(self):
        result = self.run_helper('column', '7', '2', '2',
                                 windows='7|Safari|Lenses and Search|2\n',
                                 columns=[{'index': 2, 'window-ids': []}], succeed_on=100, wait_bound='1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Safari window "Lenses and Search" in Column 2 on workspace 2', result.stderr)

    def test_already_tiled_noop_does_not_block_column_placement(self):
        result = self.run_helper('column', '7', '2', '2',
                                 windows='7|Safari|Lenses and Search|2\n', already_tiled=True,
                                 columns=[{'index': 2, 'window-ids': []}])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_layout_exit_without_tiling_readback_is_not_accepted(self):
        result = self.run_helper('column', '7', '2', '2',
                                 windows='7|Safari|Lenses and Search|2\n', already_tiled=True,
                                 layout='floating', columns=[{'index': 2, 'window-ids': []}], wait_bound='1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Column 2', result.stderr)

    def test_horizontal_layout_accepts_verified_noop(self):
        result = self.run_helper('horizontal', '7', windows='7|Preview|wallpaper.jpg|4\n',
                                 already_tiled=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_horizontal_layout_requires_horizontal_readback(self):
        result = self.run_helper('horizontal', '7', windows='7|Preview|wallpaper.jpg|4\n',
                                 layout='v_tiles', wait_bound='.35')
        self.assertEqual(result.returncode, 1)
        self.assertIn('window 7 not in horizontal tiles', result.stderr)

    def test_workspace_transfer_still_works_with_columns_off(self):
        result = self.run_helper('put', '7', '2',
                                 windows='7|Notes|Notes – No notes|2\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_display_refuses_small_desk_before_staging(self):
        result = self.run_helper('display', '1280x720@1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('1920x1080', result.stderr)

    def inventory(self):
        return '\n'.join(f'{i}|{app}|{title}|1' for i, (app, title) in enumerate([
            ('Zed', 'winmux.ncl — winmux.ncl'), ('Ghostty', 'desk'), ('Ghostty', 'desk'),
            ('Safari', 'Lenses and Search'), ('Safari', 'Fixed Columns'),
            ('Safari', 'Subscription events'), ('Notes', 'Notes – No notes'),
            ('TextEdit', 'Grievances.rtf'), ('TextEdit', 'Soft language.rtf'),
            ('TextEdit', 'Things I will get to.rtf'), ('Finder', 'desk'),
            ('Preview', 'wallpaper.jpg'), ('Calculator', 'Calculator'),
            ('Updater', 'A dialog that is not yours')], 1)) + '\n'

    def test_exact_fourteen_windows_pass(self):
        result = self.run_helper('inventory', windows=self.inventory())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_equal_count_with_replacement_names_missing_and_extra(self):
        windows = self.inventory().replace('4|Safari|Lenses and Search|1', '4|Ghostty|~|1')
        result = self.run_helper('inventory', windows=windows)
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing Safari window titled "Lenses and Search"', result.stderr)
        self.assertIn('extra Ghostty window titled "~"', result.stderr)

    def test_duplicate_window_is_extra_even_with_known_title(self):
        result = self.run_helper('inventory', windows=self.inventory() + '15|Ghostty|desk|1\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('extra Ghostty window titled "desk"', result.stderr)


if __name__ == '__main__':
    unittest.main()
