#!/bin/bash
set -euo pipefail
root=$1
out=$2
name=$3
W="$root/.build/debug/winmux"
mkdir -p "$out"
"$W" list-modes --current > "$out/$name.mode.txt"
"$W" debug-lens-trace --json --last 1 > "$out/$name.trace.json"
"$W" list-windows --focused --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/$name.focus.txt"
"$W" agent query > "$out/$name.tree.json"
screencapture -x "$out/$name.png"
