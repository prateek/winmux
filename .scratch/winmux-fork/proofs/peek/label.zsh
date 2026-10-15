#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
W=$HOME/winmux/.build/debug/winmux
zsh ~/peek-proof/profile.zsh live
zsh ~/peek-proof/restart.zsh
ghostty=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
zed=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Zed" {print $1; exit}')
$W layout floating --window-id "$ghostty"
~/peek-proof/window-frame "$ghostty" 320 180 600 350
$W agent query --path "$HOME/captures/label-native-frame.json" >/dev/null
$W focus --window-id "$zed"
$W lens recent --presentation grid --search Ghostty
zsh ~/peek-proof/take.zsh label 11 wait:0.7 snap:label-before tap:space wait:1 snap:label-peek tap:space wait:0.7 snap:label-shrunk tap:escape
$W layout tiling --window-id "$ghostty"
