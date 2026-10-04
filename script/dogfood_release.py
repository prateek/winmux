"""Release policy and serialization; signing and publishing stay in the shell worker."""

import argparse
from contextlib import AbstractContextManager
import hashlib
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


class ReleaseError(Exception):
    pass


def log(message):
    print(f'[dogfood-release] {message}', flush=True)


def git(repo, *args):
    result = subprocess.run(['git', '-C', str(repo), *args], text=True, capture_output=True)
    if result.returncode:
        raise ReleaseError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.rstrip('\n')


class ReleaseLock(AbstractContextManager):
    """A host-wide mkdir lock. Dead owners require explicit operator recovery."""

    def __init__(self, path, log=log, interval=1, owner_grace=30):
        self.path = Path(path)
        self.log = log
        self.interval = interval
        self.owner_grace = owner_grace
        self.owned = False

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        waiting = False
        owner_missing_since = None
        while True:
            try:
                self.path.mkdir(mode=0o700)
                self.owned = True
                try:
                    (self.path / 'pid').write_text(str(os.getpid()))
                except BaseException:
                    self.__exit__(None, None, None)
                    raise
                return self
            except FileExistsError:
                if not waiting:
                    self.log('waiting for release lock')
                    waiting = True
                try:
                    pid = int((self.path / 'pid').read_text())
                    if pid <= 0:
                        raise ValueError('invalid PID')
                    os.kill(pid, 0)
                except ProcessLookupError:
                    raise ReleaseError(f'stale lock at {self.path}; confirm no release is running, then remove that directory')
                except (FileNotFoundError, ValueError):
                    if not self.path.exists():
                        continue
                    if owner_missing_since is None:
                        owner_missing_since = time.monotonic()
                    if time.monotonic() - owner_missing_since >= self.owner_grace:
                        raise ReleaseError(f'lock at {self.path} has no valid owner; confirm no release is running, then remove that directory')
                except PermissionError:
                    owner_missing_since = None
                else:
                    owner_missing_since = None
                time.sleep(self.interval)

    def __exit__(self, *exc):
        if self.owned:
            (self.path / 'pid').unlink(missing_ok=True)
            self.path.rmdir()
            self.owned = False


def latest_tag(base, listing):
    pattern = re.compile(r'^refs/tags/v' + re.escape(base) + r'-dogfood\.([0-9]+)(\^\{\})?$')
    found = {}
    for line in listing.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        sha, ref = parts
        match = pattern.fullmatch(ref)
        if match:
            number = int(match[1])
            # Annotated tags identify the release commit with their peeled entry.
            if number not in found or match[2]:
                found[number] = (ref.removesuffix('^{}'), sha)
    if not found:
        return 0, None, None
    number = max(found)
    ref, sha = found[number]
    return number, ref, sha


def docs_only(repo, commit):
    if not commit:
        return False
    exists = subprocess.run(['git', '-C', str(repo), 'cat-file', '-e', f'{commit}^{{commit}}'], capture_output=True)
    if exists.returncode:
        log('last release commit is unavailable; releasing')
        return False
    paths = git(repo, 'diff', '--no-renames', '--name-only', '-z', commit, 'HEAD').split('\0')
    return all(not path or path.startswith(('.scratch/', '.claude/', 'docs/')) or path.lower().endswith(('.md', '.markdown')) for path in paths)


def verify_tree(repo, head_sha):
    if git(repo, 'rev-parse', 'HEAD') != head_sha:
        raise ReleaseError('HEAD changed during the release; refusing to publish; run again from the pulled fork')
    changes = git(repo, 'status', '--porcelain', '--untracked-files=all', '--', '.',
                  ':(exclude)Sources/Common/versionGenerated.swift',
                  ':(exclude)Sources/Common/gitHashGenerated.swift')
    if changes:
        raise ReleaseError('working tree changed during the release; refusing to publish; commit or stash first')


def build_release(repo, version, dry_run, head_sha):
    command = ['bash', str(repo / 'script/dogfood-release-build'), version]
    if dry_run:
        command.append('--dry-run')
    handled = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)
    original = {signum: signal.getsignal(signum) for signum in handled}
    deferred = []
    process = None
    def defer(signum, frame):
        deferred.append(signum)
    try:
        # Cancellation must not orphan a worker before Popen returns its handle.
        for signum in handled:
            signal.signal(signum, defer)
        process = subprocess.Popen(command, cwd=repo, start_new_session=True,
                                   env={**os.environ, "WINMUX_RELEASE_WORKER": "1", "WINMUX_RELEASE_HEAD": head_sha})
        for signum, handler in original.items():
            signal.signal(signum, handler)
        if deferred:
            raise SystemExit(128 + deferred[0])
        status = process.wait()
    except BaseException:
        for signum in handled:
            signal.signal(signum, defer)
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            process.wait()
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        raise
    finally:
        for signum, handler in original.items():
            signal.signal(signum, handler)
    if status:
        raise ReleaseError(f'build/publish worker exited {status}')


