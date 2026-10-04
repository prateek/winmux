import importlib.util
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('dogfood_release', Path(__file__).with_name('dogfood_release.py'))
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class DogfoodReleaseTest(unittest.TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, {'WINMUX_RELEASE_REMOTE': 'fork', 'WINMUX_RELEASE_REPO': 'offline/test'})
        environment.start()
        self.addCleanup(environment.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'repo'
        self.repo.mkdir()
        self.git('init', '-b', 'fork')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Test')
        self.commit('VERSION', '0.5.6\n')
        self.base = self.git('rev-parse', 'HEAD').strip()
        self.lock = Path(self.temp.name) / 'release.lock'
        self.built = []

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True, stderr=subprocess.STDOUT)

    def commit(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        self.git('add', name)
        self.git('commit', '-m', name)

    def run_release(self, args=('--next', '--dry-run'), tags=None, build=None):
        return release.run(args, self.repo, tags=lambda: tags or '',
                           build=build or (lambda version, dry: self.built.append((version, dry))),
                           lock_path=self.lock)

    def tags(self, *names):
        return ''.join(f'{self.base}\trefs/tags/{name}\n' for name in names)

    def test_exact_base_and_numeric_next(self):
        self.commit('Sources/product.swift', 'product')
        self.run_release(tags=self.tags('v0.5.6-dogfood.9', 'v0.51.0-dogfood.99', 'v0.5.6-dogfood.2'))
        self.assertEqual(self.built, [('0.5.6-dogfood.10', True)])
        self.run_release(tags=self.tags('v0.5.6-dogfood.9', 'v0.5.6-dogfood.10', 'v0.5.6-dogfood.2'))
        self.assertEqual(self.built[-1], ('0.5.6-dogfood.11', True))

    def test_no_tag_starts_at_one(self):
        self.run_release(tags=self.tags('v0.51.0-dogfood.9'))
        self.assertEqual(self.built, [('0.5.6-dogfood.1', True)])

    def test_docs_and_drafts_skip(self):
        for path in ('docs/guide.txt', '.scratch/draft', '.claude/skill', 'README.md', 'notes.MD', 'outside.markdown'):
            self.commit(path, 'docs')
        self.run_release(tags=self.tags('v0.5.6-dogfood.1'))
        self.assertEqual(self.built, [])

    def test_product_change_across_several_commits_is_not_lost(self):
        self.commit('Sources/product.swift', 'product')
        self.commit('docs/guide.md', 'docs')
        self.commit('outside.md', 'more docs')
        self.run_release(tags=self.tags('v0.5.6-dogfood.1'))
        self.assertEqual(self.built, [('0.5.6-dogfood.2', True)])

    def test_missing_release_commit_releases(self):
        self.commit('docs/guide.md', 'docs')
        self.run_release(tags='a' * 40 + '\trefs/tags/v0.5.6-dogfood.1\n')
        self.assertEqual(self.built, [('0.5.6-dogfood.2', True)])

    def test_annotated_tag_uses_peeled_commit(self):
        self.commit('docs/guide.md', 'docs')
        self.run_release(tags='b' * 40 + '\trefs/tags/v0.5.6-dogfood.1\n' + self.tags('v0.5.6-dogfood.1^{}'))
        self.assertEqual(self.built, [])

    def test_manual_version_never_skips(self):
        self.commit('docs/guide.md', 'docs')
        self.run_release(('0.5.6-dogfood.7', '--dry-run'), self.tags('v0.5.6-dogfood.1'))
        self.assertEqual(self.built, [('0.5.6-dogfood.7', True)])

    def test_publish_refuses_other_branch_before_network_or_build(self):
        self.git('checkout', '-b', 'topic')
        with self.assertRaisesRegex(release.ReleaseError, 'fork branch'):
            self.run_release(('--next',))
        self.assertEqual(self.built, [])

    def test_dry_run_allows_other_branch(self):
        self.git('checkout', '-b', 'topic')
        self.run_release()
        self.assertEqual(self.built, [('0.5.6-dogfood.1', True)])

    def test_dirty_tracked_staged_and_untracked_refuse_even_dry_run(self):
        for kind in ('tracked', 'staged', 'untracked'):
            with self.subTest(kind=kind):
                path = self.repo / ('VERSION' if kind != 'untracked' else 'scratch.txt')
                path.write_text('dirty')
                if kind == 'staged':
                    self.git('add', 'VERSION')
                with self.assertRaisesRegex(release.ReleaseError, 'dirty'):
                    self.run_release()
                self.git('reset', '--hard', 'HEAD')
                self.git('clean', '-fd')
        self.assertEqual(self.built, [])

    def test_publish_fetches_and_refuses_stale_fork(self):
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'clone', '--bare', str(self.repo), str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        self.commit('Sources/new.swift', 'unpublished')
        with self.assertRaisesRegex(release.ReleaseError, 'pull'):
            self.run_release(('--next',))
        self.assertEqual(self.built, [])

    def test_up_to_date_publish_selects_version(self):
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'clone', '--bare', str(self.repo), str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        self.run_release(('--next',))
        self.assertEqual(self.built, [('0.5.6-dogfood.1', False)])

    def test_lock_waits_and_releases_on_build_failure(self):
        entered, waiting, finish = threading.Event(), threading.Event(), threading.Event()
        errors = []
        def build(version, dry):
            entered.set()
            self.assertTrue(finish.wait(5))
            raise RuntimeError('build failed')
        def first():
            try:
                self.run_release(build=build)
            except RuntimeError as error:
                errors.append(str(error))
        thread = threading.Thread(target=first)
        thread.start()
        self.assertTrue(entered.wait(5))
        def second():
            try:
                with release.ReleaseLock(self.lock, log=lambda message: waiting.set(), interval=0.01):
                    self.assertTrue(finish.is_set())
            except BaseException as error:
                errors.append(str(error))
        waiter = threading.Thread(target=second)
        waiter.start()
        self.assertTrue(waiting.wait(5))
        finish.set()
        thread.join(5)
        waiter.join(5)
        self.assertFalse(thread.is_alive() or waiter.is_alive())
        self.assertEqual(errors, ['build failed'])
        self.assertFalse(self.lock.exists())

    def test_dead_owner_is_not_silently_stolen(self):
        self.lock.mkdir()
        # A child that has exited gives us a known dead PID.
        child = subprocess.Popen(['true'])
        child.wait()
        (self.lock / 'pid').write_text(str(child.pid))
        with self.assertRaisesRegex(release.ReleaseError, 'stale lock'):
            with release.ReleaseLock(self.lock):
                self.fail('stale lock acquired')
        self.assertTrue(self.lock.exists())

    def test_remote_tags_win_over_stale_local_tags(self):
        self.git('tag', 'v0.5.6-dogfood.99')
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'init', '--bare', str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        self.git('push', 'fork', 'fork')
        self.git('tag', 'v0.5.6-dogfood.9')
        self.git('push', 'fork', 'v0.5.6-dogfood.9')
        self.commit('Sources/new.swift', 'product')
        release.run(('--next', '--dry-run'), self.repo,
                    build=lambda version, dry: self.built.append((version, dry)), lock_path=self.lock)
        self.assertEqual(self.built, [('0.5.6-dogfood.10', True)])

    def test_missing_lock_owner_requires_operator_recovery(self):
        self.lock.mkdir()
        with self.assertRaisesRegex(release.ReleaseError, 'no valid owner'):
            with release.ReleaseLock(self.lock, owner_grace=0):
                self.fail('unowned lock acquired')

    def test_lock_rechecks_tags_and_cleanliness_after_wait(self):
        entered, finish, waiting = threading.Event(), threading.Event(), threading.Event()
        errors = []
        listing = ['']
        self.commit('Sources/product.swift', 'product')
        def build(version, dry):
            (self.repo / 'VERSION').write_text('generated build version')
            entered.set()
            if not finish.wait(5):
                raise RuntimeError('timed out waiting for second run')
            self.git('checkout', '--', 'VERSION')
            listing[0] = self.git('rev-parse', 'HEAD').strip() + '\trefs/tags/v0.5.6-dogfood.1\n'
        def output(message):
            if 'waiting for release lock' in message:
                waiting.set()
        def runner(build):
            try:
                release.run(('--next', '--dry-run'), self.repo, tags=lambda: listing[0],
                            build=build, lock_path=self.lock, log=output)
            except BaseException as error:
                errors.append(error)
        first = threading.Thread(target=runner, args=(build,))
        first.start()
        self.assertTrue(entered.wait(5))
        # A real second release must wait before inspecting build-generated changes.
        second = threading.Thread(target=runner, args=(lambda *args: self.built.append(args),))
        second.start()
        try:
            self.assertTrue(waiting.wait(5), 'second release did not wait for the lock')
        finally:
            finish.set()
            first.join(5)
            second.join(5)
        self.assertFalse(first.is_alive() or second.is_alive())
        self.assertEqual(errors, [])
        self.assertEqual(self.built, [])
        self.assertFalse(self.lock.exists())

    def test_cli_sigterm_releases_lock_and_stops_worker(self):
        scripts = self.repo / 'script'
        scripts.mkdir()
        shutil.copy(Path(__file__).with_name('dogfood_release.py'), scripts)
        (scripts / 'dogfood-release-build').write_text('#!/bin/bash\necho READY\nsleep 30\n')
        self.git('add', 'script')
        self.git('commit', '-m', 'scripts')
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'init', '--bare', str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        state = Path(self.temp.name) / 'state'
        process = subprocess.Popen(['python3', str(scripts / 'dogfood_release.py'), '--next', '--dry-run'],
                                   env={**os.environ, 'XDG_STATE_HOME': str(state), 'WINMUX_RELEASE_REMOTE': 'fork'},
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertIn('next version:', process.stdout.readline())
            self.assertEqual(process.stdout.readline().strip(), 'READY')
            process.terminate()
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 143)
            self.assertEqual(list((state / 'winmux-release').glob('*.lock')), [])
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()

    def test_detached_head_refuses_publish_but_allows_dry_run(self):
        self.git('checkout', '--detach')
        with self.assertRaisesRegex(release.ReleaseError, 'fork branch'):
            self.run_release(('--next',))
        self.run_release()
        self.assertEqual(self.built, [('0.5.6-dogfood.1', True)])

    def test_path_whitespace_does_not_turn_source_into_docs(self):
        self.commit(' docs/actually-product', 'product')
        self.run_release(tags=self.tags('v0.5.6-dogfood.1'))
        self.assertEqual(self.built, [('0.5.6-dogfood.2', True)])

    def test_invalid_version_refuses_build(self):
        with self.assertRaisesRegex(release.ReleaseError, 'invalid version'):
            self.run_release(('../elsewhere', '--dry-run'))
        self.assertEqual(self.built, [])

    def test_partial_publish_failure_is_released_on_next_docs_only_land(self):
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'clone', '--bare', str(self.repo), str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        def fails_after_tag(version, dry):
            raise RuntimeError('feed upload failed after version tag was created')
        with self.assertRaisesRegex(RuntimeError, 'feed upload'):
            self.run_release(('--next',), build=fails_after_tag)
        pending = Path(str(self.lock) + '.pending')
        self.assertTrue(pending.exists())
        self.commit('docs/next.md', 'docs')
        self.git('push', 'fork', 'fork')
        self.run_release(tags=self.tags('v0.5.6-dogfood.1'))
        self.assertEqual(self.built, [('0.5.6-dogfood.2', True)])
        self.assertTrue(pending.exists(), 'dry run must not mark a failed publication complete')
        self.run_release(('--next',), tags=self.tags('v0.5.6-dogfood.1'))
        self.assertEqual(self.built[-1], ('0.5.6-dogfood.2', False))
        self.assertFalse(pending.exists())

    def test_source_renamed_into_docs_is_not_skipped(self):
        self.commit('Sources/product.swift', 'product')
        released = self.git('rev-parse', 'HEAD').strip()
        (self.repo / 'docs').mkdir()
        self.git('mv', 'Sources/product.swift', 'docs/product.swift')
        self.git('commit', '-m', 'Move source into docs')
        self.run_release(tags=released + '\trefs/tags/v0.5.6-dogfood.1\n')
        self.assertEqual(self.built, [('0.5.6-dogfood.2', True)])

    def test_build_snapshot_refuses_head_or_non_generated_changes(self):
        self.commit('Sources/Common/versionGenerated.swift', 'generated version')
        self.commit('Sources/Common/gitHashGenerated.swift', 'generated hash')
        head = self.git('rev-parse', 'HEAD').strip()
        (self.repo / 'Sources/Common/versionGenerated.swift').write_text('build version')
        release.verify_tree(self.repo, head)
        (self.repo / 'scratch.txt').write_text('unexpected change')
        with self.assertRaisesRegex(release.ReleaseError, 'changed during'):
            release.verify_tree(self.repo, head)
        (self.repo / 'scratch.txt').unlink()
        self.git('checkout', '--', 'Sources/Common/versionGenerated.swift')
        self.commit('docs/next.md', 'another land')
        with self.assertRaisesRegex(release.ReleaseError, 'HEAD changed'):
            release.verify_tree(self.repo, head)

    def test_checkout_changed_by_build_is_refused(self):
        def concurrent_land(version, dry):
            self.commit('docs/concurrent.md', 'another land')
        with self.assertRaisesRegex(release.ReleaseError, 'HEAD changed'):
            self.run_release(build=concurrent_land)
        self.assertFalse(self.lock.exists())

    def test_finished_long_running_lock_owner_is_not_stale(self):
        self.lock.mkdir()
        (self.lock / 'pid').write_text(str(os.getpid()))
        def owner_finished(message):
            (self.lock / 'pid').unlink()
            self.lock.rmdir()
        with patch.object(release.time, 'monotonic', side_effect=[0, 31, 31]):
            with release.ReleaseLock(self.lock, log=owner_finished):
                self.assertTrue(self.lock.exists())
        self.assertFalse(self.lock.exists())

    def test_empty_environment_overrides_keep_default_remote_and_state(self):
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'clone', '--bare', str(self.repo), str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        home = Path(self.temp.name) / 'home'
        previous = Path.cwd()
        try:
            os.chdir(self.repo)
            with patch.dict(os.environ, {'WINMUX_RELEASE_REMOTE': '', 'WINMUX_RELEASE_REPO': '', 'XDG_STATE_HOME': ''}), patch.object(release.Path, 'home', return_value=home):
                release.run(('--next',), self.repo, tags=lambda: '',
                            build=lambda version, dry: self.built.append((version, dry)))
        finally:
            os.chdir(previous)
        self.assertEqual(self.built, [('0.5.6-dogfood.1', False)])
        self.assertTrue((home / '.local/state/winmux-release').is_dir())
        self.assertFalse((self.repo / 'winmux-release').exists())

    def test_signal_during_worker_spawn_stops_worker_before_unlocking(self):
        scripts = self.repo / 'script'
        scripts.mkdir()
        shutil.copy(Path(__file__).with_name('dogfood_release.py'), scripts)
        (scripts / 'dogfood-release-build').write_text('#!/bin/bash\necho READY\nsleep 30\n')
        self.git('add', 'script')
        self.git('commit', '-m', 'scripts')
        remote = Path(self.temp.name) / 'remote.git'
        subprocess.check_call(['git', 'init', '--bare', str(remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.git('remote', 'add', 'fork', str(remote))
        state = Path(self.temp.name) / 'state'
        state.mkdir()
        pid_file = state / 'worker.pid'
        code = r"""
import os, signal, subprocess, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import dogfood_release as release
original = subprocess.Popen
pid_file = Path(sys.argv[2])
def interrupted_spawn(command, *args, **kwargs):
    process = original(command, *args, **kwargs)
    if command[0] == 'bash' and command[1].endswith('dogfood-release-build'):
        pid_file.write_text(str(process.pid))
        os.kill(os.getpid(), signal.SIGTERM)
    return process
subprocess.Popen = interrupted_spawn
sys.argv = ['script/dogfood-release', '--next', '--dry-run']
sys.exit(release.main())
"""
        process = subprocess.Popen(['python3', '-c', code, str(scripts), str(pid_file)],
                                   env={**os.environ, 'XDG_STATE_HOME': str(state), 'PYTHONDONTWRITEBYTECODE': '1'},
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 143)
            self.assertEqual(list((state / 'winmux-release').glob('*.lock')), [])
        finally:
            if process.poll() is None:
                process.kill()
            if pid_file.exists():
                try:
                    os.killpg(int(pid_file.read_text()), 9)
                except ProcessLookupError:
                    pass
            process.communicate()

    def test_empty_repo_override_shares_the_default_release_lock(self):
        state = Path(self.temp.name) / 'state'
        locks = []
        def build(version, dry):
            locks.append([path.name for path in (state / 'winmux-release').glob('*.lock')])
        for repo in ('prateek/winmux', ''):
            with patch.dict(os.environ, {'WINMUX_RELEASE_REPO': repo, 'XDG_STATE_HOME': str(state)}):
                release.run(('--next', '--dry-run'), self.repo, tags=lambda: '', build=build)
        self.assertEqual(len(locks[0]), 1)
        self.assertEqual(locks[0], locks[1])

    def test_invalid_arguments_and_help_do_not_build(self):
        for args in ((), ('--next', '1.0'), ('--unknown',)):
            with self.subTest(args=args), self.assertRaises(SystemExit):
                self.run_release(args)
        with self.assertRaises(SystemExit) as result:
            self.run_release(('--help',))
        self.assertEqual(result.exception.code, 0)
        self.assertEqual(self.built, [])


if __name__ == '__main__':
    unittest.main()
