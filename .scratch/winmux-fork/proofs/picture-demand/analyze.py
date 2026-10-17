#!/usr/bin/env python3
import datetime, json, math, pathlib, re, statistics, sys
root = pathlib.Path(sys.argv[1])
rows = []
pending = {}
for line in (root/'captures.ndjson').read_text().splitlines():
    try: row = json.loads(line)
    except ValueError: continue
    text = row.get('eventMessage', '')
    delivered = re.search(r'thumbnail captured id=(\d+) pixels=(\d+)x(\d+)', text)
    if delivered:
        key=(row['processID'],int(delivered[1]))
        if key in pending: pending[key]['actual'] = [int(delivered[2]),int(delivered[3])]
        continue
    size = re.search(r'size=\(([^)]+)\)', text)
    frame = re.search(r'frame=\(([^)]+)\)', text)
    demand = re.search(r'demand=\(([^)]+)\)', text)
    if not size or not frame: continue
    rows.append(dict(pid=row['processID'], time=datetime.datetime.strptime(row['timestamp'], '%Y-%m-%d %H:%M:%S.%f%z').timestamp(),
                     size=list(map(float, size[1].split(','))), frame=list(map(float, frame[1].split(','))),
                     demand=list(map(float,demand[1].split(','))) if demand else None, text=text))
    pending[(row['processID'],int(re.search(r'id=(\d+)',text)[1]))]=rows[-1]
print('| Windows | Build | Outside MiB | Grid MiB | Closed MiB | Largest grid capture |')
print('|---|---|---:|---:|---:|---|')
for count in [3, 40]:
    for build in ['base', 'branch']:
        values = {phase: [] for phase in ['outside','grid','closed']}
        largest = (0,0)
        for trial in [1,2,3]:
            label=f'{build}-{count}-{trial}'
            phases=json.loads((root/(label+'-phases.json')).read_text())
            for phase in values:
                memory=(root/(label+'-'+phase+'-memory.txt')).read_text()
                match=re.search(r'^Physical footprint:\s*([\d.]+)([KMG])',memory,re.M)
                values[phase].append(float(match[1])*{'K':1/1024,'M':1,'G':1024}[match[2]])
            captures=[r for r in rows if r['pid']==phases['pid'] and phases['gridStart'] <= r['time'] <= phases['gridEnd']]
            print(label, 'grid captures',len(captures), 'windows',len(set(re.findall(r'id=(\d+)',r['text'])[0] for r in captures)), file=sys.stderr)
            for capture in captures:
                w,h=capture['size']; fw,fh=capture['frame'][2:]
                actual=capture.get('actual')
                assert actual is not None, capture
                assert actual[0] <= math.ceil(fw) and actual[1] <= math.ceil(fh), capture
                assert w <= fw+0.001 and h <= fh+0.001, capture
                if build=='branch':
                    dw,dh=capture['demand']
                    assert w+0.001 >= dw and h+0.001 >= dh, capture
                    if count==40:
                        assert abs(w-dw)<0.001 and abs(h-dh)<0.001, capture
                assert actual == [math.ceil(w), math.ceil(h)], capture
                if actual[0]*actual[1] > largest[0]*largest[1]: largest=tuple(actual)
        print(f'| {count} | {build} | '+ ' | '.join(f'{statistics.median(values[p]):.1f}' for p in values) +f' | {largest[0]} × {largest[1]} |')
