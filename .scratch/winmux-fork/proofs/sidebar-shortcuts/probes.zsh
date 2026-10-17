#!/bin/zsh
export TART_HOME=${TART_HOME:?set TART_HOME before running}
export PATH=/opt/homebrew/bin:$PATH
set -eu
label=$1
root=${2:-$HOME/winmux}
W=$root/.build/debug/winmux
out=$HOME/takes/117/$label
mkdir -p "$out"
exec > >(tee "$out/probes.log") 2>&1
front() { osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'; }
keys() { ~/desk/keys "$(date +%s)" "$out/keys-$(date +%s).json" "$@"; }
focus() {
  cliclick m:1240,714 ku:fn
  $W workspace 1 >/dev/null
  local wid=$($W list-windows --all --format '%{window-id}|%{app-name}' | awk -F'|' '$2=="Ghostty" {print $1; exit}')
  $W focus --window-id "$wid"
  sleep 2
}
for probe in ctrl-up ctrl-down ctrl-left ctrl-right cmd-space cmd-n; do
  echo "=== $label $probe ==="
  focus
  echo before=$(front)
  $W list-windows --focused
  osascript -e 'tell application "System Events" to tell process "Ghostty" to count windows'
  cliclick m:2,360
  sleep 2
  echo hover=$(front)
  screencapture -x "$out/$probe-expanded.png"
  case $probe in
    ctrl-up) cliclick kd:ctrl kp:arrow-up ku:ctrl ;;
    ctrl-down) cliclick kd:ctrl kp:arrow-down ku:ctrl ;;
    ctrl-left) cliclick kd:ctrl kp:arrow-left ku:ctrl ;;
    ctrl-right) cliclick kd:ctrl kp:arrow-right ku:ctrl ;;
    cmd-space) cliclick kd:cmd kp:space ku:cmd ;;
    cmd-n) keys down:cmd tap:n up:cmd ;;
  esac
  sleep 1
  screencapture -x "$out/$probe-result.png"
  echo result=$(front)
  if [[ $probe == cmd-n ]]; then
    sleep 3
    echo 'Ghostty window count after Cmd-N:'
    osascript -e 'tell application "System Events" to tell process "Ghostty" to count windows'
  fi
  cliclick m:1240,714
  sleep 1
  case $probe in
    ctrl-up|ctrl-down) cliclick kp:esc ;;
    cmd-space) cliclick kd:cmd kp:space ku:cmd ;;
  esac
  sleep 2
  echo after-exit=$(front)
  $W list-windows --focused
done
focus
cliclick m:2,360
sleep 2
keys tap:g tap:h tap:o
sleep 1
screencapture -x "$out/search-gho.png"
echo 'Search gho (count and locations read from screenshot)'
cliclick kp:arrow-down
sleep 1
screencapture -x "$out/search-down.png"
cliclick kp:arrow-up
sleep 1
screencapture -x "$out/search-arrows.png"
cliclick kp:return w:300
sleep 2
$W list-windows --focused
focus
cliclick m:2,360
sleep 2
keys tap:w tap:o tap:r tap:k tap:s tap:p tap:a tap:c tap:e tap:space tap:2
sleep 1
screencapture -x "$out/search-workspace-2.png"
cliclick kp:return w:300
sleep 2
$W list-workspaces --focused
$W list-windows --focused
focus
cliclick m:2,360
sleep 2
keys down:cmd tap:space up:cmd
sleep 1
screencapture -x "$out/spotlight-keys-result.png"
cliclick m:1240,714
sleep 1
keys down:cmd tap:space up:cmd
sleep 1
cliclick m:1240,714
sleep 1
cliclick m:2,360
sleep 2
cliclick kp:esc
sleep 1
screencapture -x "$out/search-escape.png"
cliclick m:1240,714
sleep 2
$W open-sidebar
sleep 2
keys tap:n tap:o tap:t
sleep 1
screencapture -x "$out/command-search-not.png"
cliclick kp:return w:300
sleep 2
$W list-workspaces --focused
$W list-windows --focused
focus
echo final=$(front)
$W list-windows --focused
