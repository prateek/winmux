#!/bin/bash
export TART_HOME="${TART_HOME:?Set TART_HOME before running this proof}"
set -euo pipefail
vm=$1
guest=$2
tree=$3
label=$4
source_id=${5:-49}
target_id=${6:-44}
[[ $source_id =~ ^[0-9]+$ && $target_id =~ ^[0-9]+$ ]]
guest_environment=$(printf 'export TART_HOME=%q' "$TART_HOME")
"$vm" ssh "$guest" "$guest_environment; bash ~/column-drop/off-stage.sh '$tree' '$label' '$source_id' '$target_id'"
"$vm" ssh "$guest" "$guest_environment; export PATH=/opt/homebrew/bin:\$PATH; cliclick dd:970,58 w:300 dm:360,150 w:5000 du:360,150 w:1500" &
drag_job=$!
sleep 2
"$vm" ssh "$guest" "$guest_environment; screencapture -x ~/takes/129/$label-overlay.png"
wait "$drag_job"
"$vm" ssh "$guest" "$guest_environment; ~/$tree/.build/debug/winmux list-windows --all --format '%{app-name} %{window-parent-container-layout}' --json > ~/takes/129/$label-after.json; ~/column-drop/frames > ~/takes/129/$label-after.frames.json; screencapture -x ~/takes/129/$label-after.png"
