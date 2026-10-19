# Builder briefs

Each prompt file is **Every pass** followed by one pass's section, copied whole, with each `<…>` filled. The builder never sees this file, so each prompt file carries both sections.

## Every pass

Before anything else, in every shell you use: `export TART_HOME=<TART_HOME>`. The `vm` script refuses to run without it. Every command in the guest goes through `vm ssh`, `vm push`, `vm pull`, `vm sync`, `vm build` or `vm check`: never `tart exec` or Tart's guest agent, which raises a Screen Recording prompt of its own. The guest is the driver's: resize or reboot it only where this pass's section says to, grant no permission prompt, and touch neither the golden image nor any other guest. If `tart list` shows it stopped, `vm up <guest>` boots it with its disk intact. Report `tart list` as you leave it.

Edit files with `apply_patch`, not with a Python script that rewrites them. Run anything that takes more than a few seconds, a build, a check, a staging script, a live run or a take, in the background and wait for it with one yield of 120 seconds, or the longest yield the tool accepts; repeat that single long wait only while it is still running, then read its output. A loop of short waits is polling, and it costs a model turn each time.

This pass writes one report, named in its section, once, at the end. Your last message is that report's path and nothing more.

## First pass

You are building issue #<number> of prateek/winmux, "<title>", in the worktree `<WT>` on branch `<branch>`. You have full write access and the network. The host's desktop is not yours: every debug build runs in a guest.

Read first, end to end: `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, `.claude/skills/vm/SKILL.md`, the issue (`gh issue view <number> -R prateek/winmux --json title,body,comments`) and its draft `.scratch/winmux-fork/build/<draft>.md`. Pass `-R prateek/winmux` to every `gh` command: without it `gh` resolves to upstream, where the same number is a different issue. A `gh` call that fails once is tried again. The issue is authoritative. Its **Decisions** are settled; a **Default chosen for you** may change when the code argues for it, and you say so.

**This is the one full builder pass this issue gets, and it has <hours> hours.** The whole issue, or the part the rulings name, is its job. Write the report only when each Done-when item is built, tested and, where visible, checked in a live run. Stopping early with a list of remaining work fails the issue. If something truly cannot be done here, do everything around it and say exactly what and why.

You have no one to ask. Where this prompt or the issue does not settle something, take the answer the issue recommends or the nearest one, record it in the report and in `pr.md` on a line starting "Decided:", and keep going. Record each **Default chosen for you** that you change, by name.

<the driver's rulings, numbered. These are settled: build them as written, and list each that a reviewer would not guess under **Decisions the relay made** in `pr.md`. Where the prototype and the issue's Decisions disagree, the Decisions win.>

<the order of importance when time runs short, with `report.md` and `pr.md` ahead of the live run's extras and the docs.> Write `report.md` and `pr.md` once, when the build is done; when time runs short, they come before the extras, as the order says.

Build it:

<for a prototype issue, whose deliverable is a page or a throwaway program rather than a change to WinMux, the rulings say what stands in for steps 1 and 3: which interactions are exercised in a real browser or run, what self-check replaces a Swift test, and what the live run captures, as #130's did.>


1. Test first, at the seams the issue's **Done when** list names. Every behaviour change gets a test that fails without it. A test asserts behaviour through a seam, never the text of a source file. When the change routes existing paths through a new function, test those paths' behaviour first, with the feature off, and name them. Trust a red or green run only when its log, with colour escapes stripped (`sed 's/\x1b\[[0-9;]*m//g'`), shows `Build complete!` and the executed test count moved for a test you added: a failed build leaves the previous test binary for `swift test --skip-build` to run.
2. `make check` passes on the host and in the guest. The guest's Swift is the version CI pins, so a failure there is a failure in CI; a pass there is not yet a pass in CI, whose toolchain is swift.org's. Do not declare a type inside a function that a nested function captures: CI's compiler aborts on it with "Failed to reconstruct type". Keep SwiftUI expressions short, with explicitly typed locals, and never mix `CGFloat` and `Double` arithmetic inline: CI's compiler gave up type-checking one such Column-mark expression in #249 that the host and guest compiled in milliseconds. `make check` runs the script tests with plain `python3` and no third-party packages. `vm check` quits a running debug WinMux first: run it before the live run, or start the debug build again after it.
3. Do a live run of anything a person can see or operate, CLI output included, in the guest `<guest>`, which the driver has already brought up: sync `<WT>`, build, and run the debug build there, as the `vm` skill's steps 2 and 3 say. The live run is how you check your own work; the pull request's demos are filmed later, from the final commit. Save a recording or screenshot of each thing you checked in `<STATE>/captures/`, as evidence for the driver, and read back from WinMux what each run ended on. For every Search the live run uses, write the number of matches and where they fall in `<STATE>/captures/index.md`; the storyboard is written from those counts. When the issue claims behaviour is unchanged, put the base commit's tree in a second directory in the guest with `vm push`, build it there over `vm ssh` (`vm sync` and `vm build` only know `~/winmux`), and run one script against both.
   <what this issue's live run must cover, and what earlier issues left unverified that it makes reachable>
   Until **A read-only command drops the refresh it cancels, and a new window stays unmanaged** lands, do not poll `list-windows` or another read-only command while a refresh is expected: each one cancels the refresh in progress and schedules none, so a new window can stay unlisted on every build. Wait a fixed time without running `winmux`, then read back once.
   Only a permission prompt for WinMux or for the tool driving it stops the live run and is reported as a defect in the image. "… is requesting to bypass the system private window picker" is one: do not grant it, screenshot it through `vm ssh`, and say what was left unchecked. Dismiss anything else that appears, name it in the report as a screen the image recipe should settle, and continue the run; do not click the wallpaper. When the live run ends, quit the debug build and close what you opened, so the next pass starts on a clean desktop.
   The builder never publishes a release; the driver runs `script/dogfood-release --next` on the host after each land. When the issue concerns the release script, the builder may run it on the host with `--dry-run`, which builds, signs and verifies without publishing, and from its own branch without `--dry-run` to show the refusal; record the CLI output as the demo. Installed-build checks, a second display, and real sleep, wake or unlock remain Prateek's: leave them unticked in the draft and record them in the handoff's status line and pull request description.
4. Update the issue's draft wherever the build departs from it, and the handoff wherever this issue changes what the next builder needs to know, including its status lines. Write both as they should read after this issue has landed: no transient status such as "awaiting the driver's push". Name other issues by title, not by number; the numbers of the others are easy to get wrong. Tick a Done-when item in the draft only when it is met. What the build settles and checks goes under the draft's `## Built and checked` section; leave its **Decisions** and **Defaults chosen for you** as they are, since they read as Prateek's in the issue body, and say there where the build departs from a Default. Change nothing in the draft's first three lines, and leave `{{UMBRELLA}}` as it is: the issue body is rendered from them.
5. Commit on `<branch>` in commits a reviewer can follow. Leave pushing, the pull request and merging to the driver. Leave the guest up: the driver deletes it when the issue lands.
6. Write `<STATE>/pr.md`, the notes the driver writes the pull request description from: what changes and why, where it departs from the issue, what was checked and what was not, and each "Decided:" line. Leave the demos to the demo pass. The repository is public: keep home paths, usernames, machine names and IP addresses out of it.

