#!/usr/bin/env python3
"""Find candidate native/row arrivals and save neighboring frames for visual review."""
import json
import math
import pathlib
import subprocess
import sys
from PIL import Image, ImageChops, ImageDraw

movie = pathlib.Path(sys.argv[1])
metadata = json.loads(pathlib.Path(str(movie) + '.clock.json').read_text())
events = json.loads(movie.with_suffix('.events.json').read_text())
keys = [event['bootSeconds'] for event in events if event['keys'] == '⌘ Tab']
frames = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-of', 'json', str(movie)]))['frames']
pts = [float(frame['best_effort_timestamp_time']) for frame in frames]
assert all(abs(b - a - 1 / 60) < .00001 for a, b in zip(pts, pts[1:])), 'not a 60 fps timeline'
origin = metadata['firstPTS'] - pts[0]
process = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', str(movie), '-vf', 'crop=1440:340:240:310,scale=720:170', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
images = []
while True:
    data = process.stdout.read(720 * 170 * 3)
    if not data:
        break
    assert len(data) == 720 * 170 * 3
    images.append(Image.frombytes('RGB', (720, 170), data))
assert process.wait() == 0
out = movie.parent / (movie.stem + '-frames')
out.mkdir(exist_ok=True)
boxes = {'switcher': (30, 76, 690, 154), 'row': (150, 8, 570, 59)}
results = []
for opening, key in enumerate(keys, 1):
    index = max(0, math.floor((key - origin) * 60))
    baseline = images[index]
    found = {}
    metrics = []
    for i in range(index, min(index + 45, len(images))):
        values = {}
        for kind, box in boxes.items():
            difference = ImageChops.difference(images[i].crop(box), baseline.crop(box)).convert('L')
            histogram = difference.histogram()
            fraction = sum(histogram[21:]) / (difference.width * difference.height)
            values[kind] = round(fraction, 4)
            if fraction > .10 and kind not in found:
                found[kind] = i
        metrics.append({'frame': i, **values})
    assert len(found) == 2, (opening, found)
    result = {'opening': opening, 'keyFrame': index, **found, 'rowMinusSwitcherFrames': found['row'] - found['switcher']}
    results.append(result)
    first = min(found.values())
    last = max(found.values())
    chosen = range(max(first - 2, index), last + 3)
    sheet = Image.new('RGB', (720, len(chosen) * 195), '#ffffff')
    draw = ImageDraw.Draw(sheet)
    for slot, i in enumerate(chosen):
        sheet.paste(images[i], (0, slot * 195 + 25))
        draw.text((5, slot * 195 + 5), f'Opening {opening}: frame {i}; key + {(pts[i] + origin - key) * 1000:.1f} ms', fill='black')
    sheet.save(out / f'opening-{opening}.png')
    (out / f'opening-{opening}-metrics.json').write_text(json.dumps(metrics, indent=2))
print(json.dumps(results, indent=2))
