#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
tree=${1:?source tree}
out=$HOME/safari-captures/head-flip
W=$tree/.build/debug/winmux
mkdir -p "$out"
old=$(defaults read -g doubleSidedWindows 2>/dev/null || echo absent)
restore() {
    if [[ $old == absent ]]; then defaults delete -g doubleSidedWindows; else defaults write -g doubleSidedWindows -bool "$old"; fi
    [[ -z ${logger:-} ]] || kill "$logger" 2>/dev/null || true
}
trap restore EXIT
pkill -x WinMuxApp
sleep 3
defaults write -g doubleSidedWindows -bool true
cd "$tree"
nohup env XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel .build/debug/WinMuxApp > "$out/app.log" 2>&1 </dev/null &
sleep 12
nohup /usr/bin/log stream --level debug --style compact --predicate 'category == "lens"' > "$out/lens.log" 2>&1 &
logger=$!
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' > "$out/entries.txt"
front=$(awk -F'|' '$2 == "TextEdit" && $3 == "Grievances.rtf" { print $1 }' "$out/entries.txt")
"$W" focus --window-id "$front"
sleep 3
"$W" list-windows --focused --format '%{window-id}|%{window-title}' > "$out/before.txt"
screencapture -x "$out/before.png"
screencapture -x -v -V 4 "$out/flip.mov" > "$out/recording.log" 2>&1 &
recorder=$!
sleep 1
"$HOME/desk/keys" 0 "$out/flip.events.json" down:alt tap:tab wait:1 up:alt
wait "$recorder"
sleep 2
screencapture -x "$out/after.png"
"$W" list-windows --focused --format '%{window-id}|%{window-title}' > "$out/after.txt"
"$W" agent query --path "$out/world.json"
pkill -x WinMuxApp
