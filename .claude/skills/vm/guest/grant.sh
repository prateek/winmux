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

# macOS re-asks whether a client may bypass the window picker for screen recording; this file
# holds when. Push the date out of reach.
approvals="$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist"
mkdir -p "$(dirname "$approvals")"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$approvals" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>$client</key>
  <dict>
    <key>kScreenCaptureAlertableUsageCount</key><integer>1</integer>
    <key>kScreenCaptureApprovalLastAlerted</key><date>$now</date>
    <key>kScreenCaptureApprovalLastUsed</key><date>$now</date>
    <key>kScreenCapturePrivacyHintDate</key><date>2099-01-01T00:00:00Z</date>
    <key>kScreenCapturePrivacyHintPolicy</key><integer>2592000</integer>
  </dict>
</dict></plist>
PLIST
plutil -convert binary1 "$approvals"
killall replayd 2>/dev/null || true
