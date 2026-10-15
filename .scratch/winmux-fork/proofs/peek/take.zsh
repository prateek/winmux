#!/bin/zsh
export TART_HOME="${TART_HOME:?}"
set -eu
name=$1 seconds=$2
shift 2
out=$HOME/captures/$name
mkdir -p "${out:h}"
rm -f "$out.mov"
screencapture -x -v -V "$seconds" "$out.mov" > "$out.recorder.log" 2>&1 &
recorder=$!
t0=$(date +%s)
sleep 1
~/peek-proof/keys-check "$t0" "$out.events.json" "$@"
wait $recorder
