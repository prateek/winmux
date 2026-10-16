"""The VM approval recipe and preflight share replayd's observed date rules."""
import datetime as dt
import importlib.util
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '.claude/skills/vm/guest/approvals.py'
CLIENT = '/usr/libexec/sshd-keygen-wrapper'
NOW = dt.datetime(2026, 10, 15, 12)


def load():
    spec = importlib.util.spec_from_file_location('capture_approvals', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CaptureApprovalsTest(unittest.TestCase):
    def setUp(self):
        self.module = load()

    def valid(self):
        return {CLIENT: {
            'kScreenCaptureApprovalLastUsed': NOW,
            'kScreenCaptureApprovalLastAlerted': NOW,
            'kScreenCapturePrivacyHintDate': dt.datetime(2099, 1, 1),
            'kScreenCapturePrivacyHintPolicy': 2592000,
            'kScreenCaptureAlertableUsageCount': 1000000,
        }}

    def test_high_capture_count_and_old_last_alert_do_not_expire_active_approval(self):
        data = self.valid()
        data[CLIENT]['kScreenCaptureApprovalLastAlerted'] = NOW - dt.timedelta(days=365)
        self.assertIsNone(self.module.validate(data, NOW))

    def test_missing_client_and_malformed_records_fail_closed(self):
        for data in ({}, [], {CLIENT: 'broken'}):
            with self.subTest(data=data):
                self.assertIsNotNone(self.module.validate(data, NOW))

    def test_last_use_expires_at_thirty_days_even_with_future_hint(self):
        for age, expired in ((2591999, False), (2592000, True), (2592001, True)):
            data = self.valid()
            data[CLIENT]['kScreenCaptureApprovalLastUsed'] = NOW - dt.timedelta(seconds=age)
            self.assertEqual(self.module.validate(data, NOW) is not None, expired)

    def test_hint_expires_when_its_date_passes_even_with_recent_use(self):
        for age, expired in ((-1, False), (0, False), (1, True)):
            data = self.valid()
            data[CLIENT]['kScreenCapturePrivacyHintDate'] = NOW - dt.timedelta(seconds=age)
            self.assertEqual(self.module.validate(data, NOW) is not None, expired)

    def test_missing_or_wrong_date_types_fail_with_actionable_detail(self):
        for field in ('kScreenCaptureApprovalLastUsed', 'kScreenCapturePrivacyHintDate'):
            for bad in (None, '2099-01-01', 123):
                data = self.valid()
                data[CLIENT][field] = bad
                detail = self.module.validate(data, NOW)
                self.assertIn(field, detail)
                self.assertIn('renew-approvals.sh', detail)

    def test_renewal_preserves_other_clients_and_capture_count_without_adding_guesses(self):
        data = self.valid()
        data['unrelated'] = {'kept': True}
        result = self.module.renew(data, NOW)
        self.assertEqual(set(result), {CLIENT, 'unrelated'})
        self.assertEqual(result['unrelated'], {'kept': True})
        self.assertEqual(result[CLIENT]['kScreenCaptureAlertableUsageCount'], 1000000)
        self.assertEqual(result[CLIENT]['kScreenCaptureApprovalLastUsed'], NOW)
        self.assertEqual(result[CLIENT]['kScreenCapturePrivacyHintDate'], dt.datetime(2099, 1, 1))
        self.assertIsNone(self.module.validate(result, NOW))

    def test_recipe_creates_missing_file_and_preflight_rejects_missing_and_corrupt_files(self):
        with tempfile.TemporaryDirectory() as temp:
            env = dict(os.environ, HOME=temp)
            path = Path(temp) / 'Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist'
            def run(verb):
                return subprocess.run(['python3', str(SCRIPT), verb], env=env,
                                      capture_output=True, text=True, timeout=10)
            missing = run('check')
            self.assertEqual(missing.returncode, 1)
            self.assertIn('renew-approvals.sh', missing.stdout)
            self.assertEqual(run('renew').returncode, 0)
            self.assertEqual(run('check').returncode, 0)
            self.assertEqual(set(plistlib.loads(path.read_bytes())), {CLIENT})
            path.write_bytes(b'broken')
            self.assertEqual(run('check').returncode, 1)
            self.assertEqual(run('renew').returncode, 0)
            self.assertEqual(run('check').returncode, 0)
            self.assertEqual(run('check').stderr, '', 'a passing check prints nothing to merge into preflight')
            path.write_bytes(b'<?xml version="1.0"?><plist version="1.0"><dict><key>')
            truncated = run('check')
            self.assertEqual((truncated.returncode, truncated.stderr), (1, ''))
            self.assertEqual(run('renew').returncode, 0)
            self.assertEqual(run('check').returncode, 0)


GRANT = SCRIPT.parent / 'grant.sh'


class ExistingGrantPathTest(unittest.TestCase):
    def test_image_grant_writes_existing_tcc_services_and_initial_approval_without_boot(self):
        import sqlite3
        import sys
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            binary = root / 'bin'
            binary.mkdir()
            db_path = root / 'system.db'
            with sqlite3.connect(db_path) as db:
                db.execute('create table access (service text, client text, auth_value integer, primary key(service, client))')
                db.execute('insert into access values (?,?,2)', ('kTCCServiceSystemPolicyAllFiles', CLIENT))
            shims = {
                'sudo': '#!/bin/sh\nexec "$@"\n',
                'killall': '#!/bin/sh\nexit 0\n',
                'csrutil': '#!/bin/sh\necho "System Integrity Protection status: disabled."\n',
                'sqlite3': '#!' + sys.executable + '\n' + r'''import os, sqlite3, sys
with sqlite3.connect(os.path.join(os.environ['HOME'], 'system.db')) as db:
    cursor = db.execute(sys.argv[2])
    for row in cursor.fetchall():
        print('|'.join(str(v) for v in row))
''',
            }
            for name, body in shims.items():
                path = binary / name
                path.write_text(body)
                path.chmod(0o755)
            result = subprocess.run(['bash', str(GRANT)], capture_output=True, text=True, timeout=10,
                                    env=dict(os.environ, HOME=str(root), PATH=str(binary) + ':' + os.environ['PATH']))
            self.assertEqual(result.returncode, 0, result.stderr)
            with sqlite3.connect(db_path) as db:
                rows = db.execute('select service,client,auth_value from access').fetchall()
            self.assertEqual({r[0] for r in rows}, {
                'kTCCServiceSystemPolicyAllFiles', 'kTCCServiceAccessibility',
                'kTCCServiceScreenCapture', 'kTCCServicePostEvent', 'kTCCServiceListenEvent'})
            self.assertTrue(all(row[1:] == (CLIENT, 2) for row in rows))
            path = root / 'Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist'
            data = plistlib.loads(path.read_bytes())
            self.assertEqual(set(data), {CLIENT})
            self.assertEqual(data[CLIENT]['kScreenCaptureAlertableUsageCount'], 1)
            self.assertEqual(data[CLIENT]['kScreenCapturePrivacyHintDate'], dt.datetime(2099, 1, 1))
