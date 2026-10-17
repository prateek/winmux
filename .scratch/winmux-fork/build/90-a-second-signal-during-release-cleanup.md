# A second signal during a release's cleanup leaves the worker running

Part of {{UMBRELLA}}.

## What to build

`script/dogfood_release.py` stops its build worker when the release is interrupted: `build_release` catches the interruption, signals the worker's process group, waits, and re-raises. Between the interruption being raised and the cleanup putting its deferring handlers in place, the handlers are still `main`'s, which raise `SystemExit`. A second signal in that window, such as the SIGHUP of a pane closed just after a SIGTERM, raises inside the cleanup and skips it. The worker is in a session of its own, so it keeps building and signing with no parent, and the lock is released while it runs.

Nobody has seen this happen. It was read out of the code in review, and the window is a few bytecodes wide.

## Decisions

- **An interrupted release leaves no worker, however many signals arrive.** The cleanup runs to its end once it has started, and a signal that arrives during it does not replace the first one's exit code.
- **Show it with a test before fixing it**: one that delivers the second signal inside the window through a seam, not by timing.

## Depends on

Nothing.

## Done when

- [x] A test delivers a second signal as the cleanup begins, and the worker's process group is gone and the exit code is the first signal's.
- [x] The existing interruption tests pass two hundred runs in a row under load on Xcode's Python 3.9.

## Sources

- The review of the pull request for **Two CI failures that were not the change's**, 2026-10-13.
