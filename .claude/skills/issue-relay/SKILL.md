---
name: issue-relay
description: Run the issue relay on prateek/winmux, where Codex builds the next child issue of the umbrella issue the brief names, an Opus driver reviews, fixes and merges it, then hands off to the next driver. Use when a handoff brief or Prateek says to run or continue the relay.
---

# Issue relay

You are the **driver**. Each driver lands exactly one child issue of the **umbrella**, the issue on prateek/winmux that the brief names as the relay's umbrella, then passes the baton. Codex is the **builder**: it writes the code and the tests, checks its work in a live run, and films the demos. You judge, fix and land. `AGENTS.md` at the repo root is the landing process; this skill adds who does each step and when the relay stops.

Run from the worktree the brief started you in. Trunk is `fork/fork` after a `git fetch fork`; write it that way, since bare `fork` names both a remote and a branch here and is ambiguous. Read it with `git show`, since another session may hold the worktree that has `fork` checked out. The issue's worktree is removed when the issue lands, and the next driver starts beside you.

Every debug build runs in a **guest**, a Tart VM from the `vm` skill, named `relay-<issue number>`. The host's desktop is never part of a run. A driver holds one guest: two relays can run side by side; a third waits.

Paths below: `$SKILL` is this skill's directory, `$VM` is `.claude/skills/vm/vm`, `$WT` the issue worktree, and `$STATE` is `${XDG_STATE_HOME:-$HOME/.local/state}/issue-relay/<issue number>`, which holds the builder's prompts, logs, captures, storyboard, demos and description draft.

## 1. Orient

Read the brief named in your prompt, `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, and the `vm` and `demo` skills end to end. Confirm the relay can finish: the installed `ho` skill (`~/.agents/plugins/plugins/utils-agent/skills/ho/SKILL.md`) must lack `disable-model-invocation`, or step 11 cannot run, and `tart list` must show `winmux-golden`.

Done when you can name the umbrella, and the issue the brief points to or that it points to none, `ho` is invocable, and the golden image exists.

## 2. Pick the issue

Take the brief's next issue. When it names none, take the open child of the umbrella whose blockers are all closed, preferring the one the handoff's **Next** line names. A child the handoff lists as **Done, with checks left** is not buildable: its remaining installed-build and hardware checks are Prateek's. Read the issue and its draft in `.scratch/winmux-fork/build/`.

A child labelled `blocked on Prateek` is not buildable. Before taking an issue, read the open children of **Open with Prateek** (prateek/winmux #84). When the issue builds on a question still open there, label it `blocked on Prateek`, comment with the question's number, and take the next child. A rule Prateek has not agreed to is not built on, whatever the draft says.

Done when you have one issue number and its draft. When no buildable child of the umbrella is open, the relay is over: stop and tell Prateek.

## 3. Cut the worktree and bring up the guest

`git fetch fork`, then `orca worktree create --repo id:b2cfff9e-e8d3-4db1-9795-83a57e421be8 --name <slug> --no-parent`, then `make helper` in it. Orca creates the branch too, as `prateek/<slug>`: use that name in the builder's prompt and when deleting the remote branch. Then `$VM up relay-<issue number>`. Export `TART_HOME` in every shell, put `TART_HOME=<value>` in front of every builder launch line, and fill its value into every builder brief.

The guest is yours to keep alive. Bring it up yourself: a guest a builder starts from its own shell dies with that shell's session. After every builder pass read `tart list`; `$VM up` a stopped guest again, which keeps its disk and its build. When a builder left it resized, rebooted or showing a prompt, `$VM down` it and bring up a fresh one for your own `make check`, and give the demo pass a fresh clone after a long builder pass. If `up` refuses the two-guest limit or resource cap, say you are waiting and retry every few minutes until room is free; this is a wait, not a stop. A fresh guest failing preflight is still a stop.

Done when `$WT` is on a fresh branch at `fork/fork` and the guest's preflight passes.

## 4. Builder pass

Fill [codex-brief.md](codex-brief.md)'s **First pass** into `$STATE/pass1.prompt.md`. Its rulings slot is where you settle what the issue leaves open, before the builder guesses. Number them, with file and line references at a named commit and the names that must be gone afterwards. Write each ruling for the case it is about and say what stays the same in the neighbouring cases; read it for what the person does next, not only for what the issue says; check it against the prototype; where the prototype and the issue's Decisions disagree the Decisions win, and the ruling says so. Its order-of-importance slot says what to keep when time runs short. Its `<hours>` is the launch's `--timeout` in hours, four as written below; change both together. Launch it in the background (`run_in_background`) through the shared ACPX view, and wait for the notification:

```sh
TART_HOME=<TART_HOME> ~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --log "$STATE/pass1.log" --label sol -- \
  --cwd "$WT" --format text --suppress-reads --approve-all --timeout 14400 --prompt-retries 2 \
  --agent "$SKILL/codex-sol" exec -f "$STATE/pass1.prompt.md"
