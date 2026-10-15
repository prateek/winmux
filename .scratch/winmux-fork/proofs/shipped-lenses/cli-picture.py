"""Put actual CLI output in the standing desk terminal for a readable capture."""
from probe import *

windows = data('list-windows', '--all', '--json')
terminal = next(row for row in windows if row['app-name'] == 'Ghostty')
command('focus', '--window-id', str(terminal['window-id']))
line = '''clear; W=~/winmux/.build/debug/winmux; export WINMUX_NICKEL_HELPER=~/winmux/nickel-helper/target/release/winmux-nickel; printf '\\n$ winmux list-lenses\\n'; "$W" list-lenses; printf '\\n$ winmux list-lenses --json | jq -c keys\\n'; "$W" list-lenses --json | /opt/homebrew/bin/jq -c keys; printf '\\n$ winmux config convert upstream-default-config.toml (first 8 lines)\\n'; "$W" config convert ~/winmux/nickel-helper/tests/fixtures/upstream-default-config.toml | head -8'''
subprocess.run(['pbcopy'], input=line, text=True, check=True)
keys('down:cmd', 'tap:v', 'up:cmd', 'tap:return', 'wait:2')
capture('cli-six-lenses-and-convert')
readback('cli-six-lenses-and-convert')
