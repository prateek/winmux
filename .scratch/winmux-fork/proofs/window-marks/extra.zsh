#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
out=$HOME/takes/window-marks-extra
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
  local name=$1
  sleep 2
  screencapture -x "$out/$name.png"
  "$W" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' > "$out/$name.windows.txt"
  "$W" agent query > "$out/$name.agent.json"
  cat "$out/$name.windows.txt"
}

sleep 3
"$W" list-windows --all --format '%{window-id}|%{app-name}|%{workspace}' > "$out/initial.txt"
terminal=$(awk -F'|' '$2=="Ghostty" {print $1}' "$out/initial.txt")
safari=$(awk -F'|' '$2=="Safari" {print $1}' "$out/initial.txt")
run 0 focus --window-id "$terminal"
sleep 2
run 0 mark c
run 0 move-node-to-workspace --window-id "$terminal" 2
snapshot moved-source
run 0 jump c
snapshot moved-jump

osascript -e 'tell application "System Events" to set visible of process "Ghostty" to false'
sleep 3
snapshot hidden
run 0 jump c
snapshot unhidden-jump
run 0 mark d
run 0 focus --window-id "$safari"
sleep 2
run 0 mark d
run 0 list-marks
run 0 list-marks --json
run 0 jump d
snapshot reassigned-d
run 1 mark A
run 1 jump aa
run 1 list-marks --format anything

pkill -x WinMuxApp
sleep 3
cd "$HOME/winmux"
export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$HOME/demo/state WINMUX_NICKEL_HELPER=$HOME/winmux/nickel-helper/target/release/winmux-nickel
nohup .build/debug/WinMuxApp > "$out/restart.log" 2>&1 &
sleep 12
run 1 jump c
snapshot restart-empty
run 0 list-marks --json
run 1 focus-back
print 'Extra window-mark live checks passed.'
