"""Executable regressions for the scratch proof tools; no desktop access."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent


class ToolsTest(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("PARKING_BINARY"), "set PARKING_BINARY to the guest-built parking probe")
    def test_parking_missing_arguments_print_usage(self):
        for arguments in [[], ["save"], ["apply"], ["apply", "frames.json"], ["capture"], ["unknown"]]:
            with self.subTest(arguments=arguments):
                result = subprocess.run([os.environ["PARKING_BINARY"], *arguments], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("usage: parking", result.stdout)

    def measure(self, frames, title):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "frames.json").write_text(json.dumps(frames))
            (folder / "ax.txt").write_text(
                f'     Optional(AXButton) | Optional({title}) | Optional({title}) | '
                'Optional(<AXValue> {value = x:10.0 y:20.0 type = point}) | '
                'Optional(<AXValue> {value = w:80.0 h:40.0 type = size})\n'
            )
            return subprocess.run([sys.executable, str(ROOT / "measure.py"), str(folder / "frames.json"),
                                   str(folder / "ax.txt")], capture_output=True, text=True)

    def test_title_with_parentheses_is_matched_whole(self):
        title = "Notes (archived) (2)"
        result = self.measure([dict(title=title, x=0, y=0, width=800, height=400)], title)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"{title}: 80x40 / 800x400 = 10.00%", result.stdout)

    def test_zero_size_frame_is_skipped_with_note(self):
        result = self.measure([dict(title="Notes", x=0, y=0, width=0, height=0)], "Notes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("skip zero-size frame", result.stdout)

    def shell_tool(self, name):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for tree in ["winmux", "base"]:
                bin_dir = home / tree / ".build/debug"
                bin_dir.mkdir(parents=True)
                for executable in ["WinMuxApp", "winmux"]:
                    path = bin_dir / executable
                    path.write_text('#!/bin/zsh\nprint -r -- "$0 $*" >> "$HOME/events"\n'
                                    'if [[ "$1" == list-windows ]]; then print \'[{"window-title":"Lenses and Search","window-id":918}]\'; fi\n')
                    path.chmod(0o755)
            tools = home / "mission-control"
            tools.mkdir()
            for tool in ["arrow-chord", "parking"]:
                path = tools / tool
                path.write_text('#!/bin/zsh\nprint -r -- "$0 $*" >> "$HOME/events"\n')
                path.chmod(0o755)
            recorder = home / "recorder.py"
            recorder.write_text('''import os, signal, sys, time
from pathlib import Path
marker = Path(os.environ["HOME"]) / "recording"
marker.touch()
def finish(*args):
    marker.unlink(missing_ok=True)
    sys.exit(0)
signal.signal(signal.SIGINT, finish)
signal.signal(signal.SIGTERM, finish)
if "-V" in sys.argv:
    time.sleep(float(sys.argv[sys.argv.index("-V") + 1]) * .005)
    finish()
while True: time.sleep(.01)
''')
            harness = r'''
sleep() { /bin/sleep .03; }
pkill() { return 0; }
nohup() { "$@"; }
cliclick() { print -r -- "cliclick $*" >> "$HOME/events"; }
screencapture() {
    if [[ " $* " == *" -v "* ]]; then
        exec "$PYTHON" "$HOME/recorder.py" "$@"
    else
        [[ "$*" != *interaction-end.png* || -f "$HOME/recording" ]] || return 9
        touch "${@[-1]}"
    fi
}
source "$TOOL" sample "$HOME/base"
'''
            result = subprocess.run(["zsh", "-c", harness], env={**os.environ, "HOME": str(home),
                                    "TOOL": str(ROOT / name), "PYTHON": sys.executable},
                                    capture_output=True, text=True, timeout=10)
            events = (home / "events").read_text() if (home / "events").exists() else ""
            return result, events, (home / "takes/mission-control/sample").exists()

    def test_empty_creates_output(self):
        result, _, exists = self.shell_tool("empty.zsh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(exists)

    def test_empty_uses_selected_tree(self):
        result, events, _ = self.shell_tool("empty.zsh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("/base/.build/debug/winmux workspace 2", events)
        self.assertIn("focus --window-id 918", events)

    def test_empty_exits_with_chord(self):
        result, events, _ = self.shell_tool("empty.zsh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(events.count("arrow-chord up"), 2)
        self.assertNotIn("kp:esc", events)

    def test_interact_creates_output_and_records_through_last_capture(self):
        result, events, exists = self.shell_tool("interact.zsh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(exists)
        self.assertIn("focus --window-id 918", events)


if __name__ == "__main__":
    unittest.main()
