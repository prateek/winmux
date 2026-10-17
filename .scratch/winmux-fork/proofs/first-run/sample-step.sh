#!/bin/bash
# Run through vm ssh; wait without querying WinMux, then sample once.
set -euo pipefail
step=${1:?step name}
mkdir -p "$HOME/takes/first-run"
sleep 22
"$HOME/demo/frames" > "$HOME/takes/first-run/$step.frames.json"
screencapture -x "$HOME/takes/first-run/$step.png"
W="$HOME/winmux/.build/debug/winmux"
{
  echo '$ winmux config status'
  "$W" config status
  echo '$ winmux list-windows --all'
  set +e
  "$W" list-windows --all
  echo "exit=$?"
  echo '$ winmux --version'
  "$W" --version
} > "$HOME/takes/first-run/$step.cli.txt" 2>&1
