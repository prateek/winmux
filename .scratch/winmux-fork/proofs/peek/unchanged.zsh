#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
prefix=$1
W=${WINMUX_PROOF_ROOT:-$HOME/winmux}/.build/debug/winmux
K=$HOME/peek-proof/keys-check
A=$HOME/peek-proof/assert-state.py
safari=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Safari" {print $1; exit}')
zed=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Zed" {print $1; exit}')
prepare() {
  $W move-node-to-workspace --window-id "$safari" 2
  $W workspace 2 || true
  $W workspace 1 || true
  $W focus --window-id "$safari"
  $W focus --window-id "$zed"
  cliclick m:1260,690
}
check_focus() {
  local actual=$($W list-windows --focused --format '%{window-id}')
  [[ "$actual" == "$safari" ]] || { print -u2 "focus $actual expected $safari"; exit 1; }
  local workspace=$($W list-windows --all --format '%{window-id}|%{workspace}' | awk -F'|' -v id="$safari" '$1==id {print $2}')
  [[ "$workspace" == "$1" ]] || { print -u2 "workspace $workspace expected $1"; exit 1; }
  print "PASS focused Safari on workspace $workspace"
}
prepare
$W lens search --search ''
$K 0 ~/captures/$prefix/search.events.json wait:0.5 tap:s tap:a tap:f tap:space wait:0.5 snap:$prefix/search-space tap:escape snap:$prefix/search-escape tap:escape snap:$prefix/normal-escape
python3 "$A" ~/captures/$prefix/search-space.trace.json 'search="saf "' 'state="search"' active=true
python3 "$A" ~/captures/$prefix/search-escape.trace.json 'state="normal"' active=true
python3 "$A" ~/captures/$prefix/normal-escape.trace.json active=false
$W lens search --search ''
$K 0 ~/captures/$prefix/freed.events.json wait:0.5 tap:space wait:0.4 snap:$prefix/freed-space tap:escape tap:escape
python3 "$A" ~/captures/$prefix/freed-space.trace.json 'search=" "' 'state="search"'
prepare
$W lens recent --presentation grid --search saf
$K 0 ~/captures/$prefix/enter.events.json wait:0.5 tap:return wait:0.5 snap:$prefix/enter
check_focus 2
prepare
$W lens recent --presentation grid --search saf
$K 0 ~/captures/$prefix/alt-enter.events.json wait:0.5 down:alt tap:return wait:0.5 up:alt snap:$prefix/alt-enter
check_focus 1
prepare
$K 0 ~/captures/$prefix/release.events.json down:cmd tap:tab wait:0.6 up:cmd wait:0.6 snap:$prefix/release
check_focus 2
prepare
$K 0 ~/captures/$prefix/held-enter.events.json down:cmd tap:tab wait:0.6 tap:return wait:0.6 up:cmd snap:$prefix/held-enter
check_focus 2
prepare
$K 0 ~/captures/$prefix/held-summon.events.json down:cmd tap:tab wait:0.6 down:alt tap:return wait:0.6 up:alt up:cmd snap:$prefix/held-summon
check_focus 1
ghostty=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
$W focus --window-id "$ghostty"
$K 0 ~/captures/$prefix/new-window.events.json down:cmd tap:n up:cmd wait:1
spare=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1}' | sort -n | tail -1)
[[ "$spare" != "$ghostty" ]] || exit 1
$W focus --window-id "$zed"
$W lens recent --presentation grid --search Ghostty
$K 0 ~/captures/$prefix/close.events.json wait:0.6 snap:$prefix/close-before down:cmd tap:w up:cmd wait:0.7 snap:$prefix/close
if $W list-windows --all --format '%{window-id}' | grep -qx "$spare"; then echo "Spare was not closed" >&2; exit 1; fi
print "PASS unchanged Search, freed Space, Escape, Enter, alt-enter, Cmd-Tab release and cmd-w"