```

The notification is the signal that the builder ended; `<log>.exit` holds its exit code and is the fallback when a notification is missed. The log ends `[done] end_turn` when the builder finished its turn. Exit 129 means the pane was closed, not that the builder failed. Exit 0 is not the report: check that `report.md` and `pr.md` exist, since a builder can end with its code committed and its paperwork missing.

Done when the log ends on the builder's report, and `$WT` has its commits and `$STATE` has `pr.md` and `report.md`. A builder that stopped short, by timeout or otherwise, leaves its work in `$WT`; what is missing becomes pending work for step 7.

## 5. Verify and open the pull request

Read the whole diff, test hunks, vendored and generated files included, against the issue's **Decisions** and not only its Done-when list: a builder can meet every Done-when item and still build a default a Decision overrules. Look for guards removed and fields given a second meaning, which is how a builder widens a change to satisfy a ruling, and compare the builder's verdicts with its own numbers. Read the builder's report against `$STATE/captures/`: each visible Done-when item it marks met has a capture that shows it. Run `make check` yourself, on the host and in the guest (`$VM sync relay-<n> $WT`, then `$VM check relay-<n>`). Then follow `AGENTS.md` steps 3, 4 and 6: push, open the pull request as a draft, and wait for CI. `$STATE/pr.md` is raw material for the description: read it for home paths, capture file names and overclaims, and write the description yourself. The demos come in step 8.

**Waiting for CI.** After a push, wait until a run exists for the head commit: `gh pr checks` says "no checks reported" for about a minute, and `--watch` can return the previous run's result. Wait in the background, since a run outlasts a foreground command: `gh run watch <id> --exit-status`. Then read the conclusion from `gh pr view --json statusCheckRollup,headRefOid`; do not take it from `gh pr checks --watch`, which can report the run before yours. Read the first red run's log at once, before any re-run, and fetch a timed-out job's log straight away, because it does not last. A green `make check` in the guest does not promise green CI until **One pinned toolchain for CI, the guest and the release** lands: both are Swift 6.2.4, from different toolchains.

Done when the draft pull request is open and `Build and test` has a result.

## 6. Review and fix

Run `/code-review high <pull request number>`, telling it the pull request is on `prateek/winmux`. Tell it what the change claims, so it compares paths with the base; for a second run give it the commit range and what those commits claim to fix. It runs for about ten minutes in the background. Verify each finding against the code, and check a finding's precondition in the code before declining it as rare. Fix the ones that hold, each with a test seen to fail without its fix where a test can show it, and record each declined finding with its reason in the description. Push, and wait for CI.

Done when every finding is fixed or declined with a reason, and CI is green on the head.

## 7. Second builder pass, at most one

Something is **pending** when a Done-when item is unmet, a visible one has no live-run evidence, a CI failure is the change's own, or a finding is too large to fix inline. With anything pending, fill **Follow-up pass** into `$STATE/pass2.prompt.md` with the list and a ruling on each item, launch it as in step 4 with `pass2` names, then repeat steps 5 and 6 on the new commits.

A Done-when item ends one of three ways: met, with its evidence; left to Prateek, because it needs an installed build, a real keyboard or hardware a guest lacks, and added to his checks in step 10; or pending. An item a guest could meet and the first pass did not is pending. Landing with it unticked and no second pass is not one of the three.

Done when nothing is pending. Anything still pending after the second pass and your own fixes is a stop.

## 8. Demos

The demos are filmed once, from the commit that will merge, so they show the fixes too. Finish the review's fixes before the storyboard goes out: the demos are then the fixes' live check, and a fix after filming costs a fresh guest, a `make check` and a whole filming. Start at 3 cores and 5120 MB. If filming stutters, `$VM stop` the guest and bring it up again with `VM_CPU=4 VM_MEMORY=6144 $VM up`; beside one default guest this is exactly the cap. Report the smoothness and size.

Write `$STATE/storyboard.md` yourself, as the `demo` skill's step 1 says: you have read the issue, the diff and the review, and the storyboard is where you decide what a reviewer needs to see. A **Watch** that names a count takes it from the match counts the first pass wrote in `captures/index.md`, not from a guess. Name in the demo brief each thing no live run has seen since the builder's last one. Then fill **Demo pass** into `$STATE/demo.prompt.md` and launch it as in step 4 with `demo` names.

Check every demo the builder made as the `demo` skill's step 5 says, and each take's reported ending against its **Watch**. Attach the GIFs with `gh attach --repo prateek/winmux <pull request number> <files>` and put the captions from `$STATE/demos.md` into the description.

- A demo that cannot be filmed stays in the Done-when table with its reason.
- A take that misses its **Watch** because of the filming is filmed again: launch the demo pass once more, with the list.
- A take that shows the change is wrong is a finding. Fix it as step 6 says, then film every demo again from the new head. If the second filming still shows it wrong, that is a stop.

A change with nothing to see or operate skips the builder: the description says there is nothing to show. When every claim is a still or a transcript, collect them yourself in a fresh clone and say so in the description.

Done when the description has the demos under their captions with the Done-when table, or says there is nothing to show.

## 9. Merge

The merge gate holds when all of these do:

- `Build and test` is green on the head.
- The head contains the tip of `fork/fork` (`git merge-base --is-ancestor fork/fork HEAD` after a fetch; otherwise merge `fork/fork` in, push and wait for CI).
- `make check` passed in the guest on the head itself. It takes a few minutes; run it again after any commit.
- Every finding is fixed or declined with a reason.
- The description has the demos or says there is nothing to show. The demos show the head. When a commit lands after filming, film again, unless the commit cannot change what a demo shows; then the description names the filmed commit, the commits since and why no demo changes.
- Every Done-when item is met or left to Prateek as step 7 says.
- When your harness gives you a reviewer or advisor tool that you would consult before merging and it is unavailable, do not merge on your own reading alone: ask a second model through the `utils-agent:acpx` skill to check the gate against this list, and say so in the description.

When the gate holds, `gh pr ready <pull request number> -R prateek/winmux`, and squash-merge as `AGENTS.md` step 7 says: `gh pr merge <pr> -R prateek/winmux --squash --match-head-commit <sha> --body-file <file>`. Pass no `--subject`, so the subject stays `<title> (#<pr>)`, and no `--delete-branch`. The body ends with `Closes #<issue>` and the `Co-Authored-By` line. Prateek authorised merging under this gate; it replaces his per-merge go-ahead for the relay only.

A question no issue settles does not stop the relay. Take the recommended answer, and list it in the description under **Decisions the relay made** so Prateek can reverse it. A new or vendored dependency is listed there with its tradeoff. A decision listed there is final unless he says otherwise; it is not repeated in a brief. When you expect him to reverse one, or it sets a rule a later issue builds on, it is also a question for step 10.

## 10. Land

An issue body is its draft **rendered**: without the draft's first two lines (the title heading and the blank after it), with `{{UMBRELLA}}` replaced by the number of the umbrella the issue is a child of, as `#<number>` (#84 for **Prateek's checks**, the build umbrella for a build issue), and `{{CHILDREN}}` replaced by one `- [ ] #<number>` line per child, in order. Before updating a body, compare the live body with the draft rendered at the commit before this change, ignoring a trailing newline; any other difference is an edit made only on GitHub, and a stop. Make the comparison here, at Land, with a command whose output you read: `diff <(awk 1 live.md | sed 's/^- \[x\]/- [ ]/') <(awk 1 expected.md)`. A ticked box is not a difference: GitHub ticks an umbrella's list, and Prateek ticks his checks. #84 and #85 are edited in place and never rendered over: add your line to the live body and the same line to the draft, and leave every tick as it is. Update the body. GitHub closes the issue and ticks the umbrella's list itself from `Closes #<issue>`, within a minute of the merge; check both, and close or tick by hand only what it left. Then `git fetch fork`.

