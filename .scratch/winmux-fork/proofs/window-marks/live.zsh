#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/window-marks
mkdir -p "$out"
exec > >(tee "$out/transcript.txt") 2>&1

run() {
  local expected=$1
  shift
  print -r -- "\$ winmux $*"
  local code=0
  "$W" "$@" || code=$?
  print -r -- "exit=$code"
  [[ $code == $expected ]]
}

snapshot() {
  local name=$1 expected=$2 workspace=$3
  sleep 2
  screencapture -x "$out/$name.png"
  "$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/$name.windows.txt"
  "$W" agent query > "$out/$name.agent.json"
  "$W" list-windows --focused --format '%{window-id}|%{workspace}' > "$out/$name.focus.txt"
  cat "$out/$name.windows.txt" "$out/$name.focus.txt"
  [[ $(cat "$out/$name.focus.txt") == "$expected|$workspace" ]]
}

sleep 3
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/initial.txt"
zed=$(awk -F'|' '$2=="Zed" {print $1}' "$out/initial.txt")
safari=$(awk -F'|' '$2=="Safari" {print $1}' "$out/initial.txt")
[[ -n $zed && -n $safari ]]
run 0 focus --window-id "$zed"
sleep 2
run 0 mark a
run 0 mark z
run 0 mark
run 0 focus --window-id "$safari"
sleep 2
run 0 jump a
snapshot jump-a "$zed" 1

for n in 1 2 3 4; do
  run 0 focus-back
  if (( n % 2 )); then
    snapshot "focus-back-$n" "$safari" 2
  else
    snapshot "focus-back-$n" "$zed" 1
  fi
done
run 0 list-marks
run 0 list-marks --json
run 1 jump b
snapshot empty-b "$zed" 1

run 0 macos-native-minimize --window-id "$zed"
sleep 3
screencapture -x "$out/minimized.png"
"$W" list-windows --all --json > "$out/minimized.windows.json"
run 0 focus --window-id "$safari"
sleep 2
run 0 jump a
snapshot restored-a "$zed" 1

run 0 close --window-id "$zed"
sleep 3
run 0 focus --window-id "$safari"
sleep 2
run 1 jump a
snapshot closed-a "$safari" 2
run 0 list-marks
run 0 list-marks --json
print 'All window-mark live checks passed.'
