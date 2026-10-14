#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
cp "$HOME/held-proof/$1.ncl" ~/.config/winmux/winmux.ncl
${WINMUX_PROOF_ROOT:-$HOME/winmux}/.build/debug/winmux reload-config
sleep 1
