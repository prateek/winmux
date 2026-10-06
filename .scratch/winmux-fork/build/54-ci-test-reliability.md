# Two CI failures that were not the change's

Part of {{UMBRELLA}}.

## What to build

`Build and test` is the merge gate. Twice it failed for a reason outside the pull request, and a re-run passed.

- **A Nickel helper latency test** failed at 2.5 ms against a 2 ms limit on a pull request that did not touch the helper.
- **The job ran to its 30-minute limit** in `Build and test` on a commit that changed only the handoff. The log was gone before anyone read it. A third run found no macOS runner at all, which is GitHub's and not ours.

A driver re-runs once and moves on. A gate that fails at random teaches drivers to re-run, and the next real hang will be re-run too.

## Decisions

- **A latency limit is not a pass or fail on a shared runner.** The test keeps its measurement and asserts a bound loose enough to hold on CI (ten times the local figure), or compares against a baseline taken in the same run. The tight figure stays as a local benchmark.
- **A hang leaves evidence.** `make check` runs the Swift tests with a per-test time limit below the job's, so a hanging test fails by name and the log survives.
- **Find the hang if it can be found**: run the suite repeatedly in a guest, under load, and report whether any test stalls.

## Depends on

Nothing.

## Done when

- [ ] The latency test passes fifty runs in a row on CI's runner or in a guest held to two cores.
- [ ] A test made to sleep past the limit fails by name in `make check`, in well under thirty minutes.
- [ ] The pull request says whether a stalling test was found.

## Sources

- Pull requests [#80](https://github.com/prateek/winmux/pull/80) and [#81](https://github.com/prateek/winmux/pull/81), and their handoffs.
