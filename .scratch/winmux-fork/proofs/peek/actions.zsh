#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
zsh ~/peek-proof/restart.zsh
$W lens recent --presentation grid --search saf
zsh ~/peek-proof/take.zsh enter-peek 10 wait:0.5 snap:enter-before tap:space wait:0.7 snap:enter-peek tap:return wait:0.7 snap:enter-after
zsh ~/peek-proof/restart.zsh
$W lens recent --presentation grid --search saf
zsh ~/peek-proof/take.zsh summon-peek 10 wait:0.5 snap:summon-before tap:space wait:0.7 snap:summon-peek down:alt tap:return up:alt wait:0.8 snap:summon-after
safari=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Safari" {print $1; exit}')
$W move-node-to-workspace --window-id "$safari" 2
$W workspace 2 || true
$W workspace 1 || true
