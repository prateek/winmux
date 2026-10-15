#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
W=$HOME/winmux/.build/debug/winmux
K=$HOME/peek-proof/keys-check
zsh ~/peek-proof/restart.zsh
ghostty=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
zed=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Zed" {print $1; exit}')
$W focus --window-id "$ghostty"
$K 0 ~/captures/spare-open.events.json down:cmd tap:n up:cmd wait:1
spare=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1}' | sort -n | tail -1)
[[ "$spare" != "$ghostty" ]] || { echo "No spare Ghostty window opened" >&2; exit 1; }
$W focus --window-id "$spare"
$W focus --window-id "$zed"
zsh ~/peek-proof/take.zsh close-peek 14 snap:close-before down:cmd tap:tab wait:0.6 tap:y wait:0.7 snap:close-peek tap:w wait:0.8 snap:close-moved tap:escape wait:0.5 up:cmd wait:0.5 snap:close-after
if $W list-windows --all --format '%{window-id}' | grep -qx "$spare"; then echo "Spare still exists" >&2; exit 1; fi
print "PASS closed spare $spare; original Ghostty $ghostty retained"
