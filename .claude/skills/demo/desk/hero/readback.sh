#!/bin/zsh
set -eu
W=$HOME/winmux/.build/debug/winmux
{
  $W list-workspaces --focused
  $W list-windows --focused
  $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}'
  $W list-columns --json
  $W debug-lens-trace --last 1
} > ~/takes/"$1".readback.txt
