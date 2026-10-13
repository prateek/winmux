# Two CI failures that were not the change's

Part of {{UMBRELLA}}.

## What to build

`Build and test` is the merge gate. It has repeatedly failed for reasons outside the pull request: latency, a hang, and release interruption cleanup.

- **A Nickel helper latency test** failed at 2.5 ms against a 2 ms limit on a pull request that did not touch the helper. Later docs-only runs measured 76.9 ms for a 50-window Filter and 5.0 ms for a hook.
- **The job ran to its 30-minute limit** in `Build and test` on a commit that changed only the handoff. The log was gone before anyone read it. A third run found no macOS runner at all, which is GitHub's and not ours.
- **The release script's SIGTERM test**, `script.test_dogfood_release.DogfoodReleaseTest.test_cli_sigterm_releases_lock_and_stops_worker`, twice got exit 1 instead of 143 on a docs-only pull request. Its failure discarded stderr.

A driver re-runs once and moves on. A gate that fails at random teaches drivers to re-run, and the next real hang will be re-run too.

## Decisions

- **A latency limit is not a pass or fail on a shared runner.** Always assert fixed bounds of 250 ms for the 50-window Filter and 50 ms for the hook: twenty-five times the local limits, because ten times left the Filter bound at 1.3 times a figure CI has already measured. Assert the local 10 ms / 2 ms benchmark instead when `WINMUX_NICKEL_STRICT_LATENCY` is set to anything but `0` or nothing. Keep the warm-up, median of 21, both printed figures and release-helper skip unchanged; no other latency assertion changes.
- **A hang leaves evidence.** Plain sequential `swift test`, including the invocation inside `make check`, enforces a per-test limit automatically for every XCTest case, including async, MainActor and blocked-main-thread tests. A test-only observer starts a watchdog on its own queue. Expiry prints the suite and method and ends the process, so later tests do not run. `WMTestTimeoutSeconds` is 120 seconds, at least ten times the slowest test in the full two-core guest measurement (3.135 seconds), with `WINMUX_TEST_TIMEOUT_SECONDS` as a positive finite seconds override for debugging. Python and cargo remain outside this limit, and the CI workflow remains unchanged.
- **Find the hang if it can be found**: run the full Swift suite exactly ten times in the two-core guest beside four `yes` processes. Report every failure and stall. Fix test timing assumptions in tests; leave product defects and product timeout changes for another issue. The hunt found a controlled-clock test starving on `TestClock`'s background-priority scheduling heuristic. `SerialClockTestCase` scopes the entire clock-driven test invocation to the library's test-only main serial executor, including cancellation; product clocks, deadlines and test assertions stay unchanged.
- **SIGTERM remains exit 143.** Retain stdout and stderr on exit-code or lock failures. Reproduce the problem under load on Xcode's Python 3.9 and the guest's Python before fixing it; add a directed regression that fails without the fix. Do not loosen 143 or insert a synchronization sleep. macOS can return EPERM when a signal targets a process group whose only members are unreaped zombies; cleanup must preserve the original interruption, for its SIGTERM and its SIGKILL alike. The worker must stop and the lock must be released. The SIGTERM test passes two hundred runs in a row under load on CI's Python, and a failure prints the script's stderr.

## Depends on

Nothing.

## Done when

- [x] The latency test passes fifty runs in a row on CI's runner or in a guest held to two cores.
- [x] A test made to sleep past the limit fails by name in `make check`, in well under thirty minutes.
- [x] The pull request says whether a stalling test was found.
- [x] The SIGTERM test passes two hundred runs in a row under load on CI's Python, and a failure prints the script's stderr.

## Sources

- Pull requests [#80](https://github.com/prateek/winmux/pull/80) and [#81](https://github.com/prateek/winmux/pull/81), and their handoffs.
- The [guest failure while landing Column placement](https://github.com/prateek/winmux/issues/90#issuecomment-6009636996): `ColumnPolicyTest.testWindowUnboundWhileHelperReplyIsSuspended` reported that Arrive's helper timed out and restarted.
- The four CI failures of 2026-10-13, recorded in the issue's comments: [pull request #135](https://github.com/prateek/winmux/pull/135), [run 38368388535](https://github.com/prateek/winmux/actions/runs/38368388535), attempts 1 and 2, both SIGTERM exit 1 instead of 143 ([comment](https://github.com/prateek/winmux/issues/90#issuecomment-6141769986)); [pull request #138](https://github.com/prateek/winmux/pull/138), [run 38449897091](https://github.com/prateek/winmux/actions/runs/38449897091), attempts 1 and 2, both latency failures ([comment](https://github.com/prateek/winmux/issues/90#issuecomment-6153506602)).
