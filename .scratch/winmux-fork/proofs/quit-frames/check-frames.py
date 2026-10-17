import json
import sys

before, after = (json.load(open(path)) for path in sys.argv[1:3])
after = {row['id']: row for row in after}
expected = [row for row in before if row['app'] == 'stage' and row['title']]
assert len(expected) == 5, expected
expected += [row for row in before if row['app'] in ('Zed', 'Ghostty', 'Safari', 'Notes')
             and row['title'] and row['onscreen']]
closed = sys.argv[3:]
for row in expected:
    if row['title'] in closed:
        assert row['id'] not in after or not after[row['id']]['onscreen'], after.get(row['id'])
        print('closed, not reopened:', row['title'])
        continue
    current = after[row['id']]
    assert current['bounds'] == row['bounds'], (row, current)
    assert current['onscreen'], current
    print('restored:', row['title'], current['bounds'])
late = [row for row in after.values() if row['title'] == 'Late']
assert len(late) == 1 and late[0]['onscreen'], late
bounds = late[0]['bounds']
assert 0 <= bounds['X'] + bounds['Width'] / 2 < 1280, late
assert 0 <= bounds['Y'] + bounds['Height'] / 2 < 720, late
print('new window on screen:', late[0])
