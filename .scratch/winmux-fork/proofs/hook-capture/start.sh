#!/bin/bash
export TART_HOME="${TART_HOME:?Set TART_HOME before running this proof}"
set -euo pipefail
tree=${1:-"$HOME/winmux"}
mkdir -p "$HOME/demo/hook-config" "$HOME/demo/hook-state" "$HOME/takes/hook-capture"
cp "$HOME/hook-proof/config.ncl" "$HOME/demo/hook-active.ncl"
nohup env XDG_CONFIG_HOME="$HOME/demo/hook-config" XDG_STATE_HOME="$HOME/demo/hook-state" \
  WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel" \
  "$tree/.build/debug/WinMuxApp" --config-path "$HOME/demo/hook-active.ncl" \
  > "$HOME/takes/hook-capture/app.log" 2>&1 < /dev/null &
sleep 20
"$tree/.build/debug/winmux" config status
