#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
tree=${1:?source tree}
out=$HOME/safari-captures/head-extras
W=$tree/.build/debug/winmux
mkdir -p "$out"
nohup /usr/bin/log stream --level debug --style compact --predicate 'category == "lens"' > "$out/lens.log" 2>&1 &
logger=$!
trap 'kill $logger 2>/dev/null || true' EXIT
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' > "$out/entries.txt"
safari=$(awk -F'|' '$2 == "Safari" && $3 == "Subscription events" { print $1 }' "$out/entries.txt")
"$W" focus --window-id "$safari"
sleep 3
"$W" list-columns > "$out/columns-before.txt"
"$W" column-width 0.35 --window-id "$safari"
sleep 5
"$W" agent query --path "$out/resized-world.json"
"$W" list-columns > "$out/columns-after.txt"
"$W" lens --filter true --presentation grid --sections workspace
sleep 8
screencapture -x "$out/resized-grid.png"
"$W" debug-lens-trace --json --last 1 > "$out/resized-grid.trace.json"
cliclick kp:esc w:500
"$W" lens --filter true --presentation grid --search Subscription
sleep 4
screencapture -x "$out/peek-before.png"
"$W" debug-lens-trace --json --last 1 > "$out/peek-before.trace.json"
"$HOME/desk/keys" 0 "$out/peek.events.json" tap:space wait:3
screencapture -x "$out/peek.png"
"$W" debug-lens-trace --json --last 1 > "$out/peek.trace.json"
"$HOME/desk/keys" 0 "$out/peek-close.events.json" tap:space tap:escape
"$W" column-width 0.44 --window-id "$safari"
sleep 3
"$W" list-workspaces --focused > "$out/ending-workspace.txt"
"$W" list-windows --all --json > "$out/ending-windows.json"
