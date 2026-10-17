#!/bin/zsh
export PATH=/opt/homebrew/bin:$PATH
set -u
label=$1; root=$2
W=$root/.build/debug/winmux
out=$HOME/takes/117/driver-$label; mkdir -p $out
pkill -x WinMuxApp; sleep 2
cliclick m:1240,714
export XDG_CONFIG_HOME=$HOME/demo/config XDG_STATE_HOME=$HOME/demo/state
export WINMUX_NICKEL_HELPER=$root/nickel-helper/target/release/winmux-nickel
nohup $root/.build/debug/WinMuxApp --config-path $HOME/desk/always.ncl > $out/app.log 2>&1 &
sleep 10
$W workspace 1 >/dev/null
wid=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
$W focus --window-id "$wid"; sleep 1
osascript -e 'tell application "System Events" to keystroke "clear" ' ; ~/desk/keys "$(date +%s)" $out/k0.json tap:return; sleep 1
screencapture -x $out/0-start.png
cliclick m:100,360; sleep 2
screencapture -x $out/1-hover.png
cliclick m:900,400; sleep 2
echo "front: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')"
~/desk/keys "$(date +%s)" $out/k1.json tap:e tap:c tap:h tap:o; sleep 1
screencapture -x $out/2-typed-away.png
echo "focused: $($W list-windows --focused)"
pkill -x WinMuxApp; sleep 2
