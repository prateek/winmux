#!/bin/bash
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
P="$HOME/row-prototype"
W="$HOME/winmux/.build/debug/winmux"
K="$HOME/demo-tools/keys"
mode=${1:-measure}
out="$HOME/takes/row2"
mkdir -p "$out"
swiftc "$P/window-row.swift" -o "$P/window-row"
swiftc "$P/screen-probe.swift" -o "$P/screen-probe"
swiftc "$P/input-probe.swift" -o "$P/input-probe"
swiftc -O "$HOME/demo-tools/keys.swift" -o "$K"
# IDs mapped from this pass's restaged fourteen-window inventory. Override by
# sourcing a fresh mapping before reusing the driver on a different desk.
zed=282; ghost1=292; ghost2=300
safariShown=309; safariHidden=308; safariOther=310
notes=318; textedit=328
if [ -f "$P/fixture.sh" ]; then source "$P/fixture.sh"; fi
option=""
case "$mode" in detach*|secure|contracts) option=--detach;; esac
if [ "$mode" = pending ]; then option=--slow-snapshot; fi
nohup "$P/window-row" $option > "$out/$mode.jsonl" 2>&1 < /dev/null &
prototype=$!
nohup "$P/screen-probe" > "$out/$mode-screen.jsonl" 2>&1 < /dev/null &
screen=$!
trap 'kill "$prototype" "$screen" 2>/dev/null || true' EXIT
sleep 1
kill -0 "$prototype"
# Seed duplicate-process identity from observed application activations.
for id in "$ghost2" "$ghost1" "$safariShown" "$notes" "$textedit" "$zed"; do "$W" focus --window-id "$id"; sleep .2; done
sleep 1
case "$mode" in
measure)
  for sample in $(seq 1 12); do
    "$K" 0 "$out/open-$sample.events.json" down:cmd tap:tab wait:.6 tap:tab wait:.2 tap:tab wait:.2 down:shift tap:tab up:shift wait:.2 tap:escape up:cmd wait:.35
  done
  "$K" 0 "$out/quick.events.json" delay:0 down:cmd tap:tab up:cmd wait:.6
  "$HOME/demo-tools/trace-film" row2/openings 14 \
    down:cmd tap:tab wait:1 tap:escape up:cmd wait:1 \
    down:cmd tap:tab wait:1 tap:escape up:cmd wait:1 \
    down:cmd tap:tab wait:1 tap:escape up:cmd wait:1 \
    down:cmd tap:tab wait:1 tap:escape up:cmd wait:1 \
    down:cmd tap:tab wait:1 tap:escape up:cmd
  ;;
hero|detach-hero)
  "$W" move-node-to-workspace --window-id "$safariHidden" 3
  "$W" focus --window-id "$safariShown"
  "$W" focus --window-id "$zed"
  sleep 1
  (sleep 3; screencapture -x "$out/$mode-row.png"; sleep 1; screencapture -x "$out/$mode-chosen.png") &
  capture=$!
  "$HOME/demo-tools/trace-film" "row2/$mode" 12 down:cmd tap:tab wait:1 tap:a wait:.5 tap:right wait:1 tap:tab wait:.2 down:shift tap:tab up:shift tap:left wait:.5 up:cmd wait:2
  wait "$capture"
  "$W" list-windows --focused > "$out/$mode-focused.txt"
  "$W" list-workspaces --focused > "$out/$mode-workspace.txt"
  ;;
contracts)
  "$K" 0 "$out/escape.events.json" down:cmd tap:tab wait:.7 tap:a wait:.1 delay:0 tap:escape tap:a tap:right up:cmd wait:.4
  "$K" 0 "$out/pairs.events.json" down:cmd tap:tab wait:.7 tap:a delay:0 tap:escape up:cmd wait:.4
  "$K" 0 "$out/quick2.events.json" delay:0 down:cmd tap:tab up:cmd wait:.3
  "$K" 0 "$out/bare.events.json" down:cmd wait:.3 tap:a up:cmd wait:.3
  "$K" 0 "$out/typing.events.json" tap:s tap:d tap:f
  ;;
secure)
  nohup "$P/input-probe" --secure > "$out/secure-canary.txt" 2>&1 < /dev/null &
  canary=$!
  sleep 2
  "$HOME/demo-tools/trace-film" row2/secure 8 down:cmd tap:tab wait:1 tap:a tap:tab wait:1 tap:escape up:cmd wait:1
  kill "$canary"
  ;;
identity)
  for target in 1 2; do
    for id in "$ghost2" "$ghost1" "$zed"; do "$W" focus --window-id "$id"; sleep .2; done
    sleep .5
    if [ "$target" = 1 ]; then
      "$HOME/demo-tools/trace-film" row2/ghost1 6 down:cmd tap:tab wait:1 up:cmd wait:1
    else
      "$HOME/demo-tools/trace-film" row2/ghost2 6 down:cmd tap:tab wait:.5 tap:tab wait:1 up:cmd wait:1
    fi
    "$W" list-windows --focused > "$out/ghost$target-focused.txt"
  done
  ;;
detach-tour)
  "$W" focus --window-id "$safariShown"
  "$W" focus --window-id "$notes"
  "$W" focus --window-id "$textedit"
  "$W" focus --window-id "$zed"
  sleep 1
  "$HOME/demo-tools/trace-film" row2/detach-tour 14 down:cmd tap:tab wait:.7 tap:tab wait:.7 tap:tab wait:1 tap:a wait:.5 tap:right wait:.5 tap:left wait:.5 up:cmd wait:2
  "$W" list-windows --focused > "$out/detach-tour-focused.txt"
  "$W" list-workspaces --focused > "$out/detach-tour-workspace.txt"
  ;;
pointer)
  (sleep 3; cliclick m:960,700 w:100 m:960,540 w:300 m:960,380 w:300 c:960,380) &
  pointer=$!
  "$HOME/demo-tools/trace-film" row2/pointer 7 down:cmd tap:tab wait:3 up:cmd wait:1
  wait "$pointer"
  "$W" list-windows --focused > "$out/pointer-focused.txt"
  ;;
pending)
  "$W" focus --window-id "$safariShown"
  "$W" focus --window-id "$zed"
  "$K" 0 "$out/pending.events.json" down:cmd tap:tab wait:.18 tap:a wait:.7 tap:escape up:cmd
  ;;
resilience)
  killall Dock
  sleep 2
  "$K" 0 "$out/restart-idle.events.json" down:cmd tap:tab wait:.8 tap:escape up:cmd
  (sleep .7; killall Dock) &
  restart=$!
  "$K" 0 "$out/restart-held.events.json" down:cmd tap:tab wait:2 up:cmd wait:1 down:cmd tap:tab wait:.8 tap:escape up:cmd
  wait "$restart"
  ;;
esac
sleep 1
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{app-pid}|%{app-bundle-id}|%{window-title}|%{workspace}' > "$out/$mode-inventory.txt"
kill "$prototype" "$screen"
wait "$prototype" "$screen" 2>/dev/null || true
