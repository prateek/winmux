#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=${PROOF_OUT:-$HOME/takes/tab-nine-last}
W=$HOME/winmux/.build/debug/winmux
if [[ ${1:-prepare} == prepare ]]; then
    open -a Notes
    sleep 5
    osascript <<'APPLESCRIPT'
tell application "Notes"
    set proofNote to make new note at folder "Notes" of account "On My Mac" with properties {name:"Tab digit check", body:"<div>Tab digit check</div><div>Input: </div>"}
    show proofNote
    activate
end tell
APPLESCRIPT
    sleep 8
    $W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' > "$out/notes-inventory.txt"
    note=$(awk -F'|' '$2=="Notes" {print $1; exit}' "$out/notes-inventory.txt")
    $W move-node-to-workspace --window-id "$note" 2
    $W workspace 2
    $W focus --window-id "$note"
    sleep 3
    screencapture -x "$out/notes-before.png"
else
    cliclick c:800,220
    sleep 1
    $W list-windows --focused --format '%{window-id}|%{window-title}' > "$out/notes-focus-before.txt"
    osascript -e 'tell application "Notes" to get body of note 1' > "$out/notes-body-before.html"
    "$HOME/demo/tab-nine-tools/keys" 0 "$out/option-zero.keys.json" down:alt tap:0 up:alt
    sleep 2
    osascript -e 'tell application "Notes" to get body of note 1' > "$out/notes-body-after.html"
    $W list-windows --focused --format '%{window-id}|%{window-title}' > "$out/notes-focus-after.txt"
    screencapture -x "$out/option-zero.png"
    grep -q 'º' "$out/notes-body-after.html"
    diff -u "$out/notes-focus-before.txt" "$out/notes-focus-after.txt"
    cat "$out/notes-body-after.html"
fi
