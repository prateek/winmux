import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import sys
import types
import unittest

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / '.claude/skills/demo'


def load_render():
    # render draws with Pillow, which uv supplies when it runs as a script; chip timing needs none of it.
    for name in ['PIL', 'PIL.Image', 'PIL.ImageDraw', 'PIL.ImageFilter', 'PIL.ImageFont']:
        sys.modules.setdefault(name, types.ModuleType(name))
    loader = importlib.machinery.SourceFileLoader('demo_render', str(DEMO / 'render'))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader('demo_render', loader))
    loader.exec_module(module)
    return module


class DemoRenderTest(unittest.TestCase):
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


class RichDeskTest(unittest.TestCase):
    def test_the_stage_script_parses_and_its_files_are_in_the_pushed_directory(self):
        desk = DEMO / 'desk'
        subprocess.run(['zsh', '-n', str(desk / 'stage-rich.sh')], check=True)
        for name in ['winmux.ncl', 'Soft language.txt', 'Things I will get to.txt']:
            self.assertTrue((desk / 'rich' / name).is_file(), name)


if __name__ == '__main__':
    unittest.main()
