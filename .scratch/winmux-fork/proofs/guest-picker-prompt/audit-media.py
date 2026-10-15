#!/usr/bin/env python3
import concurrent.futures
import json
from pathlib import Path
import struct
import subprocess

out = Path.home() / 'takes/accept'
assert (out / 'captures.log').read_text().rstrip().endswith('DONE'), 'capture loop is still running'
stills = sorted(out.glob('still-*.png'))
videos = sorted(out.glob('video-*.mov'))
errors = []
for path in stills:
    with path.open('rb') as stream:
        header = stream.read(24)
    if len(header) < 24 or header[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', header[16:24]) != (1280, 720):
        errors.append(path.name + ': invalid PNG or dimensions')


def inspect(path):
    result = subprocess.run(['/opt/homebrew/bin/ffprobe', '-v', 'error', '-count_packets', '-show_entries',
                             'format=duration:stream=codec_type,width,height,nb_read_packets', '-of', 'json', str(path)],
                            capture_output=True, text=True, timeout=15)
    if result.returncode:
        return path.name, None, result.stderr.strip()
    data = json.loads(result.stdout)
    duration = float(data.get('format', {}).get('duration', 0))
    valid = any(s.get('codec_type') == 'video' and s.get('width') == 1280 and s.get('height') == 720 and int(s.get('nb_read_packets', 0)) > 0
                for s in data.get('streams', []))
    return path.name, duration, None if valid and duration > 0 else 'missing video or duration'


with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(inspect, videos))
for name, _, error in results:
    if error:
        errors.append(name + ': ' + error)
summary = {'stills': len(stills), 'videos': len(videos),
           'video_duration_min': min((d for _, d, e in results if not e), default=0),
           'video_duration_max': max((d for _, d, e in results if not e), default=0),
           'errors': errors}
(out / 'media-audit.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary))
raise SystemExit(bool(errors) or len(stills) != 900 or len(videos) != 100)
