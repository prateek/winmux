#!/usr/bin/env python3
"""Write and check the replayd approval used by ssh-launched capture clients."""
import datetime as dt
import os
from pathlib import Path
import plistlib
import sys
import tempfile

CLIENT = '/usr/libexec/sshd-keygen-wrapper'
POLICY_SECONDS = 30 * 24 * 60 * 60
HINT_DATE = dt.datetime(2099, 1, 1)
FIX = 'run: bash ~/vm/renew-approvals.sh (missing script: rebuild the golden image: vm build-image)'


def validate(data, now):
    if not isinstance(data, dict) or not isinstance(data.get(CLIENT), dict):
        return 'missing approval for ' + CLIENT + '; ' + FIX
    entry = data[CLIENT]
    for field in ('kScreenCaptureApprovalLastUsed', 'kScreenCapturePrivacyHintDate'):
        if not isinstance(entry.get(field), dt.datetime):
            return 'missing or invalid ' + field + ' for ' + CLIENT + '; ' + FIX
    if (now - entry['kScreenCaptureApprovalLastUsed']).total_seconds() >= POLICY_SECONDS:
        return 'last-use approval lapsed for ' + CLIENT + '; ' + FIX
    if now > entry['kScreenCapturePrivacyHintDate']:
        return 'privacy hint date lapsed for ' + CLIENT + '; ' + FIX
    return None


def renew(data, now):
    result = dict(data) if isinstance(data, dict) else {}
    entry = result.get(CLIENT)
    entry = dict(entry) if isinstance(entry, dict) else {}
    entry.update({
        'kScreenCaptureApprovalLastUsed': now,
        'kScreenCaptureApprovalLastAlerted': now,
        'kScreenCapturePrivacyHintDate': HINT_DATE,
        'kScreenCapturePrivacyHintPolicy': POLICY_SECONDS,
    })
    entry.setdefault('kScreenCaptureAlertableUsageCount', 1)
    result[CLIENT] = entry
    return result


def main():
    verb = sys.argv[1] if len(sys.argv) == 2 else ''
    if verb not in ('check', 'renew'):
        print('usage: approvals.py <check|renew>', file=sys.stderr)
        return 2
    path = Path.home() / 'Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist'
    try:
        data = plistlib.loads(path.read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException):
        data = None
    now = dt.datetime.utcnow()
    if verb == 'check':
        error = validate(data, now)
        if error:
            print(error)
            return 1
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    staged = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            staged = stream.name
            plistlib.dump(renew(data, now), stream, fmt=plistlib.FMT_BINARY)
        os.replace(staged, path)
    finally:
        if staged and os.path.exists(staged):
            os.unlink(staged)
    print('renewed replayd approval for ' + CLIENT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
