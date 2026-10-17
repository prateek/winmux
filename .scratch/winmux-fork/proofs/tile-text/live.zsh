#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
tree=${1:?source tree}
label=${2:?base or head}
proof=$HOME/tile-proof
out=$HOME/tile-captures/$label
work=$HOME/demo/tile-text-$label
W=$tree/.build/debug/winmux
mkdir -p "$out" "$work/config" "$work/state" "$work/apps"
cleanup() {
  pkill -x WinMuxApp || true
  sleep 2
  for executable in LongName Leaf Ink Cards; do pkill -x "$executable" || true; done
}
trap cleanup EXIT
cleanup
cp "$proof/config.ncl" "$work/config.ncl"
XDG_CONFIG_HOME="$work/config" XDG_STATE_HOME="$work/state" WINMUX_NICKEL_HELPER="$tree/nickel-helper/target/release/winmux-nickel" \
  nohup "$tree/.build/debug/WinMuxApp" --config-path "$work/config.ncl" > "$out/app.log" 2>&1 &
sleep 8
"$W" config status > "$out/config-status.txt"
python3 - "$out/config-status.txt" <<'PY'
import json, sys
status = json.load(open(sys.argv[1]))
assert status["last-error"] is None, status
PY
spawn() {
  local name=$1 executable=$2
  shift 2
  local bundle="$work/apps/$executable.app"
  mkdir -p "$bundle/Contents/MacOS"
  cp "$proof/Info.plist" "$bundle/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set CFBundleName $name" -c "Set CFBundleDisplayName $name" -c "Set CFBundleExecutable $executable" -c "Set CFBundleIdentifier org.example.winmux.tile-proof.$executable" "$bundle/Contents/Info.plist"
  cp "$HOME/tile-proof-stage" "$bundle/Contents/MacOS/$executable"
  nohup "$bundle/Contents/MacOS/$executable" "$@" > "$out/$executable.log" 2>&1 &
  sleep 3
}
long=$(printf 'W%.0s' {1..92})
spawn "$long" LongName 'prateek/winmux pull request 201: a controlled long title for the tile comparison — alpha'
spawn Leaf Leaf 'prateek/winmux pull request 203: a controlled long title for the tile comparison — omega'
spawn Ink Ink 'prateek/winmux pull request 205: a controlled long title for the tile comparison — notes'
# No WinMux command while registration's refresh is pending.
sleep 8
cliclick m:1860,1020
"$W" list-windows --all --json > "$out/three-windows.json"
python3 - "$out/three-windows.json" <<'PY'
import json, sys
windows = json.load(open(sys.argv[1]))
assert len(windows) == 3, windows
assert sorted(len(w["app-name"]) for w in windows) == [3, 4, 92], windows
PY
"$W" config status > "$out/config-status.txt"
capture() {
  local name=$1
  sleep 2
  screencapture -x "$out/$name.png"
  "$W" debug-lens-trace --json --last 1 > "$out/$name.trace.json"
  cliclick kp:esc w:200 kp:esc w:300
  "$W" debug-lens-trace --json --last 1 > "$out/$name.closed.json"
}
"$W" lens windows --presentation list --tile text --search ''
capture list
"$W" lens windows --presentation strip --tile text --search ''
capture strip
extra=()
for n in {206..216}; do
  extra+=("prateek/winmux pull request $n: a controlled long title for the tile comparison — item $n")
done
spawn Cards Cards $extra
sleep 8
"$W" list-windows --all --json > "$out/fourteen-windows.json"
python3 - "$out/fourteen-windows.json" <<'PY'
import json, sys
windows = json.load(open(sys.argv[1]))
assert len(windows) == 14, windows
assert all(80 <= len(w["window-title"]) <= 95 for w in windows), windows
PY
"$W" lens windows --presentation grid --tile card --search ''
capture grid
"$W" list-windows --all --lens windows --search pr --json > "$out/search-matches.json"
"$W" lens windows --presentation grid --tile card --search pr
capture search
"$W" list-windows --all --json > "$out/ending-windows.json"
