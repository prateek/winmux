#!/bin/zsh
set -eu
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/close35/fixed-cli
mkdir -p "$out"
windows() { $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}'; }
: > "$out/summary.txt"
for kind in disabled absent; do
    if [[ $kind == disabled ]]; then title='Disabled close button'; else title='No close button'; fi
    windows > "$out/$kind-before.txt"
    row=$(windows | awk -F'|' -v title="$title" '$3==title {print; exit}')
    target=${row%%|*}
    [[ -n "$target" ]]
    result=0
    $W close --window-id "$target" > "$out/$kind-stdout.txt" 2> "$out/$kind-stderr.txt" || result=$?
    [[ $result == 1 ]]
    grep -Fx "Can't close 'CloseFixture': the window has no close button" "$out/$kind-stderr.txt"
    windows > "$out/$kind-after.txt"
    grep -Fx "$row" "$out/$kind-after.txt"
    { echo "$title: exit=$result"; cat "$out/$kind-stderr.txt"; echo "Before: $row"; echo "After:  $row"; echo; } >> "$out/summary.txt"
done
~/close35-fixture/CloseFixture $(pgrep -x CloseFixture) > "$out/ax-buttons.txt"
cat "$out/summary.txt" "$out/ax-buttons.txt"
screencapture -x "$out/native-windows-after.png"
