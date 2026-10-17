"""codex-sol launches the pinned codex-acp with full access and the builder's model."""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / '.claude/skills/issue-relay/codex-sol'

FAKE_NPX = '''#!/usr/bin/env python3
import json, os, sys
json.dump(dict(argv=sys.argv[1:], env=dict(os.environ)), sys.stdout)
'''


class CodexSolTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        bin_dir = pathlib.Path(self.temp.name)
        npx = bin_dir / 'npx'
        npx.write_text(FAKE_NPX)
        npx.chmod(0o755)
        env = dict(os.environ, PATH=f'{bin_dir}:{os.environ["PATH"]}',
                   CODEX_PATH='/elsewhere/codex', MODEL_PROVIDER='other', CODEX_API_KEY='k', OPENAI_API_KEY='k',
                   INITIAL_AGENT_MODE='auto-review')
        result = subprocess.run([str(SCRIPT), 'exec', '-f', 'prompt with spaces.md'], env=env,
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.launch = json.loads(result.stdout)

    def test_runs_the_pinned_adapter_with_the_callers_arguments(self):
        self.assertEqual(self.launch['argv'], ['-y', '@agentclientprotocol/codex-acp@2.0.1', 'exec', '-f', 'prompt with spaces.md'])

    def test_asks_for_full_access(self):
        self.assertEqual(self.launch['env']['INITIAL_AGENT_MODE'], 'agent-full-access')

    def test_configures_the_builder_model(self):
        config = json.loads(self.launch['env']['CODEX_CONFIG'])
        self.assertEqual(config['model'], 'gpt-6.1-sol')
        self.assertEqual(config['model_reasoning_effort'], 'medium')

    def test_drops_credentials_and_overrides_from_the_callers_environment(self):
        for name in ('CODEX_PATH', 'MODEL_PROVIDER', 'CODEX_API_KEY', 'OPENAI_API_KEY'):
            self.assertNotIn(name, self.launch['env'])


if __name__ == '__main__':
    unittest.main()
