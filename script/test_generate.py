"""Build provenance through make generate's output, in disposable source trees."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GenerateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ('makefile', 'VERSION', '.gitignore'):
            shutil.copy2(ROOT / name, self.root / name)
        shutil.copytree(ROOT / 'script', self.root / 'script', ignore=shutil.ignore_patterns('__pycache__'))
        common = self.root / 'Sources/Common'
        common.mkdir(parents=True)
        for name in ('gitHashGenerated.swift', 'versionGenerated.swift'):
            shutil.copy2(ROOT / 'Sources/Common' / name, common / name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], env=self.env, text=True).strip()

    def repository(self):
        self.git('init', '-q')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'source')
        return self.git('rev-parse', 'HEAD')

    def check_generate(self, expected):
        subprocess.run(['make', 'generate'], cwd=self.root, env=self.env, check=True, capture_output=True)
        output = (self.root / 'Sources/Common/gitHashGenerated.swift').read_text()
        values = dict(re.findall(r'public let (\w+) = "([^"]*)"', output))
        short = expected if expected == 'unknown' else expected[:8] + ('-dirty' if expected.endswith('-dirty') else '')
        self.assertEqual(values, {'gitHash': expected, 'gitShortHash': short})

    def test_clean_repository_names_head_even_after_repeated_generation(self):
        head = self.repository()
        self.check_generate(head)
        self.check_generate(head)

    def test_dirty_tracked_staged_and_untracked_source(self):
        head = self.repository()
        for kind in ('tracked', 'staged', 'untracked'):
            with self.subTest(kind=kind):
                path = self.root / ('VERSION' if kind == 'tracked' else 'new source.txt')
                path.write_text('changed\n')
                if kind == 'staged':
                    self.git('add', path.name)
                self.check_generate(head + '-dirty')
                self.git('reset', '--hard', '-q')
                if path.name != 'VERSION':
                    path.unlink(missing_ok=True)

    def test_generated_file_changes_do_not_make_source_dirty(self):
        head = self.repository()
        for name in ('gitHashGenerated.swift', 'versionGenerated.swift'):
            (self.root / 'Sources/Common' / name).write_text('// regenerated\n')
        self.git('add', 'Sources/Common')
        self.check_generate(head)

    def test_synced_source_commit_wins_over_guest_repository(self):
        self.repository()
        for suffix in ('', '-dirty'):
            with self.subTest(suffix=suffix):
                expected = '12345678' + 'a' * 32 + suffix
                (self.root / '.source-commit').write_text(expected + '\n')
                self.check_generate(expected)

    def test_source_archive_without_repository_is_unknown(self):
        self.check_generate('unknown')

    def test_source_archive_can_carry_a_synced_commit(self):
        commit = 'abcdef12' + '3' * 32 + '-dirty'
        (self.root / '.source-commit').write_text(commit + '\n')
        self.check_generate(commit)

    def test_invalid_synced_marker_is_unknown_instead_of_guest_head(self):
        self.repository()
        (self.root / '.source-commit').write_text('not a source commit\n')
        self.check_generate('unknown')

    def test_synced_marker_stays_out_of_repository(self):
        head = self.repository()
        (self.root / '.source-commit').write_text(head + '\n')
        self.git('add', '-A')
        self.assertEqual(self.git('ls-files', '.source-commit'), '')

    def test_guest_edit_after_sync_marks_synced_commit_dirty(self):
        self.repository()
        commit = 'abcdef12' + '3' * 32
        (self.root / '.source-commit').write_text(commit + '\n')
        (self.root / 'VERSION').write_text('edited in the guest\n')
        self.check_generate(commit + '-dirty')

    def test_tree_nested_in_another_repository_is_unknown(self):
        self.repository()
        nested = self.root / 'export'
        shutil.copytree(self.root, nested, ignore=shutil.ignore_patterns('.git', 'export'))
        self.root = nested
        self.check_generate('unknown')

    def test_root_typed_in_another_case_names_its_head(self):
        head = self.repository()
        typed = self.root.with_name(self.root.name.swapcase())
        if not typed.exists():
            self.skipTest('case-sensitive file system')
        output = subprocess.check_output(['python3', str(self.root / 'script/source_commit.py'), '--git-only', str(typed)],
                                         env=self.env, text=True).strip()
        self.assertEqual(output, head)

    def test_sha256_repository_names_its_head(self):
        self.git('init', '-q', '--object-format=sha256')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'source')
        self.check_generate(self.git('rev-parse', 'HEAD'))

    def test_generation_with_nothing_changed_leaves_files_untouched(self):
        self.repository()
        subprocess.run(['make', 'generate'], cwd=self.root, env=self.env, check=True, capture_output=True)
        files = [self.root / 'Sources/Common' / name for name in ('gitHashGenerated.swift', 'versionGenerated.swift')]
        for path in files:
            os.utime(path, (1, 1))
        subprocess.run(['make', 'generate'], cwd=self.root, env=self.env, check=True, capture_output=True)
        self.assertEqual([path.stat().st_mtime for path in files], [1, 1])


class CommittedHashTest(unittest.TestCase):
    # `make build` writes a real hash into the tracked file; committing it brings back the stale hash.
    def test_committed_hash_is_unknown(self):
        if (ROOT / '.source-commit').exists():
            self.skipTest("a guest's sync commit holds the host's working copy, not a commit")
        result = subprocess.run(['git', '-C', str(ROOT), 'show', 'HEAD:Sources/Common/gitHashGenerated.swift'],
                                capture_output=True, text=True)
        if result.returncode != 0:
            self.skipTest('no repository')
        self.assertEqual(dict(re.findall(r'public let (\w+) = "([^"]*)"', result.stdout)),
                         {'gitHash': 'unknown', 'gitShortHash': 'unknown'})
