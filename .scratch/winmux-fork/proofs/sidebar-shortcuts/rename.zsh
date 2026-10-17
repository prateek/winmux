#!/bin/zsh
export TART_HOME=${TART_HOME:?}
export PATH=/opt/homebrew/bin:$PATH
set -eu
root=${1:-$HOME/winmux}
out=$HOME/takes/117/head
W=$root/.build/debug/winmux
keys() { ~/desk/keys "$(date +%s)" "$out/rename-keys-$(date +%s).json" "$@"; }
[[ -x ~/desk/arrow-chord ]] || swiftc ~/desk/arrow-chord.swift -o ~/desk/arrow-chord
enterRename() {
  local before=$(grep -c workspaceContextRename ~/demo/winmux.log || true)
  cliclick rc:90,60
  sleep 1
  cliclick c:164,72
  sleep 2
  local after=$(grep -c workspaceContextRename ~/demo/winmux.log || true)
  [[ $after -gt $before ]] || { echo 'Rename Workspace did not open; stop before typing' >&2; exit 1; }
}
cliclick m:1240,714 ku:fn
$W workspace 1 >/dev/null
sleep 2
cliclick m:2,360
sleep 2
enterRename
screencapture -x "$out/rename-field.png"
keys tap:d tap:e tap:s tap:k
sleep 1
screencapture -x "$out/rename-typed.png"
cliclick kp:return w:300
sleep 3
screencapture -x "$out/rename-committed.png"
$W list-workspaces --all --json
grep 'renameWorkspaceFromSidebar' ~/demo/winmux.log | tail -1
cliclick m:1240,714
sleep 2
cliclick m:2,360
sleep 2
enterRename
screencapture -x "$out/rename-field-before-control-up.png"
~/desk/arrow-chord up
sleep 1
screencapture -x "$out/rename-control-up.png"
~/desk/arrow-chord up
sleep 2
keys tap:escape
cliclick m:1240,714
sleep 2
$W list-windows --focused
cliclick m:2,360
sleep 2
enterRename
keys down:shift tap:w up:shift tap:o tap:r tap:k tap:s tap:p tap:a tap:c tap:e tap:space tap:1
cliclick kp:return w:300
sleep 3
grep 'renameWorkspaceFromSidebar' ~/demo/winmux.log | tail -1
screencapture -x "$out/rename-restored.png"
cliclick m:1240,714
