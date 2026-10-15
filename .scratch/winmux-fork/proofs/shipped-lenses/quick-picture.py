"""Show the actual empty event log and quick-tap trace in the owned terminal."""
from probe import *

rows = data('list-windows', '--all', '--json')
terminal = next(row for row in rows if row['app-name'] == 'Ghostty')
command('focus', '--window-id', str(terminal['window-id']))
line = '''clear; printf '$ Lens events subscribed during the quick tap:\\n'; cat ~/takes/app-windows/quick-lens-events.jsonl; printf '$ wc -c quick-lens-events.jsonl\\n'; wc -c < ~/takes/app-windows/quick-lens-events.jsonl; printf '\\n$ winmux debug-lens-trace --last 1 (signal)\\n'; ~/winmux/.build/debug/winmux debug-lens-trace --last 1 | head -1; printf '\\n$ Focus read back after the quick tap:\\n'; cat ~/takes/app-windows/quick-tap-focused.json'''
subprocess.run(['pbcopy'], input=line, text=True, check=True)
keys('down:cmd', 'tap:v', 'up:cmd', 'tap:return', 'wait:1')
capture('quick-tap-empty-events-and-trace')
readback('quick-tap-empty-events-and-trace')
