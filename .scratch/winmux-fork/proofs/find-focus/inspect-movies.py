import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
results = []
for movie in sorted(root.glob("*.mov")):
    frames = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_frames",
        "-show_entries", "frame=best_effort_timestamp_time", "-of", "json", str(movie),
    ]))["frames"]
    pixels = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(movie), "-vf", "scale=320:180,format=rgb24",
        "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
    ])
    size = 320 * 180 * 3
    assert len(pixels) == len(frames) * size
    counts = []
    for offset in range(0, len(pixels), size):
        frame = pixels[offset:offset + size]
        counts.append(sum(b > 100 and b - max(r, g) > 40
                          for r, g, b in zip(frame[::3], frame[1::3], frame[2::3])))
    best = max(range(len(counts)), key=counts.__getitem__)
    assert counts[best] > 100, f"No marked frame found in {movie}"
    timestamp = frames[best]["best_effort_timestamp_time"]
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-i", str(movie), "-ss", timestamp,
        "-frames:v", "1", str(movie.with_suffix(".frame.png")),
    ], check=True)
    results.append({"movie": movie.name, "frame": timestamp, "bluePixels": counts[best], "frames": len(frames)})
print(json.dumps(results, indent=2))
