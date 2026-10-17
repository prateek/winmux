#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
tree=${1:?source tree}
label=${2:?base or head}
proof=$HOME/per-app-proof
out=$HOME/per-app-captures/$label
W=$tree/.build/debug/winmux
cleanup() {
  pkill -x WinMuxApp || true
  sleep 3
  pkill -x Atlas || true
  pkill -x Beacon || true
}
trap cleanup EXIT
mkdir -p "$out" "$proof/apps"
pkill -x WinMuxApp || true
sleep 3
pkill -x Atlas || true
pkill -x Beacon || true
sleep 3
XDG_CONFIG_HOME="$proof/config" XDG_STATE_HOME="$HOME/demo/state" WINMUX_NICKEL_HELPER="$tree/nickel-helper/target/release/winmux-nickel" \
  nohup "$tree/.build/debug/WinMuxApp" --config-path "$proof/config.ncl" > "$out/app.log" 2>&1 &
sleep 10
"$W" config status > "$out/config-status.json"
for workspace in 2 3 4 1; do "$W" workspace "$workspace" > /dev/null; sleep 1; done
swiftc -O "$HOME/winmux/.claude/skills/demo/stage.swift" -o "$proof/stage"
spawn() {
  local name=$1
  local bundle="$proof/apps/$name.app"
  mkdir -p "$bundle/Contents/MacOS"
  cp "$HOME/winmux/.scratch/winmux-fork/proofs/tile-text/Info.plist" "$bundle/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set CFBundleName $name" -c "Set CFBundleDisplayName $name" -c "Set CFBundleExecutable $name" \
    -c "Set CFBundleIdentifier org.example.winmux.per-app.$name" "$bundle/Contents/Info.plist"
  cp "$proof/stage" "$bundle/Contents/MacOS/$name"
  nohup "$bundle/Contents/MacOS/$name" "Blue reading desk" > "$out/$name.log" 2>&1 &
  sleep 10
}
capture() {
  local name=$1
  sleep 3
  screencapture -x "$out/$name.png"
  "$W" debug-lens-trace --json --last 1 > "$out/$name.trace.json"
  cliclick kp:esc w:500
  "$W" debug-lens-trace --json --last 1 > "$out/$name.closed.json"
}
inventory() {
  local count=$1
  # Registration gets a fixed quiet interval: read-only commands can cancel its refresh.
  sleep 8
  "$W" list-windows --all --json > "$out/$count-windows.json"
  "$W" agent query --path "$out/$count-world.json"
  "$W" list-windows --all --format '%{window-id} %{window-last-focused-seq}' > "$out/$count-mru.txt"
  sleep 2
  python3 - "$out/$count-windows.json" "$count" <<'PY'
import json, sys
windows = json.load(open(sys.argv[1]))
world = json.load(open(sys.argv[1].replace('-windows.json', '-world.json')))
processes = set(w['pid'] for w in world['inventory']['windows'])
names = sorted(set(w['app-name'] for w in windows))
assert len(processes) == int(sys.argv[2]), (names, processes)
print('App entries:', len(processes), 'Names:', ', '.join(names), 'Windows:', len(windows))
PY
}
inventory 10
cliclick m:1860,1020
"$W" lens apps
cliclick kp:arrow-right w:500
capture ten-app-strip
spawn Atlas
inventory 11
"$W" lens apps
cliclick kp:arrow-right w:500
capture eleven-app-strip
"$W" lens apps --presentation grid
capture eleven-app-grid
"$W" lens recent
capture recent-window-strip
"$W" lens recent --tile card
capture window-card-strip
"$W" list-workspaces --focused > "$out/ending-workspace.txt"
"$W" list-windows --all --json > "$out/ending-windows.json"
