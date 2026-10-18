#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
out=$HOME/takes/tab-hints
W=$HOME/winmux/.build/debug/winmux
keys=$HOME/demo/tab-nine-tools/keys
mkdir -p "$out"
first=$(awk -F'|' '$2=="Tab01" {print $1}' "$HOME/takes/tab-nine-last/inventory.txt")

readback() {
    sleep 2
    $W list-windows --focused --format '%{window-id}|%{window-title}|%{workspace}' > "$out/$1.focus.txt"
    screencapture -x "$out/$1.end.png"
    cat "$out/$1.focus.txt"
}

take() {
    local name=$1 seconds=$2
    shift 2
    screencapture -x -v -V "$seconds" "$out/$name.mov" &
    local recorder=$!
    (sleep $((seconds + 2)); kill -INT "$recorder" 2>/dev/null || true) &
    sleep 1
    "$keys" 0 "$out/$name.keys.json" "$@"
    wait "$recorder"
    readback "$name"
}

case ${1:-twelve} in
    last)
        (sleep 2; "$HOME/tab-hints-proof/scroll"; sleep 1; screencapture -x "$out/twelve-last-shown.png") &
        take twelve-last 7 down:alt wait:4 up:alt
        ;;
    twelve)
        $W focus --window-id "$first"
        sleep 2
        (sleep 1.25; screencapture -x "$out/twelve-before-deadline.png"; sleep 0.9; screencapture -x "$out/twelve-shown.png") &
        take twelve 6 down:alt wait:1.5 tap:2 wait:1 up:alt
        take quick 4 down:alt tap:3 up:alt
        take spoiled 5 down:alt tap:3 wait:2 up:alt
        ;;
    three)
        for n in {04..12}; do
            print -r -- "close Tab$n" > /tmp/stage/command
            sleep 0.4
        done
        sleep 8
        $W focus --window-id "$first"
        sleep 2
        (sleep 2; screencapture -x "$out/three-shown.png") &
        take three 6 down:alt wait:1.5 tap:2 wait:1 up:alt
        ;;
    remapped)
        (sleep 2; screencapture -x "$out/control-shown.png") &
        take control 5 down:ctrl wait:1.5 tap:3 wait:0.5 up:ctrl
        (sleep 2; screencapture -x "$out/q-shown.png") &
        take option-q 5 down:alt wait:1.5 tap:q wait:0.5 up:alt
        (sleep 1.2; cliclick m:1100,650; sleep 0.9; screencapture -x "$out/mouse-move-shown.png") &
        take mouse-move 5 down:alt wait:2 up:alt
        (sleep 2; screencapture -x "$out/lens-before.png"; sleep 1.5; screencapture -x "$out/lens-after.png") &
        take lens 7 down:alt wait:1.5 tap:slash wait:2 up:alt
        $W debug-lens-trace --last 1 > "$out/lens-trace.txt"
        $W list-windows --lens search --json > "$out/lens-matches.json"
        $W list-windows --all --format '%{window-id}|%{window-title}|%{workspace}' > "$out/lens-inventory.txt"
        "$keys" 0 "$out/lens-close.keys.json" tap:escape wait:0.3 tap:escape
        ;;
    two-groups|split-groups)
        if [[ $1 == two-groups ]]; then
            for n in {01..03}; do
                print -r -- "open Other$n" > /tmp/stage/command
                sleep 0.5
            done
        fi
        sleep 10
        $W list-windows --all --format '%{window-id}|%{window-title}' > "$out/two-groups.inventory.txt"
        jq -Rn '[inputs | split("|") | {id:(.[0]|tonumber), title:.[1]}] | sort_by(.title) as $all | [$all[] | select(.title | startswith("Tab")) | .id] as $tabs | [$all[] | select(.title | startswith("Other")) | .id] as $other | {schemaVersion:1, edit:{operations:[{type:"setWorkspaceLayout", layout:{name:"1", layout:{kind:"split", direction:"horizontal", children:[{kind:"tabGroup", tabs:$tabs, activeWindowId:$tabs[0]}, {kind:"tabGroup", tabs:$other, activeWindowId:$other[0]}]}}}]}}' < "$out/two-groups.inventory.txt" > "$out/two-groups.json"
        $W agent apply --path "$out/two-groups.json"
        $W focus --window-id "$first"
        sleep 3
        (sleep 2; screencapture -x "$out/two-groups-split-shown.png") &
        take two-groups-split 6 down:alt wait:2 tap:2 wait:0.5 up:alt
        ;;
esac
