# An interrupted release can empty an unfinished one's record

Part of {{UMBRELLA}}.

## What to build

`script/dogfood_release.py` records a publishing run's version in the `.pending` file beside the release lock before its worker starts, and `--next` reads it to finish a release whose tag was created but whose publishing did not complete. `pending.write_text(version)` opens the file with mode `w`, which truncates it, and then writes. A cancellation between the two leaves the file empty. If an earlier run's unfinished version was in it, the record is gone: a later `--next` from a docs-only commit reads nothing unfinished and skips, and that version is never finished.

Nobody has seen this happen. It was read out of the code in review, and it predates the change that found it.

## Decisions

- **Writing the record is all or nothing.** The new version replaces the old in one step, as a temporary file renamed over it.

## Depends on

Nothing.

## Done when

- [ ] A test interrupts the write of `.pending` and the earlier version is still recorded.
- [ ] The existing release tests pass unchanged.

## Sources

- The sixth review of the pull request for **A second signal during a release's cleanup leaves the worker running**, 2026-10-17.
