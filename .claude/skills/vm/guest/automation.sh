#!/bin/bash
# Let scripts started over ssh drive the apps the staged desk fills by AppleScript.
set -euo pipefail
client=/usr/libexec/sshd-keygen-wrapper
db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
system="/Library/Application Support/com.apple.TCC/TCC.db"
cols=$(sqlite3 "$db" "select group_concat(name) from pragma_table_info('access') where name not in ('service','indirect_object_identifier','indirect_object_identifier_type','auth_value')")
for target in com.apple.Notes com.apple.finder com.apple.systemevents; do
  sudo sqlite3 "$db" "attach '$system' as sys; insert or replace into access (service,indirect_object_identifier,indirect_object_identifier_type,auth_value,$cols) select 'kTCCServiceAppleEvents','$target',0,2,$cols from sys.access where service='kTCCServiceSystemPolicyAllFiles' and client='$client'"
done
sudo chown "$USER" "$db"
killall tccd 2>/dev/null || true
