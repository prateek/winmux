#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=${PROOF_OUT:-$HOME/takes/tab-nine-last}
W=$HOME/winmux/.build/debug/winmux
keys=$HOME/demo/tab-nine-tools/keys
first=$(awk -F'|' '$2=="Tab01" {print $1}' "$out/inventory.txt")
press() {
    local digit=$1 label=$2 expected=$3
    "$keys" 0 "$out/$label.keys.json" down:alt tap:$digit up:alt
    sleep 2
    $W list-windows --focused --format '%{window-id}|%{window-title}' | tee "$out/$label.focus.txt"
    [[ $(cut -d'|' -f2 "$out/$label.focus.txt") == "$expected" ]]
    screencapture -x "$out/$label.png"
}
$W focus --window-id "$first"
sleep 1
press 9 twelve-last Tab12
press 8 twelve-eighth Tab08
for n in {04..12}; do
    print -r -- "close Tab$n" > /tmp/stage/command
    sleep 0.4
done
sleep 8
$W focus --window-id "$first"
sleep 1
press 9 three-last Tab03
press 8 three-out-of-range Tab03
for arg in last 0 first; do
    print -r -- "> winmux focus --tab-index $arg"
    set +e
    $W focus --tab-index "$arg"
    code=$?
    set -e
    print -r -- "exit=$code"
done
$W list-windows --focused > "$out/cli-final-focus.txt"
