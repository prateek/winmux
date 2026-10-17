# A killed release frees its lock while its worker runs

Part of {{UMBRELLA}}.

## What to build

`script/dogfood_release.py` holds the host-wide release lock on a file it opens itself, and starts its build worker with `start_new_session=True` and Popen's default `close_fds=True`. The worker never holds the lock's descriptor. When the release process is killed with SIGKILL, which the release's own signal handling leaves as the way to stop a stuck cleanup, the kernel drops the lock while the worker, in a session of its own, keeps building, signing and publishing. A second `script/dogfood-release --next` then takes the lock and starts a worker of its own, and both publish against the same tags and cask.

Nobody has seen this happen. It was read out of the code in review, and it predates the change that found it.

## Decisions

- **The lock is held until the worker is gone.** A release killed outright leaves the lock held while its worker runs, so the next release waits for that worker instead of racing it.

## Depends on

Nothing.

## Done when

- [ ] A test kills the release with SIGKILL while its worker runs, and a second release waits for the lock until the worker has exited.
- [ ] The existing interruption tests pass unchanged.

## Sources

- The sixth review of the pull request for **A second signal during a release's cleanup leaves the worker running**, 2026-10-17.
