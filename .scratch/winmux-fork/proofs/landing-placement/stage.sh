#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
checkout=${1:?checkout directory}
label=${2:?capture label}
proof=$HOME/demo/landing76
mkdir -p "$proof/config/winmux" "$proof/state-$label" "$HOME/takes/landing76"
pkill -x WinMuxApp || true
sleep 2
pkill -x LandingStage || true
sleep 1
cat > "$proof/config/winmux/winmux.ncl" <<'CONFIG'
let W = import "winmux/winmux.ncl" in
{
  enable-normalization-flatten-containers = false,
  enable-normalization-opposite-orientation-for-nested-containers = false,
  workspace-sidebar.enabled = false,
  on-focused-monitor-changed = [],
  workspace."1".columns.count = 3,
  columns.place = fun w ctx cols => { column = 2, overflow = 'tab-group },
  lenses.overview.sort = ['title],
} | W.Config
CONFIG
XDG_CONFIG_HOME="$proof/config" XDG_STATE_HOME="$proof/state-$label" WINMUX_NICKEL_HELPER="$checkout/nickel-helper/target/release/winmux-nickel" nohup "$checkout/.build/debug/WinMuxApp" > "$proof/$label-app.log" 2>&1 &
sleep 8
nohup "$proof/LandingStage" Red Blue Green Orange > "$proof/$label-stage.log" 2>&1 &
# Read-only commands cancel the refresh on the base. Let registration finish first.
sleep 8
W=$checkout/.build/debug/winmux
$W list-windows --all --format '%{window-id}|%{window-title}|%{workspace}|%{window-parent-container-layout}' > "$proof/$label-initial.txt"
cat "$proof/$label-initial.txt"
id() { awk -F'|' -v title="$1" '$2 == title { print $1; exit }' "$proof/$label-initial.txt"; }
for title in Red Blue Green Orange; do test -n "$(id "$title")"; done
$W move-node-to-workspace --window-id "$(id Orange)" 2
$W move-node-to-column 1 --window-id "$(id Red)"
$W close --window-id "$(id Green)"
sleep 3
$W workspace 1
$W focus --window-id "$(id Red)"
sleep 2
{
  echo 'Flattening off: two windows shared Column 2; close one, leaving the survivor in a tab group.'
  $W list-columns --json
  $W list-windows --all --format '%{window-title}|%{workspace}|%{window-parent-container-layout}'
  $W place --dry-run --window-id "$(id Blue)" --json
} > "$HOME/takes/landing76/$label-container.txt"
cat "$HOME/takes/landing76/$label-container.txt"
screencapture -x "$HOME/takes/landing76/$label-staged.png"
