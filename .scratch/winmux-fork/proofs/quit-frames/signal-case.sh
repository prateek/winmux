#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/quit-proof/signal
mkdir -p "$out"
pid=$(pgrep -x WinMuxApp)
"$HOME/quit-tools/quit" "$pid"
sleep 3
nohup "$HOME/quit-tools/stage" Red Blue Green Yellow Violet > "$out/stage.log" 2>&1 &
sleep 3
"$HOME/quit-tools/frames" > "$out/before.json"
screencapture -x "$out/before.png"
cp "$HOME/quit-tools/on.ncl" "$HOME/demo/quit-config/winmux/winmux.ncl"
export XDG_CONFIG_HOME=$HOME/demo/quit-config XDG_STATE_HOME=$HOME/demo/quit-state
export WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
cd "$HOME/winmux"
nohup .build/debug/WinMuxApp > "$out/winmux.log" 2>&1 &
echo $! > "$out/pid"
sleep 15
W=$HOME/winmux/.build/debug/winmux
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/startup.txt"
while IFS='|' read -r id app title workspace; do
  target=1
  case "$app" in
    Ghostty) target=2 ;;
    Safari) target=3 ;;
    stage) case "$title" in Blue|Yellow) target=2 ;; Green|Violet) target=3 ;; esac ;;
  esac
  $W move-node-to-workspace --window-id "$id" "$target"
done < "$out/startup.txt"
$W workspace 2
$W workspace 3
$W workspace 1
sleep 3
echo 'open Late' > /tmp/stage/command
sleep 5
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/tiled.txt"
"$HOME/quit-tools/frames" > "$out/tiled.json"
screencapture -x "$out/tiled.png"
bash "$HOME/quit-tools/finish-case.sh" signal signal
