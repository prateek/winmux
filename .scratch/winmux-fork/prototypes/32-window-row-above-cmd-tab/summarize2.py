#!/usr/bin/env python3
"""Summarize the follow-up run's opening-relative clocks, one row per opening."""
import json
import statistics
import sys
from collections import Counter

records = []
for line in open(sys.argv[1]):
    try:
        records.append(json.loads(line))
    except ValueError:
        pass


def stats(values):
    return {'n': len(values), 'min_ms': round(min(values), 3),
            'median_ms': round(statistics.median(values), 3), 'max_ms': round(max(values), 3)}


openings = []
for session in range(1, 13):
    rows = [record for record in records if record.get('session') == session]
    created = next(record for record in rows if record['event'] == 'list-created')
    read = next(record for record in rows if record['event'] == 'session-open')
    shown = next(record for record in rows if record['event'] == 'row-show')
    started = next(record for record in rows if record['event'] == 'snapshot-start')
    snapshot = next(record for record in rows if record['event'] == 'snapshot')
    key = next(record for record in rows if record['event'] == 'tab')
    openings.append({'session': session, 'created_ms': created['tabMs'], 'read_ms': read['tabMs'],
                     'row_ms': shown['tabMs'], 'lag_ms': shown['readLagMs'], 'snapshot_ms': snapshot['ms'],
                     'snapshot_start_ms': (started['time'] - key['stamp']) * 1000})
print(json.dumps({'openings': [{k: round(v, 3) if isinstance(v, float) else v for k, v in row.items()} for row in openings],
                  'summary': {key: stats([row[key] for row in openings]) for key in openings[0] if key != 'session'},
                  'snapshots': dict(Counter(record['session'] for record in records if record['event'] == 'snapshot')),
                  'overlap': sum(record['intersects'] for record in records if record['event'] == 'row-show'),
                  'key_panel': sum(record['key'] for record in records if record['event'] == 'row-show'),
                  'quick': [record for record in records if record.get('session') == 13]}, indent=2))
