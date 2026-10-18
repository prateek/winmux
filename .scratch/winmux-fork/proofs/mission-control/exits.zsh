#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/mission-control/exits
mkdir -p "$out"

snapshot() {
    screencapture -x "$out/$1.png"
    ~/mission-control/parking ax > "$out/$1.ax.txt"
    ~/mission-control/chrome > "$out/$1.chrome.json"
}
check_chrome() {
    python3 - "$out/$1.chrome.json" "$2" <<'PY'
import json, sys
from pathlib import Path
panels = json.load(open(sys.argv[1]))
chrome = [p for p in panels if p['kCGWindowLayer'] in (0, 27)]
ax = Path(sys.argv[1].replace('.chrome.json', '.ax.txt')).read_text()
overview = 'Optional(Mission Control)' in ax or 'Optional(App Expose)' in ax
print(sys.argv[1], 'chrome:', len(chrome))
assert bool(chrome) == (sys.argv[2] == 'shown'), chrome
assert overview == (sys.argv[2] == 'hidden'), 'unexpected Dock view'
PY
}
click_thumbnail() {
    local point
    point=$(python3 - "$out/$1.ax.txt" <<'PY'
import re, sys
for line in open(sys.argv[1]):
    if 'Optional(AXButton) | Optional(Fixed Columns)' not in line:
        continue
    x,y,w,h = map(float, re.search(r'x:([\d.-]+) y:([\d.-]+).*?w:([\d.-]+) h:([\d.-]+)', line).groups())
    print(f'{round(x+w/2)},{round(y+h/2)}')
    break
else:
    raise SystemExit('no Fixed Columns thumbnail')
PY
)
    cliclick ku:fn "c:$point" m:1880,1070
}

$W workspace 2
sleep 4
for exit in chord escape click; do
    ~/mission-control/parking save "$out/mc-$exit-open.frames.json"
    ~/mission-control/arrow-chord up
    sleep 3
    $W balance-sizes
    sleep 3
    snapshot "mc-$exit-open"
    check_chrome "mc-$exit-open" hidden
    case $exit in
        chord) ~/mission-control/arrow-chord up; cliclick ku:fn ;;
        escape) cliclick ku:fn kp:esc ;;
        click) click_thumbnail "mc-$exit-open" ;;
    esac
    sleep 3
    snapshot "mc-$exit-closed"
    check_chrome "mc-$exit-closed" shown
done

for exit in chord escape click; do
    ~/mission-control/parking save "$out/expose-$exit-open.frames.json"
    ~/mission-control/arrow-chord down
    sleep 3
    $W balance-sizes
    sleep 3
    snapshot "expose-$exit-open"
    check_chrome "expose-$exit-open" hidden
    case $exit in
        chord) ~/mission-control/arrow-chord down; cliclick ku:fn ;;
        escape) cliclick ku:fn kp:esc ;;
        click) click_thumbnail "expose-$exit-open" ;;
    esac
    sleep 3
    snapshot "expose-$exit-closed"
    check_chrome "expose-$exit-closed" shown
done

pgrep -x Dock > "$out/dock-before.txt"
~/mission-control/arrow-chord up
sleep 3
snapshot dock-before-restart
check_chrome dock-before-restart hidden
killall Dock
sleep 8
pgrep -x Dock > "$out/dock-after.txt"
snapshot dock-restarted
check_chrome dock-restarted shown
~/mission-control/arrow-chord up
sleep 3
$W workspace 3
sleep 3
snapshot dock-reattached
check_chrome dock-reattached hidden
~/mission-control/arrow-chord up
cliclick ku:fn
sleep 3
$W workspace 2
sleep 3
snapshot dock-final
check_chrome dock-final shown
$W list-workspaces --focused > "$out/workspace-end.txt"
$W list-windows --all --json > "$out/windows-end.json"
