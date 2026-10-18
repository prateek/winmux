#!/bin/zsh
set -eu
export PATH=/opt/homebrew/bin:$PATH
W=$HOME/winmux/.build/debug/winmux
OUT=${FIND_FOCUS_CAPTURES:-$HOME/takes/find-focus}
mkdir -p "$OUT"
inventory=$($W list-windows --all --format '%{window-id}|%{app-name}|%{window-title}')
print -r -- "$inventory" > "$OUT/inventory.txt"
zed=$(print -r -- "$inventory" | awk -F'|' '$2=="Zed" {print $1}')
ghostty=$(print -r -- "$inventory" | awk -F'|' '$2=="Ghostty" {print $1}')

readback() {
  $W list-windows --focused > "$OUT/$1.focus.txt" || true
  $W list-workspaces --focused >> "$OUT/$1.focus.txt"
  $HOME/focus-proof/observe focus >> "$OUT/$1.focus.txt"
}

set_layout() {
  local desired=$1
  local current=$($W list-windows --focused --format '%{window-layout}')
  if [[ "$current" != "$desired" ]]; then $W layout "$desired"; fi
  sleep 1
  current=$($W list-windows --focused --format '%{window-layout}')
  print -r -- "$current" >> "$OUT/layouts.txt"
  [[ "$current" == "$desired" ]]
}

take() {
  local name=$1 action=${2:-none}
  readback "$name.before"
  screencapture -x -v -V 4 "$OUT/$name.mov" > "$OUT/$name.recorder.txt" 2>&1 &
  local recorder=$!
  sleep 0.7
  $HOME/focus-proof/observe sample > "$OUT/$name.alpha.csv" &
  local observer=$!
  $W find-focus > "$OUT/$name.stdout.txt" 2> "$OUT/$name.stderr.txt"
  sleep 0.15
  screencapture -x "$OUT/$name.mark.png"
  case "$action" in
    key) $HOME/desk/keys 0 "$OUT/$name.keys.json" tap:escape ;;
    click) cliclick c:900,400 ;;
    focus) $W focus --window-id "$ghostty" ;;
    flags) $HOME/desk/keys 0 "$OUT/$name.keys.json" down:shift up:shift ;;
    restart) sleep 0.15; $W find-focus ;;
    late-restart) sleep 0.6; $W find-focus ;;
    disable) $W enable off ;;
    reload) $W reload-config --no-gui ;;
  esac
  sleep 0.15
  screencapture -x "$OUT/$name.after-action.png"
  sleep 1.3
  if [[ "$action" == disable ]]; then
    $W find-focus > "$OUT/disabled.stdout.txt" 2> "$OUT/disabled.stderr.txt"
    print $? > "$OUT/disabled.exit.txt"
    $W enable on
    sleep 1
  fi
  readback "$name.after"
  screencapture -x "$OUT/$name.end.png"
  wait "$observer"
  wait "$recorder"
}

if [[ ${1:-all} == functions ]]; then return; fi

if [[ ${1:-all} == all ]]; then
$W mode main
$W focus --window-id "$zed"
set_layout h_tiles
sleep 2
take tiled
take key key
take click click
$W focus --window-id "$zed"
sleep 1
take focus focus
$W focus --window-id "$zed"
sleep 1
take flags flags
take restart restart
take reload reload
take disable disable
fi
$W enable on
sleep 1
$W focus --window-id "$zed"
set_layout h_tab_group
$W focus tab-next
sleep 2
take tab
$W layout floating
sleep 2
take floating
$W layout tiling
$W fullscreen on
sleep 2
take fullscreen
$W fullscreen off
sleep 2
$W workspace 3
sleep 2
set +e
$W find-focus > "$OUT/empty.stdout.txt" 2> "$OUT/empty.stderr.txt"
print $? > "$OUT/empty.exit.txt"
set -e
readback empty
screencapture -x "$OUT/empty.png"
$W focus --window-id "$zed"
sleep 2
readback c.before
screencapture -x -v -V 4 "$OUT/c.mov" > "$OUT/c.recorder.txt" 2>&1 &
recorder=$!
sleep 0.7
$HOME/desk/keys 0 "$OUT/c.keys.json" down:alt tap:semicolon up:alt wait:0.2 tap:c
sleep 0.15
screencapture -x "$OUT/c.mark.png"
sleep 1.5
$W list-modes --current > "$OUT/c.mode.txt"
readback c.after
wait "$recorder"
$W mode main
readback final
