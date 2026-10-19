#!/bin/bash
export TART_HOME="${TART_HOME:?Set TART_HOME before running this proof}"
set -euxo pipefail
out="$HOME/takes/hook-capture"
w="$HOME/winmux/.build/debug/winmux"
capture="$HOME/demo/hook-state/winmux/hook-capture.jsonl"
pkill -x WinMuxApp || true
sleep 3
pkill -x ghostty || true
sleep 2
bash "$HOME/hook-proof/start.sh"
"$w" debug-hooks
"$w" debug-hooks --help
open -a Ghostty
sleep 3
warm_id=$("$w" list-windows --all --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["window-id"])')
"$w" close --window-id "$warm_id"
sleep 3
"$w" subscribe hook-called > "$out/events.jsonl" &
subscriber=$!
trap 'kill "$subscriber" 2>/dev/null || true' EXIT
sleep 1
test ! -s "$out/events.jsonl"
"$w" debug-hooks on
open -a Ghostty
sleep 2
id=$(python3 -c 'import json,sys; a=[json.loads(l) for l in open(sys.argv[1])]; assert len(a)==2,a; assert [r["hook"] for r in a]==["arrive","columns.place"]; print(a[0]["window-id"])' "$capture")
"$w" debug-windows --window-id "$id" > "$out/live-arrival-debug.txt"
cp "$capture" "$out/live-arrival.jsonl"
cat "$out/live-arrival.jsonl"
cat "$out/live-arrival-debug.txt"
"$w" list-windows --all --json | tee "$out/live-arrival-windows.json"
"$w" list-columns --json | tee "$out/live-arrival-columns.json"
"$w" agent query > "$out/live-arrival-tree.txt"
screencapture -x "$out/live-arrival.png"
"$w" debug-hooks on --json
test "$(wc -l < "$capture" | tr -d ' ')" = 2
"$w" place --dry-run --window-id "$id" --json
test "$(wc -l < "$capture" | tr -d ' ')" = 3
"$w" move-node-to-column 3 --window-id "$id"
"$w" move right --window-id "$id"
test "$(wc -l < "$capture" | tr -d ' ')" = 4
tail -2 "$capture"
"$w" list-columns --json | tee "$out/live-boundary-columns.json"

cp "$HOME/hook-proof/fail.ncl" "$HOME/demo/hook-active.ncl"
"$w" reload-config --no-gui
"$w" debug-hooks status --json
open -a Ghostty
"$HOME/demo/hook-keys" "$(date +%s)" "$out/failure-keys.json" down:cmd tap:n up:cmd
sleep 3
cp "$capture" "$out/live-failure.jsonl"
tail -2 "$capture"
"$w" config status | tee "$out/live-failure-status.json"
"$w" list-columns --json | tee "$out/live-failure-columns.json"
"$w" list-windows --all --json | tee "$out/live-failure-windows.json"
screencapture -x "$out/live-failure.png"

cp "$HOME/hook-proof/out-of-range.ncl" "$HOME/demo/hook-active.ncl"
"$w" reload-config --no-gui
open -a Ghostty
"$HOME/demo/hook-keys" "$(date +%s)" "$out/out-of-range-keys.json" down:cmd tap:n up:cmd
sleep 3
cp "$capture" "$out/live-out-of-range.jsonl"
tail -2 "$capture"
"$w" config status | tee "$out/live-out-of-range-status.json"
"$w" list-columns --json | tee "$out/live-out-of-range-columns.json"
"$w" list-windows --all --json | tee "$out/live-out-of-range-windows.json"
screencapture -x "$out/live-out-of-range.png"
sleep 1
kill "$subscriber"
wait "$subscriber" || true
cp "$capture" "$out/live-on.jsonl"
"$w" debug-hooks off --json
"$w" debug-hooks off
"$w" debug-hooks status --json
"$w" subscribe hook-called > "$out/off-events.jsonl" &
subscriber=$!
sleep 1
before=$(wc -l < "$capture")
open -a Ghostty
"$HOME/demo/hook-keys" "$(date +%s)" "$out/off-keys.json" down:cmd tap:n up:cmd
sleep 3
after=$(wc -l < "$capture")
test "$before" = "$after"
test ! -s "$out/off-events.jsonl"
"$w" list-windows --all --json | tee "$out/live-off-windows.json"
"$w" list-columns --json | tee "$out/live-off-columns.json"
"$w" agent query > "$out/live-off-tree.txt"
wc -l "$capture" "$out/off-events.jsonl"
kill "$subscriber"
wait "$subscriber" || true
trap - EXIT
python3 "$HOME/hook-proof/validate.py" "$out"
"$w" debug-hooks on --json
test "$(wc -l < "$capture" | tr -d ' ')" = 0
"$w" debug-hooks off
pkill -x WinMuxApp
sleep 3
pkill -x ghostty || true
sleep 3
screencapture -x "$out/live-clean.png"