def run(args, repo, tags=None, build=None, lock_path=None, log=log):
    parser = argparse.ArgumentParser(prog='script/dogfood-release', description='Build, sign and publish a WinMux dogfood release. Publishing requires a clean, up-to-date fork checkout.',
        epilog='Overrides: WINMUX_RELEASE_REPO (prateek/winmux), WINMUX_RELEASE_REMOTE (fork), WINMUX_TAP_REPO (prateek/homebrew-tap), WINMUX_SIGN_IDENTITY (WinMux Dogfood Signing).')
    parser.add_argument('version', nargs='?', help='explicit version (never skipped)')
    parser.add_argument('--next', action='store_true', help='choose VERSION-dogfood.N from release-remote tags; skip docs-only changes since the last release')
    parser.add_argument('--dry-run', action='store_true', help='build, sign and verify; publish nothing; allowed off fork')
    options = parser.parse_args(args)
    if bool(options.version) == options.next:
        parser.error('choose exactly one of --next or a version')
    repo = Path(repo)
    branch_result = subprocess.run(['git', '-C', str(repo), 'symbolic-ref', '--quiet', '--short', 'HEAD'], text=True, capture_output=True)
    branch = branch_result.stdout.strip() or 'detached'
    if branch != 'fork' and not options.dry_run:
        raise ReleaseError(f'releases are cut from the fork branch, not {branch}')
    remote = os.environ.get('WINMUX_RELEASE_REMOTE') or 'fork'
    release_repo = os.environ.get('WINMUX_RELEASE_REPO') or 'prateek/winmux'
    if lock_path is None:
        state = Path(os.environ.get('XDG_STATE_HOME') or str(Path.home() / '.local/state'))
        key = hashlib.sha256(release_repo.encode()).hexdigest()[:16]
        lock_path = state / 'winmux-release' / f'{key}.lock'
    pending = Path(str(lock_path) + '.pending')
    with ReleaseLock(lock_path, log=log):
        if git(repo, 'status', '--porcelain'):
            raise ReleaseError('working tree is dirty; commit or stash first (including untracked files)')
        if not options.dry_run:
            git(repo, 'fetch', '--no-tags', remote, 'refs/heads/fork')
            if git(repo, 'rev-parse', 'HEAD') != git(repo, 'rev-parse', 'FETCH_HEAD'):
                raise ReleaseError(f'local fork is not at {remote}/fork; pull --ff-only before releasing')
        head_sha = git(repo, 'rev-parse', 'HEAD')
        version = options.version
        if version and not re.fullmatch(r'[0-9][0-9A-Za-z.+-]*', version):
            raise ReleaseError('invalid version: use numbers, letters, dots, plus or hyphens')
        if options.next:
            base = (repo / 'VERSION').read_text().strip()
            if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', base):
                raise ReleaseError('VERSION must contain a three-part numeric base')
            listing = tags() if tags else git(repo, 'ls-remote', '--tags', remote)
            number, ref, commit = latest_tag(base, listing)
            version = f'{base}-dogfood.{number + 1}'
            log(f'next version: {version}')
            if commit and tags is None:
                exists = subprocess.run(['git', '-C', str(repo), 'cat-file', '-e', f'{commit}^{{commit}}'], capture_output=True)
                if exists.returncode:
                    subprocess.run(['git', '-C', str(repo), 'fetch', '--no-tags', remote, ref], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if pending.exists():
                log('previous publishing run did not finish; releasing even if the diff is docs-only')
            if docs_only(repo, commit) and not pending.exists():
                verify_tree(repo, head_sha)
                log(f'skipped: docs-only diff since v{base}-dogfood.{number}; nothing published')
                return 0
        if not options.dry_run:
            pending.write_text(version + '\n')
        verify_tree(repo, head_sha)
        (build or (lambda version, dry: build_release(repo, version, dry, head_sha)))(version, options.dry_run)
        verify_tree(repo, head_sha)
        if not options.dry_run:
            pending.unlink(missing_ok=True)
    return 0


def main():
    def interrupted(signum, frame):
        raise SystemExit(128 + signum)
    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(signum, interrupted)
    try:
        return run(sys.argv[1:], Path(__file__).resolve().parent.parent)
    except ReleaseError as error:
        print(f'[dogfood-release] error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
