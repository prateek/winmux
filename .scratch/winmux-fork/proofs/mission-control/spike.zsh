#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/takes/mission-control/spike
mkdir -p "$out"
P=$HOME/mission-control/parking
W=$HOME/winmux/.build/debug/winmux
option=$1
if [[ $option == setup ]]; then
    $W workspace 3
    sleep 4
    $P save "$out/workspace3.json"
    $W workspace 2
    sleep 4
    $P save "$out/workspace2.json"
    $W list-windows --all --json > "$out/windows.json"
    pkill -x WinMuxApp
    sleep 4
    option=baseline
fi
if pgrep -x WinMuxApp; then
    echo 'Refusing to experiment while WinMux is running' >&2
    exit 1
fi
$P apply "$out/workspace2.json" "$option" "$out/$option-actual.json" > "$out/$option-apply.txt"
cliclick m:1880,1070
sleep 2
screencapture -x "$out/$option-desktop.png"
~/mission-control/arrow-chord up
sleep 3
screencapture -x "$out/$option-mission-control.png"
$P ax > "$out/$option-mission-control-ax.txt"
cliclick kp:esc ku:fn
sleep 2
if ! $P capture 204 "$out/$option-textedit.png" > "$out/$option-textedit.txt" 2>&1; then
    echo "TextEdit capture unavailable for $option"
fi
if ! $P capture 185 "$out/$option-safari.png" > "$out/$option-safari.txt" 2>&1; then
    echo "Safari capture unavailable for $option"
fi
screencapture -x "$out/$option-after-capture.png"
screencapture -x -v -V 20 "$out/$option-switch.mov" &
recorder=$!
sleep 2
for n in 1 2; do
    $P apply "$out/workspace3.json" "$option" "$out/$option-switch3-$n.json" > "$out/$option-switch3-$n.txt"
    sleep 1
    $P apply "$out/workspace2.json" "$option" "$out/$option-switch2-$n.json" > "$out/$option-switch2-$n.txt"
    sleep 1
done
wait "$recorder"
