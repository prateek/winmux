#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
W=$HOME/winmux/.build/debug/winmux
K=$HOME/peek-proof/keys-check
A=$HOME/peek-proof/assert-state.py
mkdir -p ~/captures/final
starting_dark=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
print "$starting_dark" > ~/captures/final/starting-dark-mode.txt
restore_appearance() {
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $starting_dark" >/dev/null
  osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' > ~/captures/final/ending-dark-mode.txt
}
trap restore_appearance EXIT
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
key() { $K 0 ~/captures/final/$1.events.json "${@:2}"; }
check() { python3 "$A" ~/captures/final/$1.trace.json "${@:2}"; }
close_lens() { key close tap:escape tap:escape; }
prepare() {
  $W focus --window-id "$garden"
  $W focus --window-id "$reading"
}
focused_selection() {
  local selected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[-1]["session"]["selectedId"])' ~/captures/final/$1.trace.json)
  local focused=$($W list-windows --focused --format '%{window-id}')
  [[ "$selected" == "$focused" ]] || { echo "Focus $focused differs from selected $selected"; exit 1; }
  print "PASS $1 focused $focused"
}
$W config status > ~/captures/final/config-status.json
$W doctor > ~/captures/final/doctor-before.txt
garden=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Garden plan" {print $1}')
reading=$($W list-windows --all --format '%{window-id}|%{window-title}' | awk -F'|' '$2=="Reading notes" {print $1}')
[[ -n "$garden" && -n "$reading" ]]

prepare
key grid down:ctrl down:alt tap:g wait:0.4 snap:final/grid-open tap:g wait:0.2 snap:final/grid-step down:shift tap:g up:shift wait:0.2 snap:final/grid-reverse tap:g up:alt up:ctrl wait:0.4 snap:final/grid-release
check grid-open active=true hold=true 'presentation="grid"'
check grid-release active=false 'presentation="grid"' peek=null
focused_selection grid-release
python3 - <<'PY'
import json
from pathlib import Path
p=Path.home()/'captures/final'
s=lambda n:json.load(open(p/(n+'.trace.json')))[-1]['session']['selectedId']
assert s('grid-open')!=s('grid-step')
assert s('grid-open')==s('grid-reverse')
print('PASS invoking key steps and Shift reverses in a grid')
PY

key shift-only down:shift tap:g wait:0.4 snap:final/shift-only-held up:shift snap:final/shift-only-release
check shift-only-held active=true hold=true
check shift-only-release active=false
focused_selection shift-only-release

prepare
$W subscribe lens-opened lens-closed --no-send-initial > ~/captures/final/quick-tap.lens-events.jsonl &
subscriber=$!
rm -f ~/captures/final/quick-tap.mov
screencapture -x -v -V 3 ~/captures/final/quick-tap.mov > ~/captures/final/quick-tap.recorder.txt 2>&1 &
recorder=$!
sleep 0.5
key quick delay:0.002 down:ctrl down:alt tap:g up:alt up:ctrl wait:0.4 snap:final/quick-tap
kill $subscriber
wait $subscriber || true
wait $recorder
[[ ! -s ~/captures/final/quick-tap.lens-events.jsonl ]]
check quick-tap active=false
focused_selection quick-tap
python3 - <<'PY'
import json
from pathlib import Path
p=Path.home()/'captures/final/quick-tap.trace.json'
t=json.load(open(p))[-1]
assert t['signal']=='cancelled before first frame', t
assert not any(s['name']=='first frame presented' for s in t['stages'])
print('PASS quick tap: no first frame and empty Lens event subscription')
PY

key stay-enter down:ctrl down:alt tap:s wait:0.4 up:alt up:ctrl snap:final/stay-release tap:return wait:0.4 snap:final/stay-enter
check stay-release active=true hold=false 'state="normal"' 'presentation="strip"'
check stay-enter active=false
focused_selection stay-enter
key stay-escape down:ctrl down:alt tap:s wait:0.3 up:alt up:ctrl tap:escape snap:final/stay-escape
check stay-escape active=false
key stay-toggle down:ctrl down:alt tap:s wait:0.3 up:alt up:ctrl wait:0.1 down:ctrl down:alt tap:s up:alt up:ctrl snap:final/stay-toggle
check stay-toggle active=false

key stay-peek down:ctrl down:alt tap:s wait:0.4 tap:space wait:0.4 up:alt up:ctrl wait:0.3 snap:final/light-peek click:650,360 snap:final/peek-click tap:return wait:0.3
check light-peek active=true hold=false
check peek-click active=true peek=null
python3 -c 'import json; from pathlib import Path; assert json.load(open(Path.home()/"captures/final/light-peek.trace.json"))[-1]["session"]["peek"] is not None'
key grid-peek down:ctrl down:alt tap:g wait:0.3 tap:space wait:0.3 up:alt up:ctrl snap:final/grid-peek-release
check grid-peek-release active=false peek=null

key slash down:cmd tap:tab wait:0.3 tap:y wait:0.3 tap:slash snap:final/strip-to-list up:cmd snap:final/list-after-release
check strip-to-list active=true 'presentation="list"'
check list-after-release active=true 'presentation="list"' hold=false
python3 - <<'PY'
import json
from pathlib import Path
p=Path.home()/'captures/final'
a=json.load(open(p/'strip-to-list.trace.json'))[-1]['session']
b=json.load(open(p/'list-after-release.trace.json'))[-1]['session']
assert a['peek'] is not None and a['peek']==b['peek']
print('PASS strip-to-list preserves zoom and release does not commit')
PY
close_lens
close_lens

for mode in light dark; do
  [[ $mode == dark ]] && dark=true || dark=false
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"
  sleep 1
  for presentation in strip grid list; do
    $W lens recent --presentation "$presentation" --search ''
    key $mode-$presentation wait:0.5 snap:final/$mode-$presentation
    check $mode-$presentation active=true "presentation=\"$presentation\""
    close_lens
  done
done
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
sleep 1
$W lens dark-list --search ''
key forced-dark wait:0.4 snap:final/forced-dark-in-light
close_lens
$W lens overview --search ''
key miniatures wait:0.6 snap:final/light-miniatures
close_lens
$W lens search --search read
key search wait:0.3 snap:final/light-search-read
close_lens
key cmd-tab down:cmd tap:tab wait:0.4 snap:final/cmd-tab up:cmd snap:final/cmd-tab-release
check cmd-tab active=true 'presentation="strip"'
check cmd-tab-release active=false
focused_selection cmd-tab-release
$W doctor > ~/captures/final/doctor-after.txt
$W list-lenses --json > ~/captures/final/list-lenses.json
osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' > ~/captures/final/ending-dark-mode.txt
print 'PASS all release and appearance live probes'
