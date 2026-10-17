"""codex-policy reads the policy a builder pass runs with from its Codex rollout."""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / '.claude/skills/issue-relay/codex-policy'


class CodexPolicyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name) / 'account/home/sessions'
        self.day = self.root / '2026/10/17'
        self.day.mkdir(parents=True)
        self.clock = 1_000_000

    def write(self, name, cwd, approval, sandbox, source='vscode'):
        records = [dict(type='session_meta', payload=dict(cwd=cwd, source=source)),
                   dict(type='turn_context', payload=dict(approval_policy=approval, sandbox_policy=dict(type=sandbox)))]
        path = self.day / f'rollout-{name}.jsonl'
        path.write_text(''.join(json.dumps(record) + '\n' for record in records))
        self.clock += 10
        os.utime(path, (self.clock, self.clock))

    def run_policy(self, cwd):
        return subprocess.run([str(SCRIPT), cwd], env=dict(os.environ, CODEX_SESSIONS=str(self.root)),
                              capture_output=True, text=True, timeout=60)

    def test_full_access_passes_and_names_the_rollout(self):
        self.write('full', '/wt/a', 'never', 'danger-full-access')
        result = self.run_policy('/wt/a')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'rollout-full.jsonl: approval never, sandbox danger-full-access\n')

    def test_auto_review_fails_with_the_policy_it_found(self):
        self.write('sandboxed', '/wt/a', 'on-request', 'workspace-write')
        result = self.run_policy('/wt/a')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('approval on-request, sandbox workspace-write', result.stdout)

    def test_newest_rollout_of_the_worktree_wins_and_subagents_are_skipped(self):
        self.write('old', '/wt/a', 'on-request', 'workspace-write')
        self.write('new', '/wt/a', 'never', 'danger-full-access')
        self.write('other', '/wt/b', 'on-request', 'workspace-write')
        self.write('reviewer', '/wt/a', 'never', 'read-only', source={'subagent': {'other': 'guardian'}})
        result = self.run_policy('/wt/a/')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.startswith('rollout-new.jsonl:'), result.stdout)

    def test_no_rollout_for_the_worktree_is_an_error(self):
        self.write('other', '/wt/b', 'never', 'danger-full-access')
        result = self.run_policy('/wt/a')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no rollout', result.stderr)
