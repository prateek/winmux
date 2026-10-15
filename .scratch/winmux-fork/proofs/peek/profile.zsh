#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
cp "$HOME/peek-proof/$1.ncl" ~/.config/winmux/winmux.ncl
if pgrep -x WinMuxApp >/dev/null; then
  ${WINMUX_PROOF_ROOT:-$HOME/winmux}/.build/debug/winmux reload-config
fi
sleep 1
