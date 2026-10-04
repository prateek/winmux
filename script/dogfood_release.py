"""Release policy and serialization; signing and publishing stay in the shell worker."""

import argparse
from contextlib import AbstractContextManager
import fcntl
import hashlib
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

# The build rewrites these, and the worker restores them when it exits.
GENERATED = ('Sources/Common/versionGenerated.swift', 'Sources/Common/gitHashGenerated.swift')
# How long a cancelled worker gets to stop before it is killed.
WORKER_GRACE = 10


class ReleaseError(Exception):
    pass


def log(message):
    print(f'[dogfood-release] {message}', flush=True)


def git(repo, *args):
    result = subprocess.run(['git', '-C', str(repo), *args], text=True, capture_output=True)
    if result.returncode:
        raise ReleaseError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.rstrip('\n')


def has_commit(repo, commit):
    return not subprocess.run(['git', '-C', str(repo), 'cat-file', '-e', f'{commit}^{{commit}}'], capture_output=True).returncode


class ReleaseLock(AbstractContextManager):
    """A host-wide lock on a file. The kernel drops it when its holder dies, so a crash leaves nothing to clean up."""

    def __init__(self, path, log=log):
        self.path = Path(path)
        self.log = log
        self.file = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.file = open(self.path, 'w')
        try:
            try:
                fcntl.flock(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                self.log('waiting for release lock')
                fcntl.flock(self.file, fcntl.LOCK_EX)
        except BaseException:
            self.file.close()
            raise
        return self

    def __exit__(self, *exc):
        self.file.close()


def dogfood_tags(base, listing):
    """Maps N to the commit of v<base>-dogfood.N for each such tag in `git ls-remote` output."""
    pattern = re.compile(r'^refs/tags/v' + re.escape(base) + r'-dogfood\.([0-9]+)(\^\{\})?$')
    found = {}
    for line in listing.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        sha, ref = parts
        match = pattern.fullmatch(ref)
        # Annotated tags identify the release commit with their peeled entry.
        if match and (int(match[1]) not in found or match[2]):
            found[int(match[1])] = sha
    return found


def skip_reason(repo, commit):
    """Why nothing since `commit` needs a release, or None when something does."""
    if not commit:
        return None
    if not has_commit(repo, commit):
        log('last release commit is unavailable; releasing')
        return None
    paths = [path for path in git(repo, 'diff', '--no-renames', '--name-only', '-z', commit, 'HEAD').split('\0') if path]
    if not paths:
        return 'no changes'
    if all(path.startswith(('.scratch/', '.claude/', 'docs/')) or path.lower().endswith(('.md', '.markdown')) for path in paths):
        return 'docs-only diff'
    return None


def tree_changes(repo):
    return git(repo, 'status', '--porcelain', '--untracked-files=all', '--', '.',
               *(f':(exclude){path}' for path in GENERATED))


def verify_tree(repo, head_sha):
    if git(repo, 'rev-parse', 'HEAD') != head_sha:
        raise ReleaseError('HEAD changed during the release; run again from the pulled fork')
    if tree_changes(repo):
        raise ReleaseError('working tree changed during the release; commit or stash first')


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
            try:
                process.wait(timeout=WORKER_GRACE)
            except subprocess.TimeoutExpired:
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
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
    parser.add_argument('--next', action='store_true', help='choose VERSION-dogfood.N from release-remote tags; skip when nothing but docs changed since the last release')
    parser.add_argument('--dry-run', action='store_true', help='build, sign and verify; publish nothing; allowed off fork')
    options = parser.parse_args(args)
    if bool(options.version) == options.next:
        parser.error('choose exactly one of --next or a version')
    repo = Path(repo)
    version = options.version
    # The version becomes a tag, so git has to accept it as one.
    if version and (not re.fullmatch(r'[0-9][0-9A-Za-z.+-]*', version)
                    or subprocess.run(['git', 'check-ref-format', f'refs/tags/v{version}']).returncode):
        raise ReleaseError('invalid version: use numbers, letters, dots, plus or hyphens, in a form git accepts as a tag')
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
        # An interrupted build can leave the generated files rewritten; the next build rewrites them anyway.
        if tree_changes(repo):
            raise ReleaseError('working tree is dirty; commit or stash first (including untracked files)')
        head_sha = git(repo, 'rev-parse', 'HEAD')
        listing = None
        if not options.dry_run or (options.next and tags is None):
            # One answer from the remote for both the trunk's head and the tags.
            listing = git(repo, 'ls-remote', remote, 'refs/heads/fork', 'refs/tags/*')
        if not options.dry_run and f'{head_sha}\trefs/heads/fork' not in listing.splitlines():
            raise ReleaseError(f'local fork is not at {remote}/fork; pull --ff-only before releasing')
        if options.next:
            base = (repo / 'VERSION').read_text().strip()
            if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', base):
                raise ReleaseError('VERSION must contain a three-part numeric base')
            released = dogfood_tags(base, tags() if tags else listing)
            number = max(released, default=0)
            commit = released.get(number)
            version = f'{base}-dogfood.{number + 1}'
            if commit and tags is None and not has_commit(repo, commit):
                subprocess.run(['git', '-C', str(repo), 'fetch', '--no-tags', remote, f'refs/tags/v{base}-dogfood.{number}'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            unfinished = pending.read_text().strip() if pending.exists() else None
            if unfinished == f'{base}-dogfood.{number}' and commit == head_sha:
                # Its tag is on this commit, so the worker finishes that release instead of abandoning it.
                version = unfinished
                log(f'finishing {version}: an earlier run created it and did not complete')
            elif unfinished:
                log(f'next version: {version}')
                log(f'an earlier run of {unfinished} did not finish publishing; releasing whatever changed')
            else:
                log(f'next version: {version}')
                reason = skip_reason(repo, commit)
                if reason:
                    verify_tree(repo, head_sha)
                    log(f'skipped: {reason} since v{base}-dogfood.{number}; nothing published')
                    return 0
        if not options.dry_run:
            pending.write_text(version + '\n')
        verify_tree(repo, head_sha)
        (build or (lambda version, dry: build_release(repo, version, dry, head_sha)))(version, options.dry_run)
        if options.dry_run:
            verify_tree(repo, head_sha)
        else:
            # The worker checked the tree before it published; a change after that is not a failed release.
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
