#!/bin/bash
export TART_HOME="${TART_HOME:?Set TART_HOME before running this proof}"
set -euxo pipefail
out="$HOME/takes/hook-capture"
w="$HOME/winmux/.build/debug/winmux"
capture="$HOME/demo/hook-state/winmux/hook-capture.jsonl"
bash "$HOME/hook-proof/start.sh"
open -a Ghostty
sleep 3
id=$("$w" list-windows --all --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["window-id"])')
"$w" subscribe hook-called > "$out/file-error-events.jsonl" &
subscriber=$!
trap 'kill "$subscriber" 2>/dev/null || true' EXIT
sleep 1
"$w" debug-hooks on --json
env WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel" "$w" config check "$HOME/demo/hook-active.ncl"
"$w" list-windows --all --filter true --json
test "$(wc -l < "$capture" | tr -d ' ')" = 0
test ! -s "$out/file-error-events.jsonl"
rm "$capture"
mkdir "$capture"
"$w" place --dry-run --window-id "$id" --json
"$w" debug-hooks status --json | tee "$out/file-error-status.json"
test ! -s "$out/file-error-events.jsonl"
if "$w" debug-hooks on --json > "$out/start-error-status.json"; then exit 1; fi
cat "$out/start-error-status.json"
python3 -c 'import json,sys; a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2])); assert not a["capturing"] and a["records"]==0 and a["until"] is None and a["error"]; assert not b["capturing"] and b["error"]; print("Write and start failures report JSON status and stop capture")' "$out/file-error-status.json" "$out/start-error-status.json"
rmdir "$capture"
"$w" debug-hooks on --json
"$w" place --dry-run --window-id "$id" --json
sleep 1
kill "$subscriber"
wait "$subscriber" || true
trap - EXIT
cp "$capture" "$out/file-error-recovered.jsonl"
python3 -c 'import json,sys; a=[json.loads(l) for l in open(sys.argv[1])]; b=[json.loads(l) for l in open(sys.argv[2])]; assert len(a)==len(b)==1; assert b[0].pop("_event")=="hook-called"; assert a==b; print("Recovery: one file record equals one event; no fallback event was emitted while the file failed")' "$out/file-error-recovered.jsonl" "$out/file-error-events.jsonl"
"$w" debug-hooks off
screencapture -x "$out/file-error-recovered.png"
"$w" close --window-id "$id"
sleep 3
pkill -x WinMuxApp
sleep 3
pkill -x ghostty || true
sleep 3
screencapture -x "$out/final-clean.png"
