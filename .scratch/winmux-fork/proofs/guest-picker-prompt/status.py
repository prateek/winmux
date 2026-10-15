#!/usr/bin/env python3
"""Summarize the acceptance logs without touching the running app or recorders."""
import datetime as dt
import json
from pathlib import Path
import re
import subprocess

out = Path.home() / 'takes/accept'
read = lambda name: (out / name).read_text() if (out / name).exists() else ''
lenses = read('lenses.log')
decisions = read('decisions.log')
captures = re.findall(r'^capture=(\d+) kind=(\w+) status=0$', read('captures.log'), re.M)
watch = read('watch.log').splitlines()
expected = {'Ghostty', 'Notes', 'Safari', 'Zed', 'WinMuxApp'}
owners = set()
for line in watch:
    for window in line.split('windows=', 1)[-1].split('; '):
        if ' | ' in window:
            owners.add(window.split(' | ', 1)[0])
times = [dt.datetime.strptime(line[:20], '%Y-%m-%dT%H:%M:%SZ') for line in watch]
try:
    pid = subprocess.check_output(['pgrep', '-x', 'WinMuxApp'], text=True).strip()
except subprocess.CalledProcessError:
    pid = ''
print(json.dumps({
    'utc': dt.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'started': read('started.txt').strip(),
    'same_process': pid == read('app.pid').strip(),
    'pid': pid,
    'openings': len(re.findall(r'^opening=', lenses, re.M)),
    'open_readbacks': lenses.count('active=true'),
    'closed_readbacks': lenses.count('active=false'),
    'lenses_done': lenses.rstrip().endswith('DONE'),
    'captures': len(captures),
    'stills': sum(kind == 'still' for _, kind in captures),
    'videos': sum(kind == 'video' for _, kind in captures),
    'captures_done': read('captures.log').rstrip().endswith('DONE'),
    'unexpected_owners': sorted(owners - expected),
    'alert_requests': decisions.count('+[SCAlert userAcknowledgementAlertWithBundleID:]'),
    'hint_requests': decisions.count('Requesting privacy hint to be displayed'),
    'alert_windows_requested': decisions.count('+[SCAlert showAlertWithTitle:'),
    'watch_samples': len(watch),
    'watch_age_seconds': (dt.datetime.utcnow() - times[-1]).total_seconds() if times else None,
    'max_watch_gap_seconds': max(((b-a).total_seconds() for a,b in zip(times,times[1:])), default=0),
    'last_watch': watch[-1] if watch else '',
}, sort_keys=True))
