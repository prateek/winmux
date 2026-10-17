#!/bin/zsh
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
set -eu
label=$1
root=${2:-$HOME/winmux}
W=$root/.build/debug/winmux
out=$HOME/takes/117/$label
[[ -x ~/desk/snapshot-recorder ]] || swiftc -O ~/desk/snapshot-recorder.swift -o ~/desk/snapshot-recorder
[[ -x ~/desk/arrow-chord ]] || swiftc ~/desk/arrow-chord.swift -o ~/desk/arrow-chord
for driver in cliclick keys; do
for direction in left right; do
  cliclick m:1240,714 ku:fn
  $W workspace 1 >/dev/null
  sleep 2
  cliclick m:2,360
  sleep 2
  movie=$out/spaces-$direction-$driver.mov
  rm -f "$movie"
  ~/desk/snapshot-recorder "$movie" 4 &
  recorder=$!
  sleep 1
  if [[ $driver == cliclick ]]; then
    cliclick kd:ctrl kp:arrow-$direction ku:ctrl
  else
    ~/desk/arrow-chord "$direction"
  fi
  wait $recorder
  cliclick m:1240,714
  sleep 2
  $W list-windows --focused
done
done
