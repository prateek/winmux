# Follow-ups: bugs, declined findings, the relay's guest and the docs demos

The fork foundation, #1, is built. This is what its build left behind: one bug found while filming, five review findings that were declined on their pull requests as follow-ups, the first-run screens and props the filming guest still needs, and the hero demos the docs were waiting for. Each child issue is one buildable slice, written to be built by the issue relay without reading the pull requests the findings came from.

## Child issues, in build order

{{CHILDREN}}

The `close` bug comes first: it is small and visible, so it is the first issue the relay builds in a guest end to end. The other code issues are independent of each other. The docs demos come last, because they are filmed on the set the two guest issues finish.

## Running the relay

- The `issue-relay` skill takes its umbrella from the brief it is started with, and stops on a brief that names none. The brief for this umbrella names this issue as the umbrella and the `close` bug as the first issue.
- The relay starts when Prateek asks for it. Opening this umbrella did not start it, and no child has a worktree or a guest until he does.
- The relay has never run end to end in a guest. Expect gaps in the skill on the first issue; the driver fixes them as they turn up and says what changed.
- **Before the builder pass of the first-run screens issue**, the driver checks two things. That issue has the builder rebuild the golden image, while the relay's own guest for it is a clone of the old image and the builder runs on the host. So: the builder's environment has `TART_HOME` set, and renaming `winmux-golden` aside does not disturb the running clone. If either fails, that is a gap in the skill to fix and report.
- A stopped guest named `demo-set` holds the desk as it was dressed by hand, with the first-run screens already clicked. It is for looking at the set, and proves nothing about a fresh clone. Delete it once the first-run screens issue has landed.

## Not part of this

- **The deferred features of #1**: Tabs, trackpad gestures, Display profiles, the `'grid` Presentation and proactive registration of Accessory apps. They are being discussed separately.
- **The checks #1 left for Prateek**: installed and release builds, real wake and unlock, two displays.
- **Releases.** No child issue runs `script/dogfood-release`.

## How the children are written

The same way as the children of #1. **Decisions** are settled. **Defaults chosen for you** are starting points: the implementer may change one and says so in the pull request. Anything a child is silent on is the implementer's call, reported the same way. The terms are defined in [`CONTEXT.md`](https://github.com/prateek/winmux/blob/fork/CONTEXT.md).

## Where the findings came from

- [Issue #35](https://github.com/prateek/winmux/issues/35), the `close` bug as first reported.
- The **Declined** lists in the descriptions of pull requests [#32](https://github.com/prateek/winmux/pull/32) and [#33](https://github.com/prateek/winmux/pull/33).
- Pull requests [#34](https://github.com/prateek/winmux/pull/34) and [#36](https://github.com/prateek/winmux/pull/36), which added the `vm` and `demo` skills and moved the relay into a guest.
