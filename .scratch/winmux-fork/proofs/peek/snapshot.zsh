#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
id=$1
out=$HOME/captures/$id
mkdir -p "${out:h}"
W=${WINMUX_PROOF_ROOT:-$HOME/winmux}/.build/debug/winmux
$W debug-lens-trace --last 1 > "$out.trace.txt"
$W debug-lens-trace --last 1 --json > "$out.trace.json"
$W list-workspaces --focused > "$out.workspace.txt"
$W list-windows --focused > "$out.focus.txt"
$W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out.windows.txt"
query=$(python3 -c 'import json,sys; traces=json.load(open(sys.argv[1])); print(traces[-1]["session"]["search"] if traces else "")' "$out.trace.json")
if [[ -n ${WINMUX_PROOF_FILTER:-} ]]; then
  $W list-windows --filter "$WINMUX_PROOF_FILTER" --search "$query" --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out.matches.txt"
else
  $W list-windows --lens recent --search "$query" --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out.matches.txt"
fi
screencapture -x "$out.png"
