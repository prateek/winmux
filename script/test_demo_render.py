import importlib.machinery
import importlib.util
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / '.claude/skills/demo'


def load_render():
    loader = importlib.machinery.SourceFileLoader('demo_render', str(DEMO / 'render'))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader('demo_render', loader))
    loader.exec_module(module)
    return module


class DemoRenderTest(unittest.TestCase):
    def test_default_geometry_is_unchanged_for_both_styles(self):
        render = load_render()
        self.assertEqual(render.layout('card', 1920, 1080), dict(
            canvas=(960, 604), inner=(848, 476), at=(56, 64), radius=14,
            title_at=(56, 22), title_size=22, shadow_dy=10, shadow_blur=18, keys_right=904, keys_y=555, key_h=34))
        self.assertEqual(render.layout('claim', 1920, 1080), dict(
            canvas=(960, 584), inner=(960, 540), at=(0, 0), radius=0,
            title_at=(14, 550), title_size=20, keys_right=948, keys_y=547, key_h=30))

    def test_width_scales_geometry_in_both_styles(self):
        render = load_render()
        self.assertEqual(render.layout('card', 1920, 1080, 1920), dict(
            canvas=(1920, 1210), inner=(1696, 954), at=(112, 128), radius=28,
            title_at=(112, 44), title_size=44, shadow_dy=20, shadow_blur=36, keys_right=1808, keys_y=1112, key_h=68))
        self.assertEqual(render.layout('claim', 1920, 1080, 1920), dict(
            canvas=(1920, 1168), inner=(1920, 1080), at=(0, 0), radius=0,
            title_at=(28, 1100), title_size=40, keys_right=1896, keys_y=1094, key_h=60))
        self.assertEqual(render.layout('card', 1280, 720, 1280)['canvas'][0], 1280)

    def test_parser_defaults_and_width_bounds(self):
        render = load_render()
        args = ['take.mov', '-o', 'out.gif', '--title', 'A claim']
        self.assertEqual(render.argument_parser().parse_args(args).width, 960)
        for width in [320, 1280, 1920]:
            self.assertEqual(render.argument_parser().parse_args(args + ['--width', str(width)]).width, width)
        for width in ['319', '321', '1921', '1922', 'no']:
            with self.subTest(width=width), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                render.argument_parser().parse_args(args + ['--width', width])

    def test_invalid_width_cli_refuses_before_tools_or_optional_packages(self):
        result = subprocess.run([sys.executable, '-S', str(DEMO / 'render'), 'absent.mov',
                                 '-o', 'absent.gif', '--title', 'Claim', '--width', '321'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('width must be even', result.stderr)
        self.assertNotIn('ModuleNotFoundError', result.stderr)

    def test_budgets_stay_fixed_at_the_boundary(self):
        render = load_render()
        render.check_duration(8)
        render.check_size(3_000_000)
        with self.assertRaisesRegex(SystemExit, '8s cap'):
            render.check_duration(8.01)
        with self.assertRaisesRegex(SystemExit, '3 MB budget'):
            render.check_size(3_000_001)

    def test_a_key_chip_ends_before_the_next_one_begins(self):
        render = load_render()
        windows = render.chip_windows([0.5, 0.8, 2.0])
        self.assertEqual([round(end, 3) for _, end in windows], [0.799, 2.0 - 0.001, 2.0 + render.KEY_SECONDS])
        for (_, end), (start, _) in zip(windows, windows[1:]):
            self.assertLess(end, start)

    def test_two_keys_at_the_same_instant_do_not_give_a_chip_a_negative_window(self):
        render = load_render()
        for start, end in render.chip_windows([1.0, 1.0, 1.4]):
            self.assertGreaterEqual(end, start)


class GrievanceTest(unittest.TestCase):
    def load_grievances(self):
        loader = importlib.machinery.SourceFileLoader('grievances', str(DEMO / 'desk/grievances.py'))
        module = importlib.util.module_from_spec(importlib.util.spec_from_loader('grievances', loader))
        loader.exec_module(module)
        return module

    def test_reset_uses_the_shared_five_lines(self):
        g = self.load_grievances()
        lines = (DEMO / 'desk/grievance-lines.txt').read_text().splitlines()
        body = g.note_body(lines, 'reset', '<strike>1. old strike</strike>')
        self.assertEqual(body.count('<div>'), 9)
        self.assertNotIn('<strike>', body)
        for line in lines:
            self.assertIn(g.html.escape(line), body)

    def test_strike_keeps_prior_strikes_and_other_lines(self):
        g = self.load_grievances()
        lines = ['1. One', '2. Two', '3. Three', '4. Four', '5. Five']
        first = g.note_body(lines, '1', '')
        third = g.note_body(lines, '3', first)
        self.assertIn('<strike>1. One</strike>', third)
        self.assertIn('<strike>3. Three</strike>', third)
        for i in [2, 4, 5]:
            self.assertIn('<div>' + lines[i - 1] + '</div>', third)
        normalized = '<div><span style="text-decoration: line-through">1. One</span></div>'
        self.assertIn('<strike>1. One</strike>', g.note_body(lines, '3', normalized))

    def test_invalid_number_refuses_before_running_notes(self):
        desk = DEMO / 'desk'
        for args in [['0'], ['9'], ['-1'], [''], ['reset', 'extra'], ['1', '2']]:
            result = subprocess.run([str(desk / 'strike'), *args], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('usage:', result.stderr)


class RichDeskTest(unittest.TestCase):
    def test_the_stage_script_parses_and_its_files_are_in_the_pushed_directory(self):
        desk = DEMO / 'desk'
        subprocess.run(['zsh', '-n', str(desk / 'stage-rich.sh')], check=True)
        for name in ['winmux.ncl', 'Soft language.txt', 'Things I will get to.txt']:
            self.assertTrue((desk / 'rich' / name).is_file(), name)


class PropCommandTest(unittest.TestCase):
    def test_calendar_returns_existing_prop_to_the_original_focused_workspace(self):
        self.run_prop('calendar')

    def test_music_fallback_displays_the_album_in_zed_without_opening_music(self):
        result = self.run_prop('music')
        self.assertEqual(result['opened'], ['Zed'])
        self.assertEqual(result['newWorkspaces'], 1)
        self.assertIn("Seven Windows You Can't Tile", result['displayed'])
        self.assertIn('Stage Manager', result['displayed'])
        for title in ["Fullscreen Is a Cry for Help", "I Don't Have a Problem, You Have a Layout"]:
            self.assertEqual(result['displayed'].count(title), 1)

    def run_prop(self, app):
        import shutil
        import os
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            binary = root / 'bin'
            binary.mkdir()
            cli = root / 'winmux/.build/debug/winmux'
            cli.parent.mkdir(parents=True)
            cli.write_text('#!' + sys.executable + '\n' + '''import json, os, pathlib, sys
p = pathlib.Path(os.environ['HOME']) / 'state.json'
s = json.loads(p.read_text())
a = sys.argv[1:]
if a == ['list-workspaces', '--focused']: print(s['focusedWorkspace'])
elif a[0] == 'list-windows':
 if s['app'] == 'Calendar' and not s.get('ready'): pass
 elif 'window-layout' in a[-1]: print('88|' + ('floating' if s.get('floatingWindow') else 'h_tiles'))
 else:
  print('88|' + s['app'] + '|' + s.get('title', 'Calendar'))
  if s['app'] == 'Zed': print('77|Zed|winmux.ncl')
elif a[0] == 'move-node-to-workspace': s['propWorkspace'] = a[-1]
elif a[0] == 'focus':
 s['focusedWindow'] = a[-1]
 s['focusedWorkspace'] = s['propWorkspace']
elif a[0] == 'layout':
 if s.get('floatingWindow') == a[-1]: raise SystemExit(1)
 s['floatingWindow'] = a[-1]
p.write_text(json.dumps(s))
''')
            cli.chmod(0o755)
            script = binary / 'osascript'
            script.write_text('#!' + sys.executable + '\n' + '''import json, os, pathlib, sys
p = pathlib.Path(os.environ['HOME']) / 'state.json'
s = json.loads(p.read_text())
if any('to activate' in a for a in sys.argv[1:]):
 s['ready'] = True
 p.write_text(json.dumps(s))
 raise SystemExit(0)
if s.get('focusedWindow') != '88': raise SystemExit('prop must be focused before UI commands')
s['focusedWorkspace'] = '1'
s['populated'] = True
p.write_text(json.dumps(s))
''')
            script.chmod(0o755)
            (binary / 'open').write_text('#!' + sys.executable + '\n' + '''import json, os, pathlib, sys
p = pathlib.Path(os.environ['HOME']) / 'state.json'
s = json.loads(p.read_text())
a = sys.argv[1:]
s.setdefault('opened', []).append(a[1])
if a[1] == 'Calendar': s['ready'] = False
if a[1] == 'Zed':
 s['app'] = 'Zed'
 s['title'] = pathlib.Path(a[-1]).name
 s['displayed'] = pathlib.Path(a[-1]).read_text()
 s['populated'] = True
p.write_text(json.dumps(s))
''')
            (binary / 'open').chmod(0o755)
            (binary / 'sleep').write_text('#!/bin/sh\nexit 0\n')
            (binary / 'sleep').chmod(0o755)
            (binary / 'zed').write_text('#!' + sys.executable + '\n' + '''import json, os, pathlib, sys
assert sys.argv[1] == '--new'
p = pathlib.Path(os.environ['HOME']) / 'state.json'
s = json.loads(p.read_text())
s.setdefault('opened', []).append('Zed')
s['newWorkspaces'] = s.get('newWorkspaces', 0) + 1
s['app'] = 'Zed'
s['title'] = pathlib.Path(sys.argv[-1]).name
s['displayed'] = pathlib.Path(sys.argv[-1]).read_text()
s['populated'] = True
p.write_text(json.dumps(s))
''')
            (binary / 'zed').chmod(0o755)
            state = root / 'state.json'
            import json
            state.write_text(json.dumps(dict(focusedWorkspace='2', propWorkspace='1', app=app.capitalize())))
            desk = root / 'desk'
            desk.mkdir()
            shutil.copy2(DEMO / 'desk/props', desk / 'props')
            if app == 'music':
                shutil.copy2(DEMO / 'desk/Music.txt', desk / 'Music.txt')
            for _ in range(2):
                subprocess.run([str(desk / 'props'), app], check=True, capture_output=True,
                               env=dict(os.environ, HOME=str(root), PATH=str(binary) + ':' + os.environ['PATH']))
            import json
            result = json.loads(state.read_text())
            self.assertEqual(result['propWorkspace'], '2')
            self.assertEqual(result['focusedWindow'], '88')
            self.assertTrue(result['populated'])
            self.assertEqual(result['floatingWindow'], '88')
            return result


if __name__ == '__main__':
    unittest.main()
