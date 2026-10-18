#!/usr/bin/env python3
"""Save release-relative film frames alongside the independent focus samples."""
import json
import pathlib
import subprocess
import sys
from PIL import Image, ImageDraw

movie = pathlib.Path(sys.argv[1])
records = [json.loads(line) for line in movie.with_suffix('.jsonl').read_text().splitlines() if line.startswith('{')]
release = next(record['time'] for record in records if record['event'] == 'session-close')
metadata = json.loads(pathlib.Path(str(movie) + '.clock.json').read_text())
origin = metadata['firstPTS']
offsets = [-100, 0, 100, 200, 300, 400, 600, 800]
indices = [round((release + offset / 1000 - origin) * 60) for offset in offsets]
selector = '+'.join(f'eq(n,{index})' for index in indices)
data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(movie), '-vf', f"select='{selector}',scale=720:405", '-fps_mode', 'vfr', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
size = 720 * 405 * 3
assert len(data) == len(indices) * size
sheet = Image.new('RGB', (1440, 4 * 430), 'white')
draw = ImageDraw.Draw(sheet)
for slot, (index, offset) in enumerate(zip(indices, offsets)):
    x, y = slot % 2 * 720, slot // 2 * 430
    sheet.paste(Image.frombytes('RGB', (720, 405), data[slot * size:(slot + 1) * size]), (x, y + 25))
    draw.text((x + 5, y + 5), f'frame {index}; release {offset:+} ms', fill='black')
sheet.save(movie.with_suffix('.release.png'))
print(json.dumps({'releaseBootSeconds': release, 'frames': dict(zip(offsets, indices))}, indent=2))
