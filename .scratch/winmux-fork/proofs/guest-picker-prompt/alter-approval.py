import datetime
import pathlib
import plistlib
import sys
path = pathlib.Path.home() / 'Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist'
mode = sys.argv[1]
data = plistlib.loads(path.read_bytes())
entry = data['/usr/libexec/sshd-keygen-wrapper']
if mode == 'count':
    entry['kScreenCaptureAlertableUsageCount'] = 1000000
else:
    field = {'used': 'kScreenCaptureApprovalLastUsed', 'alerted': 'kScreenCaptureApprovalLastAlerted', 'hint': 'kScreenCapturePrivacyHintDate'}[mode]
    entry[field] = datetime.datetime.utcnow() - datetime.timedelta(days=31)
path.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_BINARY))
