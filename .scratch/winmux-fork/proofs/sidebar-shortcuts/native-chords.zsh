#!/bin/zsh
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
set -eu
label=$1
root=${2:-$HOME/winmux}
W=$root/.build/debug/winmux
out=$HOME/takes/117/$label
keys() { ~/desk/keys "$(date +%s)" "$out/native-keys-$(date +%s).json" "$@"; }
front() { osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'; }
[[ -x ~/desk/arrow-chord ]] || swiftc ~/desk/arrow-chord.swift -o ~/desk/arrow-chord
for location in over away; do
  for direction in up down; do
    pkill -x WinMuxApp || true
    sleep 2
    cliclick m:1240,714 ku:fn
    keys tap:escape
    export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state
    export WINMUX_NICKEL_HELPER=$root/nickel-helper/target/release/winmux-nickel
    nohup "$root/.build/debug/WinMuxApp" > "$out/native-fn-$location-$direction-app.log" 2>&1 &
    sleep 10
    $W workspace 1 >/dev/null
    wid=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
    $W focus --window-id "$wid"
    sleep 2
    echo "$label $location ctrl-$direction before=$(front)"
    $W list-windows --focused
    [[ $location != over ]] || cliclick m:2,360
    sleep 2
    echo "hover=$(front)"
    screencapture -x "$out/native-fn-$location-$direction-before.png"
    ~/desk/arrow-chord "$direction"
    sleep 1
    screencapture -x "$out/native-fn-$location-$direction-result.png"
    if [[ $label == head || $location == away ]]; then
      ~/desk/arrow-chord "$direction"
      sleep 2
    fi
    cliclick m:1240,714
    sleep 2
    screencapture -x "$out/native-fn-$location-$direction-after.png"
    echo "after-exit=$(front)"
    $W list-windows --focused
  done
done
