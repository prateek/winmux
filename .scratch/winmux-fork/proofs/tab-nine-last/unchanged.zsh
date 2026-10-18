#!/bin/zsh
set -eu
tree=${WINMUX_TREE:-$HOME/winmux}
out=${PROOF_OUT:-$HOME/takes/tab-nine-last}
W=$tree/.build/debug/winmux
first=$(awk -F'|' '$2=="Tab01" {print $1}' "$out/inventory.txt")
$W focus --window-id "$first"
for command in 'focus --tab-index 8' 'focus tab-next' 'focus tab-prev' 'focus --tab-index 13'; do
    print -r -- "> $command"
    set +e
    $W ${=command}
    code=$?
    set -e
    print -r -- "exit=$code"
    sleep 1
    $W list-windows --focused --format '%{window-title}'
done
