#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
prefix=$1
W=${WINMUX_PROOF_ROOT:-$HOME/winmux}/.build/debug/winmux
K=$HOME/held-proof/keys-check
safari=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Safari" {print $1}')
zed=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Zed" {print $1}')
prepare() {
  $W move-node-to-workspace --window-id "$safari" 2
  $W workspace 2
  sleep 0.4
  $W workspace 1
  sleep 0.4
  $W focus --window-id "$safari"
  $W focus --window-id "$zed"
  cliclick m:1260,690
}
check() {
  local name=$1 destination=$2
  local actual=$($W list-windows --focused --format '%{window-id}')
  [[ "$actual" == "$safari" ]] || { print -u2 "$name focused $actual instead of $safari"; exit 1; }
  local workspace=$($W list-windows --all --format '%{window-id}|%{workspace}' | awk -F'|' -v id="$safari" '$1==id {print $2}')
  [[ "$workspace" == "$destination" ]] || { print -u2 "$name moved to $workspace instead of $destination"; exit 1; }
  print "PASS $name: Safari focused, workspace $workspace"
}
prepare
$W lens recent --presentation grid --search saf
$K 0 ~/captures/$prefix/grid-focus.events.json wait:0.4 tap:return wait:0.5 snap:$prefix/grid-focus
check grid-focus 2
prepare
$W lens recent --presentation grid --search saf
$K 0 ~/captures/$prefix/grid-alt-enter.events.json wait:0.4 down:alt tap:return wait:0.5 up:alt snap:$prefix/grid-alt-enter
check grid-alt-enter 1
prepare
$K 0 ~/captures/$prefix/list-held-shift-enter.events.json down:alt tap:slash wait:0.5 down:shift tap:return wait:0.5 up:shift up:alt snap:$prefix/list-held-shift-enter
check list-held-shift-enter 1
prepare
$K 0 ~/captures/$prefix/grid-held-shift-enter.events.json down:ctrl down:alt tap:tab wait:0.5 down:shift tap:return wait:0.5 up:shift up:alt up:ctrl snap:$prefix/grid-held-shift-enter
check grid-held-shift-enter 1
prepare
$W lens recent --presentation grid --search saf
$K 0 ~/captures/$prefix/grid-option-click.events.json wait:0.5 down:alt click:640,385 wait:0.5 up:alt snap:$prefix/grid-option-click
check grid-option-click 1
prepare
$K 0 ~/captures/$prefix/strip-option-click.events.json down:ctrl down:shift tap:tab wait:0.5 down:alt click:640,365 wait:0.5 up:alt up:shift up:ctrl snap:$prefix/strip-option-click
check strip-option-click 1
prepare
$K 0 ~/captures/$prefix/strip-release.events.json down:cmd tap:tab wait:0.5 up:cmd wait:0.5 snap:$prefix/strip-release
check strip-release 2
prepare
$K 0 ~/captures/$prefix/strip-option-release.events.json down:cmd tap:tab wait:0.5 down:alt up:cmd wait:0.5 up:alt snap:$prefix/strip-option-release
check strip-option-release 1