Then cut the release as `AGENTS.md`'s Releases section says, after the squash merge and before removing the issue worktree: in the checkout that has `fork` checked out, or a temporary one, `git pull --ff-only` and then `script/dogfood-release --next`, **on the host**, with the full output saved to `$STATE/release.log`. Read the worktree list from `git worktree list --porcelain`, since a path can contain spaces. Remove a temporary release worktree after the run, including on failure.

Record the outcome in the description's `Released as:` line: the version cut, or that it was skipped and why. A skip exits 0. A failed pull or release does not undo the merge or stop the relay: report the failure to Prateek with the script's output, record it in the description, and continue. The next land's release includes the change. Do not release from the driver's branch, and do not name a version by hand to get past a skip.

Then empty your list for Prateek. Everything you would have written under "for Prateek to look at" ends in one of four places, and none of them is the brief:

- **A decision the relay made** is already in the description. Nothing more.
- **A defect**, found on the way or declined in review as real and out of scope, becomes a build issue. Write its draft in `.scratch/winmux-fork/build/` in the house form, create the issue from the rendered draft, link it as a sub-issue of the build umbrella and add it to the umbrella's child list and draft. A defect you know of before the merge has its draft in the issue's own pull request. One found at Land goes in a docs pull request of its own, merged when CI is green on a head that contains `fork/fork`; the rest of the gate has nothing to check in it. This covers defects only: an issue that adds or changes behaviour Prateek has not asked for is a question.
- **A question** becomes a child of #84: the context, the choices, your recommendation, and the issue that builds on the answer. Label that issue `blocked on Prateek` when the answer could change it.
- **A check** only Prateek can make becomes a line in **Prateek's checks on an installed build and real hardware** (#85), under the issue's title, with the exact steps and what a pass looks like. Its draft is `49-prateeks-checks.md`; change the draft and the body together.

