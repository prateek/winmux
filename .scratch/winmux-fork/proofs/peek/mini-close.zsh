#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
K=$HOME/peek-proof/keys-check
zsh ~/peek-proof/profile.zsh live
zsh ~/peek-proof/restart.zsh
ghostty=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
zed=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Zed" {print $1; exit}')
$W focus --window-id "$ghostty"
$K 0 ~/captures/mini-spare.events.json down:cmd tap:n up:cmd wait:1
spare=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1}' | sort -n | tail -1)
[[ "$spare" != "$ghostty" ]] || exit 1
$W focus --window-id "$zed"
export WINMUX_PROOF_FILTER="w.id == $spare"
$W lens --filter "$WINMUX_PROOF_FILTER" --presentation miniatures
(sleep 5; $W close --window-id "$spare") > ~/captures/mini-close-command.txt 2>&1 &
closer=$!
zsh ~/peek-proof/take.zsh mini-close 12 wait:0.5 snap:mini-close-before tap:space wait:0.7 snap:mini-close-peek wait:3 snap:mini-close-empty tap:escape
wait $closer
