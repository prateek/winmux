import json
import subprocess
import sys

movie = sys.argv[1]
x, y = map(int, sys.argv[2:4]) if len(sys.argv) == 4 else (670, 300)
probe = json.loads(subprocess.check_output([
    "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_frames",
    "-show_entries", "frame=best_effort_timestamp_time", "-of", "json", movie,
]))
pixels = subprocess.check_output([
    "ffmpeg", "-v", "error", "-i", movie, "-vf", f"format=rgb24,crop=1:1:{x}:{y}",
    "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
])
frames = probe["frames"]
assert len(pixels) == len(frames) * 3
samples = []
for i, frame in enumerate(frames):
    r, g, b = pixels[i * 3:i * 3 + 3]
    samples.append((float(frame["best_effort_timestamp_time"]), b - max(r, g)))
peak = max(value for _, value in samples)
baseline = samples[0][1]
marked = [(t, value) for t, value in samples if value > baseline + (peak - baseline) * 0.02]
full = [(t, value) for t, value in marked if value >= baseline + (peak - baseline) * 0.95]
print(json.dumps({
    "movie": movie, "sample": [x, y], "frames": len(frames), "peakBlueExcess": peak,
    "firstMarked": marked[0][0], "lastFull": full[-1][0], "lastMarked": marked[-1][0],
    "fullHoldFromFirstFrame": full[-1][0] - marked[0][0],
    "visibleDuration": marked[-1][0] - marked[0][0],
    "blueExcessSamples": samples,
}, indent=2))
