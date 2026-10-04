# Builder briefs

The driver copies one section into a prompt file and fills each `<…>`.

## First pass

You are building issue #<number> of prateek/winmux, "<title>", in the worktree `<WT>` on branch `<branch>`. You have full write access and the network. The host's desktop is not yours: every debug build runs in a guest.

Read first, end to end: `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, `.claude/skills/vm/SKILL.md`, the issue (`gh issue view <number> -R prateek/winmux --json title,body,comments`) and its draft `.scratch/winmux-fork/build/<draft>.md`. Pass `-R prateek/winmux` to every `gh` command: without it `gh` resolves to upstream, where the same number is a different issue. A `gh` call that fails once is tried again. The issue is authoritative. Its **Decisions** are settled; a **Default chosen for you** may change when the code argues for it, and you say so.

**This is the one full builder pass this issue gets, and it has <hours> hours.** The whole issue is its job. Write the report only when each Done-when item is built, tested and, where visible, checked in a live run. Stopping early with a list of remaining work fails the issue. If something truly cannot be done here, do everything around it and say exactly what and why.

You have no one to ask. Where this prompt or the issue does not settle something, take the answer the issue recommends or the nearest one, record it in the report and in `pr.md` on a line starting "Decided:", and keep going. Record each **Default chosen for you** that you change, by name.

Build it:

1. Test first, at the seams the issue's **Done when** list names. Every behaviour change gets a test that fails without it.
2. `make check` passes on the host and in the guest. The guest's Swift is the version CI pins, so a failure there is a failure in CI.
3. Do a live run of anything a person can see or operate, CLI output included, in the guest `<guest>`, which the driver has already brought up: sync `<WT>`, build, and run the debug build there, as the `vm` skill's steps 2 and 3 say. The live run is how you check your own work; the pull request's demos are filmed later, from the final commit. Save a recording or screenshot of each thing you checked in `<STATE>/captures/`, as evidence for the driver, and read back from WinMux what each run ended on.
   <what this issue's live run must cover, and what earlier issues left unverified that it makes reachable>
   A permission prompt or a window you did not open in the guest is a defect in its image: stop the live run and report it. When the live run ends, quit the debug build and close what you opened, so the next pass starts on a clean desktop.
   The builder never publishes a release; the driver runs `script/dogfood-release --next` on the host after each land. When the issue concerns the release script, the builder may run `script/dogfood-release --dry-run` on the host to build, sign and verify without publishing; record its CLI output as the demo. Installed-build checks, a second display, and real sleep, wake or unlock remain Prateek's: leave them unticked in the draft and record them in the handoff's status line and pull request description.
4. Update the issue's draft wherever the build departs from it, and the handoff wherever this issue changes what the next builder needs to know, including its status lines. Write both as they should read after this issue has landed: no transient status such as "awaiting the driver's push". Name other issues by title, not by number; the numbers of the others are easy to get wrong. Tick a Done-when item in the draft only when it is met. Change nothing in the draft's first three lines, and leave `{{UMBRELLA}}` as it is: the issue body is rendered from them.
5. Commit on `<branch>` in commits a reviewer can follow. Leave pushing, the pull request and merging to the driver. Leave the guest up: the driver deletes it when the issue lands.
6. Write `<STATE>/pr.md`, the pull request description, as `AGENTS.md` step 4 asks: what changes and why, where it departs from the issue, what was checked and what was not. Leave the demos to the demo pass. The repository is public: keep home paths, usernames and machine names out of the description.

Finish with a report, written to `<STATE>/report.md` and repeated in your last message: each Done-when item marked met, unmet or not checkable, with its evidence; each default you changed and each "Decided:"; the commits; what the live run showed; and anything you were unsure of.

## Follow-up pass

You are continuing issue #<number> of prateek/winmux in `<WT>` on `<branch>`, now open as pull request #<pr>. Read its description first (`gh pr view <pr> -R prateek/winmux --json title,body`), and your first pass's prompt, `<STATE>/pass1.prompt.md`, whose rules still hold: `AGENTS.md`, the handoff, tests first, `make check` on the host and in the guest `<guest>`, the live run in the guest, and commits on `<branch>`.

**This is the last builder pass, and it has <hours> hours.** Each item below carries the driver's ruling. A ruling is settled: build it as written, and record under "Decided:" only what it leaves open.

Resolve each item. Every fix gets a test that fails without it: undo the fix, see the test fail, restore it.

<pending items, one per line, each with its evidence and the driver's ruling>

Update `<STATE>/pr.md` for what changed. Finish with a report, written to `<STATE>/report2.md` and repeated in your last message: each item resolved or not, with the test that covers it and whether you saw it fail without the fix.

## Demo pass

You are filming the demos for pull request #<pr> of prateek/winmux, issue #<number>, from the commit it will merge: `<sha>` on `<branch>` in `<WT>`. The code is finished and reviewed; change none of it. The pass has <hours> hours.

Read `.claude/skills/demo/SKILL.md` and `.claude/skills/vm/SKILL.md` end to end. The storyboard is written and checked: `<STATE>/storyboard.md`. Film it, starting at the demo skill's step 3, in the guest `<guest>`, with `$OUT` as `<STATE>`.

- The guest is already up. Sync `<WT>` into it and build it before the first take, so the demos show `<sha>`. Pull the takes out when you finish and leave the guest up: the driver deletes it.
- Film every demo and still in the storyboard and collect every transcript. After each take, read back where WinMux ended and compare it with the storyboard's **Watch**.
- A demo you cannot film is reported with its reason, not replaced by a different claim.
- Render every demo, check every one as the skill's step 5 says, and write the captions into `<STATE>/demos.md`, in the storyboard's order with its headings and its Done-when table.

Finish with a report, written to `<STATE>/demo-report.md` and repeated in your last message: each storyboard entry filmed or not, with where WinMux ended against its **Watch**; each GIF's size; and anything on screen you did not put there.
