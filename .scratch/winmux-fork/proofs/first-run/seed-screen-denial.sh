#!/bin/bash
# Guest-only fixture for a Screen Recording request that failed to create its disabled row.
# This writes a denial, never a grant, and preserves this bundle's actual code requirement.
# Historical diagnostic only; the verified native filming flow does not use it.
set -euo pipefail
db='/Library/Application Support/com.apple.TCC/TCC.db'
client=com.zimengxiong.winmux.debug
cols=$(sudo sqlite3 "$db" "select group_concat(name) from pragma_table_info('access') where name != 'service'")
sudo sqlite3 "$db" "begin;
insert or replace into access (service,$cols)
select 'kTCCServiceScreenCapture',$cols from access
where service='kTCCServiceAccessibility' and client='$client' and client_type=0;
update access set auth_value=0,auth_reason=4
where service='kTCCServiceScreenCapture' and client='$client' and client_type=0;
commit;"
row=$(sudo sqlite3 "$db" "select auth_value from access where service='kTCCServiceScreenCapture' and client='$client' and client_type=0")
[ "$row" = 0 ] || { echo 'Open Accessibility Settings from WinMux first to register its identity.' >&2; exit 1; }
echo 'WinMux debug Screen Recording: denied (auth_value=0); enable its toggle in System Settings.'
