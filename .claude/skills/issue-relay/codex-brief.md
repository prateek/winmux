# Builder briefs

The driver copies one section into a prompt file and fills each `<…>`.

## First pass

You are building issue #<number> of prateek/winmux, "<title>", in the worktree `<WT>` on branch `<branch>`. You have full write access, the network, and the desktop.

Read first, end to end: `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, the issue (`gh issue view <number> -R prateek/winmux`) and its draft `.scratch/winmux-fork/build/<draft>.md`. The issue is authoritative. Its **Decisions** are settled; a **Default chosen for you** may change when the code argues for it, and you say so.

Build it:

1. Test first, at the seams the issue's **Done when** list names. Every behaviour change gets a test that fails without it.
2. `make check` passes.
3. Do a live run of anything a person can see or operate, CLI output included, and save the captures in `<STATE>/captures/`. Follow the handoff's **Live runs** and **Running a debug build** notes. Save every window's frame first and restore it after, close every app you opened, keep usernames, home paths and machine names out of every capture, and leave any macOS permission prompt unanswered.
   Releases are Prateek's: `script/dogfood-release` runs only when he asks for a release.
4. Update the issue's draft wherever the build departs from it, and the handoff wherever this issue changes what the next builder needs to know, including its status lines.
5. Commit on `<branch>` in commits a reviewer can follow. Leave pushing, the pull request and merging to the driver.
6. Write `<STATE>/pr.md`, the pull request description, as `AGENTS.md` step 4 asks: what changes and why, where it departs from the issue, what was checked and what was not, and a **Live run** section naming each capture file.

Finish with a report: each Done-when item marked met, unmet or not checkable, with its evidence; the commits; the captures; and anything you were unsure of.

## Follow-up pass

You are continuing issue #<number> of prateek/winmux in `<WT>` on `<branch>`, now open as pull request #<pr>. Read its description and review comments (`gh pr view <pr> -R prateek/winmux --comments`) first. The same rules as your first pass apply: `AGENTS.md`, the handoff, tests first, `make check`, live-run captures in `<STATE>/captures/`, and commits on `<branch>`.

Resolve each item:

<pending items, one per line, each with its evidence>

Update `<STATE>/pr.md` for what changed. Finish with a report: each item resolved or not, with its evidence.
