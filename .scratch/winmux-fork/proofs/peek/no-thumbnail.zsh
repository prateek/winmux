#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
export PATH=/opt/homebrew/bin:$PATH
set -eu
name=${1:-no-thumbnail}
W=$HOME/winmux/.build/debug/winmux
K=$HOME/peek-proof/keys-check
open -a Ghostty
sleep 3
$K 0 ~/captures/$name-minimize.events.json down:cmd tap:m up:cmd wait:0.7
open -a Zed ~/.config/winmux/winmux.ncl
sleep 4
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
cd ~/winmux
nohup .build/debug/WinMuxApp > ~/demo/winmux.log 2>&1 &
sleep 6
$W lens recent --presentation grid --search Ghostty
zsh ~/peek-proof/take.zsh "$name" 11 wait:0.6 snap:$name-before tap:space wait:0.8 snap:$name-peek tap:space wait:0.6 snap:$name-back tap:escape
id=$($W list-windows --lens recent --search Ghostty --format '%{window-id}')
$W debug-windows --window-id "$id" > ~/captures/$name-record.txt
zsh ~/peek-proof/cleanup.zsh
