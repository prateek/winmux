"""Match Dock AX thumbnail rectangles to the independently saved CG window sizes."""
import json
from pathlib import Path
import re
import sys

frames = json.loads(Path(sys.argv[1]).read_text())
pattern = re.compile(r'^ {4,5}Optional\(AXButton\) \| Optional\((.*?)\) \| .*?x:([\d.-]+) y:([\d.-]+).*?w:([\d.-]+) h:([\d.-]+)', re.MULTILINE)
thumbnails = []
for line in Path(sys.argv[2]).read_text().splitlines():
    match = pattern.search(line)
    if not match:
        continue
    title, x, y, width, height = match.groups()
    width, height = float(width), float(height)
    candidates = []
    for frame in frames:
        if frame['title'] != title:
            continue
        if frame['width'] <= 0 or frame['height'] <= 0:
            print(f'skip zero-size frame: {title!r} id={frame.get("id", "unknown")}')
            continue
        candidates.append(frame)
    if candidates:
        real = min(candidates, key=lambda f: abs(f['width'] / f['height'] - width / max(1, height)))
        ratio = (width / real['width'] + height / real['height']) / 2
        thumbnails.append(ratio)
        print(f'{title}: {width:g}x{height:g} / {real["width"]:g}x{real["height"]:g} = {ratio:.2%} linear')
    else:
        print(f'overlay or unmatched: {title!r} {width:g}x{height:g}')
rows = [line for line in Path(sys.argv[2]).read_text().splitlines()
        if re.match(r'^ {4,5}Optional\(AXButton\)', line) and 'add desktop' not in line]
print(f'{len(thumbnails)} matched application thumbnails; {len(rows)} total thumbnails including unnamed panels')
if thumbnails:
    print(f'linear share range {min(thumbnails):.2%}..{max(thumbnails):.2%}')
if frames:
    x1 = min(f['x'] for f in frames)
    y1 = min(f['y'] for f in frames)
    x2 = max(f['x'] + f['width'] for f in frames)
    y2 = max(f['y'] + f['height'] for f in frames)
    print(f'window bounding box: {x1:g},{y1:g} .. {x2:g},{y2:g} ({x2-x1:g}x{y2-y1:g})')
