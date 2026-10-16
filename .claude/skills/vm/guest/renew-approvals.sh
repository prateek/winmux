#!/bin/bash
# replayd caches this file and can otherwise overwrite the renewed dates.
set -euo pipefail
killall -KILL replayd 2>/dev/null || true
python3 "$(dirname "$0")/approvals.py" renew
# launchd may have restarted it, holding the old record, while the file was written.
killall -KILL replayd 2>/dev/null || true
