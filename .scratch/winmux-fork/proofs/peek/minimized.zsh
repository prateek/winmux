#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
K=$HOME/peek-proof/keys-check
ghostty=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
$W focus --window-id "$ghostty"
$K 0 ~/captures/minimize.events.json down:cmd tap:m up:cmd wait:1
$W lens recent --presentation grid --search Ghostty
zsh ~/peek-proof/take.zsh minimized 10 wait:0.6 snap:minimized-before tap:space wait:0.8 snap:minimized-peek tap:space wait:0.5 snap:minimized-back tap:escape
$W debug-windows --window-id "$ghostty" > ~/captures/minimized-record.json
$W lens recent --presentation grid --search Ghostty
$K 0 ~/captures/minimized-restore.events.json wait:0.5 tap:return wait:0.7 snap:minimized-restored