Finish with the report, written to `<STATE>/report.md`: each Done-when item marked met, unmet or not checkable, with its evidence; each default you changed and each "Decided:"; the commits; what the live run showed; and anything you were unsure of.

## Follow-up pass

You are continuing issue #<number> of prateek/winmux in `<WT>` on `<branch>`, now open as pull request #<pr>. Read its description first (`gh pr view <pr> -R prateek/winmux --json title,body`), and your first pass's prompt, `<STATE>/pass1.prompt.md`, whose rules still hold: `AGENTS.md`, the handoff, tests first, `make check` on the host and in the guest `<guest>`, the live run in the guest, and commits on `<branch>`.

**This is the last builder pass, and it has <hours> hours.** Each item below carries the driver's ruling. A ruling is settled: build it as written, and record under "Decided:" only what it leaves open.

Resolve each item. Every fix gets a test that fails without it: undo the fix, see the test fail, restore it.

<pending items, one per line, each with its evidence and the driver's ruling>

Update `<STATE>/pr.md` for what changed. Finish with the report, written to `<STATE>/report2.md`: each item resolved or not, with the test that covers it and whether you saw it fail without the fix.

## Demo pass

You are filming the demos for pull request #<pr> of prateek/winmux, issue #<number>, from the commit it will merge: `<sha>` on `<branch>` in `<WT>`. The code is finished and reviewed; change none of it. The pass has <hours> hours.

Read `.claude/skills/demo/SKILL.md` and `.claude/skills/vm/SKILL.md` end to end. The storyboard is written and checked: `<STATE>/storyboard.md`. Film it, starting at the demo skill's step 3, in the guest `<guest>`, with `$OUT` as `<STATE>`.

- The driver has brought the guest up at the display size the storyboard needs. Do not stop, restart or resize it to change that size: a guest started from your shell dies with it.
- Start filming at 3 cores and 5120 MB. If it stutters, `vm stop <guest>` and then `VM_CPU=4 VM_MEMORY=6144 vm up <guest>` (4 cores and 6 GB), which keeps the guest's disk and its build; beside one default guest this is exactly the cap. Report what you saw and the size used.
- The guest is already up. Sync `<WT>` into it and build it before the first take, so the demos show `<sha>`. Pull the takes out when you finish and leave the guest up: the driver deletes it.
- Film every demo and still in the storyboard and collect every transcript. After each take, read back where WinMux ended and compare it with the storyboard's **Watch**.
- A demo you cannot film is reported with its reason, not replaced by a different claim. A take that misses its **Watch** because of staging or timing is filmed again; one that misses because WinMux did the wrong thing is reported as it is. When a count on the desk differs from the storyboard, film what is true and say so.
- Leave the desk's settings as the staging wrote them, Zed's `trust_all_worktrees` included.
- <what changed since the builder's last live run and no live run has seen. Look at these hardest and report on them first, by name.>
- Render every demo, check every one as the skill's step 5 says, and write the captions into `<STATE>/demos.md`, in the storyboard's order with its headings and its Done-when table.

Finish with the report, written to `<STATE>/demo-report.md`: each storyboard entry filmed or not, with where WinMux ended against its **Watch**; each GIF's size; and anything on screen you did not put there.
