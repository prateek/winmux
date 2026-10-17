import json
import sys

rows = [row for row in json.load(open(sys.argv[1])) if row['app'] == 'stage' and row['title']]
assert len(rows) == 6, rows
expected = dict(X=380, Y=int(sys.argv[2]), Width=520, Height=392)
for row in rows:
    assert row['onscreen'] and row['bounds'] == expected, row
    print('centered:', row['title'], row['bounds'])
