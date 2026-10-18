#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
tree=${WINMUX_TREE:-$HOME/winmux}
out=${PROOF_OUT:-$HOME/takes/tab-nine-last}
mkdir -p "$out" "$HOME/demo/tab-nine-tools" "$HOME/demo/tab-nine-config" "$HOME/demo/tab-nine-state"
pkill -x WinMuxApp || true
pkill -x tab-nine-stage || true
sleep 3
swiftc "$HOME/winmux/.claude/skills/demo/stage.swift" -o "$HOME/demo/tab-nine-tools/tab-nine-stage"
swiftc "$HOME/winmux/.claude/skills/demo/keys.swift" -o "$HOME/demo/tab-nine-tools/keys"
cd "$tree"
XDG_CONFIG_HOME=$HOME/demo/tab-nine-config XDG_STATE_HOME=$HOME/demo/tab-nine-state WINMUX_NICKEL_HELPER=$tree/nickel-helper/target/release/winmux-nickel nohup .build/debug/WinMuxApp > "$out/app.log" 2>&1 &
sleep 15
nohup "$HOME/demo/tab-nine-tools/tab-nine-stage" Tab01 Tab02 Tab03 Tab04 Tab05 Tab06 Tab07 Tab08 Tab09 Tab10 Tab11 Tab12 > "$out/stage.log" 2>&1 &
sleep 15
W=$tree/.build/debug/winmux
$W list-windows --all --format '%{window-id}|%{window-title}' > "$out/inventory.txt"
[[ $(grep -c '|Tab' "$out/inventory.txt") == 12 ]]
first=$(awk -F'|' '$2=="Tab01" {print $1}' "$out/inventory.txt")
$W focus --window-id "$first"
$W layout tiles horizontal || true
awk -F'|' '$2 ~ /^Tab/ {print}' "$out/inventory.txt" | sort -t'|' -k2 | cut -d'|' -f1 | jq -s --argjson active "$first" \
    '{schemaVersion:1, edit:{operations:[{type:"createTabGroup", tabs:., activeWindowId:$active}]}}' > "$out/group.json"
$W agent apply --path "$out/group.json"
sleep 3
cliclick m:1240,714
screencapture -x "$out/staged.png"
$W list-windows --all --format '%{window-id}|%{window-title}|%{workspace}' > "$out/grouped.txt"
$W list-windows --focused > "$out/staged-focus.txt"
