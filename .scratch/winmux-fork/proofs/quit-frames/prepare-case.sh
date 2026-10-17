#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
case_name=$1
source_dir=${2:-$HOME/winmux}
config_name=${3:-on}
mkdir -p "$HOME/quit-proof/$case_name" "$HOME/demo/quit-config/winmux" "$HOME/demo/quit-state"
pkill -x WinMuxApp || true
sleep 3
pkill -x stage || true
sleep 1
cp "$HOME/quit-tools/$config_name.ncl" "$HOME/demo/quit-config/winmux/winmux.ncl"
cd "$source_dir"
nohup "$HOME/quit-tools/stage" Red Blue Green Yellow Violet > "$HOME/quit-proof/$case_name/stage.log" 2>&1 &
sleep 3
"$HOME/quit-tools/frames" > "$HOME/quit-proof/$case_name/before.json"
screencapture -x "$HOME/quit-proof/$case_name/before.png"
export XDG_CONFIG_HOME=$HOME/demo/quit-config XDG_STATE_HOME=$HOME/demo/quit-state
export WINMUX_NICKEL_HELPER=$source_dir/nickel-helper/target/release/winmux-nickel
nohup .build/debug/WinMuxApp > "$HOME/quit-proof/$case_name/winmux.log" 2>&1 &
echo $! > "$HOME/quit-proof/$case_name/pid"
sleep 12
W=$source_dir/.build/debug/winmux
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$HOME/quit-proof/$case_name/startup.txt"
while IFS='|' read -r id app title workspace; do
  [[ "$app" == stage ]] || continue
  case "$title" in Blue|Yellow) $W move-node-to-workspace --window-id "$id" 2 ;; esac
done < "$HOME/quit-proof/$case_name/startup.txt"
$W workspace 2
$W workspace 1
sleep 3
echo 'open Late' > /tmp/stage/command
sleep 5
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$HOME/quit-proof/$case_name/tiled.txt"
"$HOME/quit-tools/frames" > "$HOME/quit-proof/$case_name/tiled.json"
screencapture -x "$HOME/quit-proof/$case_name/tiled.png"
echo "Ready: $case_name"
