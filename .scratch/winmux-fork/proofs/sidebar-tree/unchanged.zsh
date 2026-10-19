#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$1
out=$2
mkdir -p "$out"
sleep 4
$W list-windows --all --format '%{app-name}|%{window-title}|%{workspace}|%{window-layout}' | sort > "$out/before.txt"
id=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F '|' '$2 == "Calculator" {print $1; exit}')
$W move-node-to-workspace --window-id "$id" 1
sleep 3
$W list-windows --all --format '%{app-name}|%{window-title}|%{workspace}|%{window-layout}' | sort > "$out/moved.txt"
$W move-node-to-workspace --window-id "$id" 4
$W workspace 2
sleep 3
$W list-columns --json > "$out/columns-2.json"
$W focus-column 1
$W focus-column 3
$W workspace 1
sleep 3
$W list-windows --all --format '%{app-name}|%{window-title}|%{workspace}|%{window-layout}' | sort > "$out/after.txt"
$W list-windows --focused --format '%{window-id}|%{workspace}' > "$out/focus.txt"
$W agent query > "$out/layout-after.json"