Finish the rest of `AGENTS.md` step 8: retarget any stacked pull request after merging `fork` into it, remove the issue worktree and both branches, and `$VM down relay-<issue number>`. `orca worktree rm --worktree path:<path> --force` removes the worktree in the background: wait until `git worktree list` no longer shows it. Orca deletes the local branch only when it can prove it merged, which a squash hides from it, so run `git branch -D prateek/<slug>` if `git branch --list` still shows it, and delete the remote branch yourself with `git push fork --delete prateek/<slug>`.

Done when the issue is closed, its body matches its draft, the release is recorded as cut, skipped or failed, every item for Prateek is a decision in the description, a build issue, a child of #84 or a line in #85, the issue worktree, both branches, any temporary release worktree and the guest are gone, and `fork/fork` is at the merge commit.

## 11. Hand off

Run `/ho --here Continue the issue relay; Run the issue-relay skill.` The brief names the umbrella, the next issue, what this issue left for the next one to build on, and the release version cut (or that it was skipped or failed, with the reason). It links #84 and lists nothing from it: no "for Prateek to look at", and no "still open from earlier briefs".

A brief carries what is true of this handoff. What is true of the relay goes into this skill, the builder briefs, or the `vm` and `demo` skills, in the issue's pull request or a docs pull request merged under the gate, so the next driver reads it in step 1 and nobody copies it forward. Before writing "things that will bite", move each one that will still be true in five issues to the file it belongs in.

## How long things take

For setting `<hours>` and knowing when something is stuck: a builder pass, 25 minutes to 4 hours; `make check` on host and guest together, 5 to 6 minutes; CI, 10 to 14 minutes with a 30-minute limit; `/code-review high`, about 10 minutes; a demo pass, 15 to 50 minutes; the release, 4 to 8 minutes; an image build, 15 minutes.

## Stops

Stop the relay, leave everything where it is, and tell Prateek what is blocked and what you recommend, when:

- The brief names no umbrella.
- No buildable child of the umbrella is open, or the brief names an issue that is closed or still blocked.
- `ho` is not invocable.
- The golden image is missing, or a fresh guest's preflight fails.
- Something is still pending after the second builder pass and your own fixes.
- A demo still shows the change wrong after a fix and a second filming.
- CI stays red: for a reason in the change after the second pass, or for a reason outside it after one re-run, such as the runner failing to resolve a registry.
- An issue body was edited on GitHub and differs from its rendered draft.
