#!/bin/bash
set -euo pipefail
case_name=$1
source_dir=$2
config_name=$3
bash "$HOME/quit-tools/prepare-case.sh" "$case_name" "$source_dir" "$config_name"
"$source_dir/.build/debug/winmux" enable off
sleep 3
bash "$HOME/quit-tools/finish-case.sh" "$case_name" menu
