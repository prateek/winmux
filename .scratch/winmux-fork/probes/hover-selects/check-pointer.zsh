#!/bin/zsh
# Run over vm ssh on the standing desk at 1280×720, with Cmd-Tab opted in.
export TART_HOME=${TART_HOME:?Set TART_HOME before invoking the probe}
export PATH=/opt/homebrew/bin:$PATH
set -eu
W=${WINMUX_TEST_ROOT:-$HOME/winmux}/.build/debug/winmux
out=${1:-$HOME/takes/hover-pointer-check}
repeats=${2:-5}
mkdir -p "$out"
failures=0
id() { $W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' -v a="$1" '$2==a {print $1; exit}'; }
safari=$(id Safari); notes=$(id Notes)
selected() { $W debug-lens-trace --last 1 | python3 -c 'import re,sys; s=sys.stdin.read(); m=re.search(r"Session:.*selection=Optional\((\d+)\)",s); print(m.group(1) if m else "none")'; }
check() {
    local actual=$(selected)
    print "$1: expected=$2 actual=$actual" | tee -a "$out/results.txt"
    [[ "$actual" == "$2" ]] || failures=$((failures + 1))
    $W debug-lens-trace --last 1 > "$out/$1.txt"
}
for presentation in strip grid; do
    for n in $(seq 1 "$repeats"); do
        for app in Notes Safari Ghostty Zed; do $W focus --window-id $(id "$app") >/dev/null; sleep .3; done
        cliclick m:1260,690
        if [[ $presentation == strip ]]; then
            (cliclick kd:cmd kp:tab w:1800 m:695,360 p w:1800 m:836,360 p w:1800 ku:cmd > "$out/$presentation-$n-pointer.txt") &
        else
            $W lens recent --presentation grid
            (cliclick w:1800 m:737,385 p w:1800 m:967,385 p w:1800 kp:esc > "$out/$presentation-$n-pointer.txt") &
        fi
        sleep 2.8
        check "$presentation-$n-first" "$safari"
        sleep 2
        check "$presentation-$n-second" "$notes"
        wait
    done
done
print "Failures: $failures" | tee -a "$out/results.txt"
[[ $failures == 0 ]]
