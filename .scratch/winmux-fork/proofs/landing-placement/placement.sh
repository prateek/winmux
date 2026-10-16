#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
checkout=${1:?checkout directory}
label=${2:?capture label}
proof=$HOME/demo/landing76
captures=$HOME/takes/landing76
W=$checkout/.build/debug/winmux
blue=$(awk -F'|' '$2 == "Blue" { print $1; exit }' "$proof/$label-initial.txt")
for policy in float squeeze; do
  python3 - "$proof/config/winmux/winmux.ncl" "$policy" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
path.write_text(re.sub(r"overflow = '[a-z-]+", "overflow = '" + sys.argv[2], path.read_text()))
PY
  sleep 3
  {
    echo "Flattening off, Overflow $policy; Blue is the only leaf of its tab-group Column."
    $W list-columns --json
    $W list-windows --all --format '%{window-title}|%{workspace}|%{window-parent-container-layout}'
    $W place --dry-run --window-id "$blue" --json
    echo 'Trying layout tiling on the already tiled survivor (this is a no-op before relayoutWindow).'
    $W layout tiling --window-id "$blue" || echo "Already tiled: command declined the no-op before calling Place."
    sleep 1
    $W list-columns --json
    $W list-windows --all --format '%{window-title}|%{workspace}|%{window-parent-container-layout}'
  } > "$captures/$label-container-$policy.txt"
done
sed -i '' 's/enable-normalization-flatten-containers = false/enable-normalization-flatten-containers = true/' "$proof/config/winmux/winmux.ncl"
sleep 3
{
  echo 'Flattening on, Columns unchanged, Overflow squeeze.'
  $W list-columns --json
  $W list-windows --all --format '%{window-title}|%{workspace}|%{window-parent-container-layout}'
  $W place --dry-run --window-id "$blue" --json
} > "$captures/$label-flattening-on.txt"
screencapture -x "$captures/$label-flattening-on.png"
