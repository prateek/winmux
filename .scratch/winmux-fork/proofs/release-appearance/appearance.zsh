#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
W=$HOME/winmux/.build/debug/winmux
K=$HOME/peek-proof/keys-check
key() { $K 0 ~/captures/final/$1.events.json "${@:2}"; }
mode() { osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1"; sleep 1; }
original_dark=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
restore_appearance() {
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $original_dark" >/dev/null
  osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' > ~/captures/final/ending-dark-mode.txt
}
trap restore_appearance EXIT
mode false
$W lens search --search read
key snapshot-light wait:0.3 snap:final/auto-before-system-change
mode true
key snapshot-stays wait:0.3 snap:final/auto-stays-light
key close tap:escape tap:escape
$W lens search --search read
key snapshot-next wait:0.3 snap:final/auto-next-open-dark
key close tap:escape tap:escape
mode false
travel=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Travel list" {print $1}')
reading=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Reading notes" {print $1}')
$W move-node-to-workspace --window-id "$travel" 2
$W workspace 2
$W workspace 1
$W focus --window-id "$reading"
$W lens recent --presentation grid --search travel
key light-hints wait:0.4 down:alt snap:final/light-hints-badges up:alt tap:escape
key capture down:ctrl down:alt tap:g wait:0.4 down:shift tap:g up:shift tap:space wait:1 snap:final/light-grid-peek-capture up:alt up:ctrl snap:final/grid-capture-release
python3 - <<'PY'
import json
from pathlib import Path
p=Path.home()/'captures/final'
a=json.load(open(p/'light-grid-peek-capture.trace.json'))[-1]['session']
b=json.load(open(p/'grid-capture-release.trace.json'))[-1]['session']
assert a['peek'] is not None and a['peekCaptureMs']>0, a
assert not b['active'] and b['peek'] is None, b
print('PASS light grid full-size capture',a['peekCaptureMs'],'ms; release clears peek')
PY
$W move-node-to-workspace --window-id "$travel" 1
$W workspace 1
$W list-windows --all > ~/captures/final/supplement-ending-windows.txt
osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' > ~/captures/final/ending-dark-mode.txt
