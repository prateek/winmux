#!/bin/bash
# Give everything started over ssh the services a debug WinMux, screencapture and cliclick need.
# The Cirrus images ship with SIP off, so the rows can be written directly.
set -euo pipefail
client=/usr/libexec/sshd-keygen-wrapper
db="/Library/Application Support/com.apple.TCC/TCC.db"
csrutil status | grep -q disabled || { echo "SIP is on; the grants cannot be written"; exit 1; }
cols=$(sudo sqlite3 "$db" "select group_concat(name) from pragma_table_info('access') where name != 'service'")
for service in kTCCServiceAccessibility kTCCServiceScreenCapture kTCCServicePostEvent kTCCServiceListenEvent; do
  sudo sqlite3 "$db" "insert or replace into access (service,$cols) select '$service',$cols from access where service='kTCCServiceSystemPolicyAllFiles' and client='$client'"
done
sudo killall tccd 2>/dev/null || true

# ScreenCaptureKit's private-picker approval is separate from the TCC grant above.
bash "$(dirname "$0")/renew-approvals.sh"
