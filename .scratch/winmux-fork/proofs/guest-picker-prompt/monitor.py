#!/usr/bin/env python3
"""Host-side read-only checkpoints, with every guest read going through vm ssh."""
import datetime as dt
import json
from pathlib import Path
import subprocess
import sys
import time

vm, guest, output = sys.argv[1:]
next_poll = time.monotonic()
while True:
    result = subprocess.run([vm, 'ssh', guest, 'python3 ~/probe/status.py'],
                            capture_output=True, text=True, timeout=40)
    lines = [line for line in result.stdout.splitlines() if line.startswith('{')]
    if result.returncode or not lines:
        print('ATTENTION: checkpoint transport failed; inspect the saved stderr.', flush=True)
        Path(output + '.stderr').write_text(result.stderr)
        raise SystemExit(1)
    state = json.loads(lines[-1])
    with Path(output).open('a') as stream:
        stream.write(json.dumps(state) + '\n')
    started = dt.datetime.strptime(state['started'], '%Y-%m-%dT%H:%M:%SZ')
    now = dt.datetime.strptime(state['utc'], '%Y-%m-%dT%H:%M:%SZ')
    elapsed = (now - started).total_seconds()
    danger = (not state['same_process'] or state['unexpected_owners'] or state['alert_requests'] or
              state['hint_requests'] or state['alert_windows_requested'] or state['watch_age_seconds'] > 15 or
              (not state['lenses_done'] and elapsed > state['openings'] * 60 + 90) or
              (not state['captures_done'] and elapsed > 600))
    print(f"{state['utc']} Lens {state['closed_readbacks']}/120; captures {state['captures']}/1000; "
          f"same PID {state['same_process']}; owners {state['unexpected_owners']}; "
          f"alerts/hints {state['alert_requests']}/{state['hint_requests']}; "
          f"watch gap {state['max_watch_gap_seconds']:.0f}s" + (' ATTENTION' if danger else ''), flush=True)
    if danger:
        raise SystemExit(1)
    if state['lenses_done'] and state['captures_done']:
        print('DONE: both required run durations/counts completed.', flush=True)
        break
    next_poll += 50
    time.sleep(max(0, next_poll - time.monotonic()))
