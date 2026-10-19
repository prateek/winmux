#!/bin/bash
set -eu
export PATH=/opt/homebrew/bin:$PATH
cli="$HOME/winmux/.build/debug/winmux"
out="$HOME/takes/tab-strip"
for pair in gutter:1853 empty:1450; do
 name=${pair%:*}; x=${pair#*:}
 for id in 201 252 210 248 227; do "$cli" move-node-to-workspace --window-id "$id" 1; done
 "$cli" workspace 1
 "$cli" flatten-workspace-tree
 "$cli" layout --window-id 201 h_tab_group
 "$cli" focus --window-id 201
 cliclick m:1860,1072
 sleep 2
 cliclick dd:$x,60 dm:1700,150 dm:25,100 w:1200 dm:150,278 w:800
 screencapture -x "$out/drag-$name-preview.png"
 cliclick du:150,278 m:1860,1072
 sleep 5
 screencapture -x "$out/drag-$name-result.png"
 "$cli" agent query > "$out/drag-$name-tree.json"
 "$cli" list-windows --all --format '%{window-id} | %{workspace} | %{window-layout} | %{window-title}' > "$out/drag-$name-windows.txt"
done
