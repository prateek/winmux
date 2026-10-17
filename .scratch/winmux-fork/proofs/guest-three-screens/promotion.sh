#!/bin/bash
# Controlled positive/negative check of the installed Zed's announcement state.
# Run after saving the rich desk's captures and stopping its apps.
set -euo pipefail
database="$HOME/Library/Application Support/Zed/db/0-stable/db.sqlite"
pkill -x zed || true
sleep 2
sqlite3 "$database" "DELETE FROM kv_store WHERE key = 'delta_announcement_dismissed'; INSERT OR REPLACE INTO kv_store VALUES ('auto-updater-should-show-updated-notification', '1');"
open -a Zed ~/scratch-136/note.txt
sleep 12
screencapture -x ~/takes/delta-control-shown.png
pkill -x zed || true
sleep 2
python3 ~/vm/quiet-zed.py
sqlite3 "$database" "SELECT key, value FROM kv_store WHERE key IN ('delta_announcement_dismissed', 'auto-updater-should-show-updated-notification');"
open -a Zed ~/scratch-136/note.txt
sleep 12
screencapture -x ~/takes/delta-control-quiet.png
pkill -x zed || true
