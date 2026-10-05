import ast
from pathlib import Path
import unittest


class DemoRenderTest(unittest.TestCase):
    def test_successive_key_chips_do_not_overlap(self):
        source = Path(__file__).resolve().parents[1] / '.claude/skills/demo/render'
        tree = ast.parse(source.read_text())
        loop = next(node for node in ast.walk(tree) if isinstance(node, ast.For) and ast.unparse(node.target) == '(index, event)')
        # Exercise the renderer's real event loop at its ffmpeg-command boundary.
        class Chip:
            width = 50
            def save(self, path): pass
        events = [{'t': 0.5, 'keys': 'Tab'}, {'t': 0.8, 'keys': 'Tab'}, {'t': 2, 'keys': 'Esc'}]
        import types
        namespace = dict(args=types.SimpleNamespace(start=0), end=3, events=events, visible_events=events,
                         key_chip=lambda *args: Chip(), geo=dict(key_h=30, keys_right=960, keys_y=540),
                         tmp=Path('/tmp'), inputs=[], length=3, FPS=15, KEY_SECONDS=1.2, graph=[], last='c0', next_input=3)
        exec(compile(ast.fix_missing_locations(ast.Module(body=[loop], type_ignores=[])), str(source), 'exec'), namespace)
        import re
        intervals = [tuple(map(float, re.search(r'between\(t,([\d.]+),([\d.]+)\)', entry).groups())) for entry in namespace['graph']]
        for previous, following in zip(intervals, intervals[1:]):
            self.assertLess(previous[1], following[0])
        self.assertEqual(intervals[0], (0.5, 0.799))
        self.assertEqual(intervals[-1], (2, 3.2))


class RichDeskTest(unittest.TestCase):
    def test_rich_desk_uses_stable_targets_and_one_pushed_directory(self):
        root = Path(__file__).resolve().parents[1]
        desk = root / '.claude/skills/demo/desk'
        script = (desk / 'stage-rich.sh').read_text()
        config = (desk / 'rich/winmux.ncl').read_text()
        self.assertNotIn('~/rich/', script)
        self.assertNotIn('osascript -e', script)
        self.assertIn('~/desk/rich/winmux.ncl', script)
        self.assertIn('swiftc -O wallpaper.swift', script)
        self.assertIn('swiftc -O dialog.swift', script)
        self.assertIn('keys.swift -o ~/desk/keys', script)
        self.assertIn('"Start Page"', script)
        self.assertGreater(script.rfind('cp ~/desk/rich/winmux.ncl'), script.index('put $(id Preview "") "4"'))
        self.assertIn('put $(id Finder "desk") "3"', script)
        self.assertIn('SafariTabs.db*(N)', script)
        self.assertIn('http://localhost:8765/lenses.html', script)
        self.assertNotIn('open -a Safari ~/desk/docs', script)
        self.assertIn('--bind 127.0.0.1 --directory', script)
        self.assertIn('make-repo.sh', script)
        self.assertIn('Ghostty --args -e ~/desk/term.sh', script)
        self.assertIn('persistent-workspaces = ["1", "2", "3", "4"]', config)
        self.assertIn('workspace."2".columns', config)
        self.assertIn('workspace."3".columns', config)
        for text in ['Soft language.txt', 'Things I will get to.txt']:
            self.assertTrue((desk / 'rich' / text).is_file())
        import subprocess
        subprocess.run(['zsh', '-n', str(desk / 'stage-rich.sh')], check=True)


if __name__ == '__main__':
    unittest.main()
