#!/usr/bin/env python3
"""Compare a trace with a timestamped movie. Requires ffmpeg, ffprobe and Pillow.

check-lens-film.py TAKE.mov TRACE.json --probe x,y,w,h --threshold .25
The probe is chosen inside the strip after inspecting its first visible PNG.
A changed-pixel fraction detects the panel rather than waiting for fresh pictures.
"""
import argparse
import bisect
import json
import pathlib
import subprocess


def compare(frames, first_pts, keys, traces, visible):
    if not len(keys) == len(traces) == len(visible):
        raise ValueError("key, trace and visible-frame counts differ")
    rows = []
    for key, trace, index in zip(keys, traces, visible):
        pressed = key['bootSeconds'] - first_pts
        delay = (frames[index] - pressed) * 1000
        total = trace['totalMs']
        trace_index = bisect.bisect_left(frames, pressed + total / 1000)
        rows.append(dict(opening=trace['id'], keySeconds=pressed, frame=index,
                         frameSeconds=frames[index], visibleMs=delay, traceMs=total,
                         differenceMs=delay-total, differenceFrames=index-trace_index))
    return rows


def validate_sample_times(encoded, metadata):
    expected = [time - metadata['firstPTS'] for time in metadata['framePTS']]
    if len(encoded) != len(expected):
        raise ValueError('encoded frame count differs from clock metadata')
    if any(b < a for a, b in zip(encoded, encoded[1:])):
        raise ValueError('encoded timestamps went backwards')
    if any(abs(actual - wanted) > .002 for actual, wanted in zip(encoded, expected)):
        raise ValueError('encoded timestamps differ from measured receipt times')


def main():
    from PIL import Image, ImageChops
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('movie', type=pathlib.Path)
    parser.add_argument('traces', type=pathlib.Path)
    parser.add_argument('--probe', required=True, help='x,y,width,height')
    parser.add_argument('--threshold', type=float, default=0.25, help='fraction of pixels changed by >20 levels')
    args = parser.parse_args()
    movie = args.movie
    metadata = json.loads(pathlib.Path(str(movie)+'.clock.json').read_text())
    raw = movie.with_name(movie.stem + ".raw.mov")
    raw_frames = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_frames", "-of", "json", str(raw)]))["frames"]
    validate_sample_times([float(frame["best_effort_timestamp_time"]) for frame in raw_frames], metadata)
    events = json.loads(movie.with_suffix('.events.json').read_text())
    keys = [event for event in events if event['keys'] == '⌘ Tab']
    traces = [trace for trace in json.loads(args.traces.read_text()) if trace['presentation'] == 'strip'][-len(keys):]
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-show_streams', '-of', 'json', str(movie)]))
    frames = [float(frame['best_effort_timestamp_time']) for frame in probe['frames']]
    stream = probe['streams'][0]
    print(f"File rate: r_frame_rate={stream['r_frame_rate']}, avg_frame_rate={stream['avg_frame_rate']}; {len(frames)} frames; comparisons use actual frame PTS")
    offset = metadata['firstPTS'] - frames[0]
    if stream['r_frame_rate'] != '60/1' or stream['avg_frame_rate'] != '60/1':
        raise ValueError('trace-film must supply a constant 60 fps movie')
    for index, time in enumerate(frames):
        if abs(time - frames[0] - index / 60) > .001:
            raise ValueError('movie frame spacing differs from 60 fps')
    out = movie.with_suffix('.frames'); out.mkdir(exist_ok=True)
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(movie), '-fps_mode', 'passthrough', str(out/'%06d.png')], check=True)
    x,y,w,h = map(int, args.probe.split(','))
    crop = (x,y,x+w,y+h)
    images = sorted(out.glob('*.png'))
    visible = []
    for key in keys:
        pressed = key['bootSeconds'] - offset
        baseline_index = max(0, bisect.bisect_left(frames, pressed)-1)
        baseline = Image.open(images[baseline_index]).convert('RGB').crop(crop)
        found = None
        for index in range(baseline_index+1, len(frames)):
            if frames[index] > pressed+1.5: break
            candidate = Image.open(images[index]).convert('RGB').crop(crop)
            difference = ImageChops.difference(candidate, baseline)
            pixels = list(difference.get_flattened_data())
            changed = sum(max(pixel)>20 for pixel in pixels)/len(pixels)
            if changed >= args.threshold:
                found = index; break
        if found is None: raise ValueError('no Presentation found within 1.5 s')
        visible.append(found)
    rows = compare(frames, offset, keys, traces, visible)
    for row in rows:
        print(f"Opening {row['opening']}: key {row['keySeconds']:.6f}s; strip frame {row['frame']} @ {row['frameSeconds']:.6f}s; visible {row['visibleMs']:.3f}ms; trace {row['traceMs']:.3f}ms; difference {row['differenceMs']:+.3f}ms / {row['differenceFrames']:+d} frames")
    movie.with_suffix('.comparison.json').write_text(json.dumps(rows, indent=2)+'\n')
    if any(trace.get('signal') is None for trace in traces): raise SystemExit('FAIL: incomplete first-frame trace')
    if any(abs(row['differenceMs']) > 2000/60 or abs(row['differenceFrames'])>2 for row in rows): raise SystemExit('FAIL: trace differs by more than two frames')


if __name__ == '__main__': main()
