---
name: issue-relay
description: Run the issue relay on prateek/winmux, where Codex builds the next child issue of the umbrella issue the brief names, an Opus driver reviews, fixes and merges it, then hands off to the next driver. Use when a handoff brief or Prateek says to run or continue the relay.
---

# Issue relay

You are the **driver**. Each driver lands exactly one child issue of the **umbrella**, the issue on prateek/winmux that the brief names as the relay's umbrella, then passes the baton. Codex is the **builder**: it writes the code and the tests, checks its work in a live run, and films the demos. You judge, fix and land. `AGENTS.md` at the repo root is the landing process; this skill adds who does each step and when the relay stops.

Every debug build runs in a **guest**, a Tart VM from the `vm` skill, named `relay-<issue number>`. The host's desktop is never part of a run. A driver holds one guest: two relays can run side by side; a third waits.

Nothing in a relay waits on Prateek: no question to him through your harness, and no step held for his password, his sudo or a login. What only he can give goes where [Items for Prateek](#items-for-prateek) says, and the relay carries on. The relay halts only at a **stop**, and [Stops](#stops) lists every one.

The steps say what you do and when it is done. [reference.md](reference.md) holds the mechanics they point to; open the named section when a step names it.

## Where you work

- Run from the worktree the brief started you in, and keep it on its branch: the next driver starts beside you and reads `$SKILL` from it. Read a pull request or another branch with `gh pr diff`, `git show`, or a worktree of its own.
- Trunk is `fork/fork` after a `git fetch fork`; write it that way, since bare `fork` names both a remote and a branch here and is ambiguous. Read it with `git show`, since another session may hold the worktree that has `fork` checked out.
- Your shell is zsh, where an unquoted `$var` holding several issue numbers is one argument: hold a list in an array.
- `$SKILL` is this skill's directory, `$VM` is `.claude/skills/vm/vm`, `$WT` the issue worktree, and `$STATE` is `${XDG_STATE_HOME:-$HOME/.local/state}/issue-relay/<issue number>`, which holds the builder's prompts, logs, captures, storyboard, demos and description draft.

## 1. Orient

Read the brief named in your prompt, `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, and the `vm` and `demo` skills end to end. Check that the relay can finish: the installed `ho` skill (`~/.agents/plugins/plugins/utils-agent/skills/ho/SKILL.md`) has no `disable-model-invocation` line, or step 11 cannot run, and `tart list` shows `winmux-golden`.

Done when you can name the umbrella, and the issue the brief points to or that it points to none, `ho` is invocable, and the golden image exists.

## 2. Pick the issue

Take the brief's next issue. When it names none, take the open child of the umbrella whose blockers are all closed, preferring the one the handoff's **Next** line names. Read the issue and its draft in `.scratch/winmux-fork/build/`.

Before taking an issue, read the open children of **Open with Prateek** (prateek/winmux #84). A child is not buildable when:

- it is labelled `blocked on Prateek`;
- the handoff lists it as **Done, with checks left**: its remaining installed-build and hardware checks are Prateek's;
- it builds on a question still open under #84. Label it `blocked on Prateek`, comment with the question's number, and take the next child. A rule Prateek has not agreed to is not built on, whatever the draft says.

When the draft says each of its parts is its own pull request, the relay builds one **part** per driver, and the part is the issue for every step below. The builder brief scopes the pass to that part, the draft ticks only its Done-when items and says the part landed on its own, the closing line is `Part of #<issue>` as [The pull request description](#the-pull-request-description) says, and the issue stays open. The handoff names the next part as the next issue. The last part closes it.

Done when you have one issue number and its draft. When no buildable child of the umbrella is open, the relay is over: stop and tell Prateek.

## 3. Cut the worktree and bring up the guest

`git fetch fork`, then `orca worktree create --repo id:b2cfff9e-e8d3-4db1-9795-83a57e421be8 --name <slug> --no-parent`, then `make helper` in it. Orca creates the branch too, as `prateek/<slug>`: use that name in the builder's prompt and when deleting the remote branch. Then `$VM up relay-<issue number>`. Export `TART_HOME` in every shell, put `TART_HOME=<value>` in front of every builder launch line, and fill its value into every builder brief.

The guest is yours to keep alive from here to Land, as [The guest](reference.md#the-guest) says. When `up` refuses for room, that section's wait applies.

Done when `$WT` is on a fresh branch at `fork/fork` and the guest's preflight passes.

## 4. First builder pass

Fill [codex-brief.md](codex-brief.md)'s **Every pass** and **First pass**, in that order, into `$STATE/pass1.prompt.md`.

- **Rulings.** Settle in the rulings slot what the issue leaves open, before the builder guesses. Number them, with file and line references at a named commit and the names that must be gone afterwards. Write each ruling for the case it is about and say what stays the same in the neighbouring cases. Read it for what the person does next, not only for what the issue says. Check it against the prototype; where the prototype and the issue's **Decisions** disagree the Decisions win, and the ruling says so. Before a ruling says existing tests pass unchanged, look for a test that pins the behaviour the issue fixes, and name it as the exception: a builder told to stop rather than edit a test stops there.
- **Order of importance.** Say what to keep when time runs short.
- **Hours.** `<hours>` is the launch's `--timeout` in hours; change both together. [How long things take](reference.md#how-long-things-take) has the range.

Launch the pass and read how it ended as [Launching a builder pass](reference.md#launching-a-builder-pass) says.

Done when the log ends on the path of the builder's report, `$WT` has its commits, and `$STATE` has `pr.md` and `report.md`. A builder that stopped short, by timeout or otherwise, leaves its work in `$WT`; what is missing is **pending** for step 7.

## 5. Verify and open the pull request

Check the builder's work:

- Read the whole diff, test hunks, vendored and generated files included, against the issue's **Decisions** and not only its Done-when list: a builder can meet every Done-when item and still build a default a Decision overrules.
- Look for guards removed and fields given a second meaning, which is how a builder widens a change to satisfy a ruling, and compare the builder's verdicts with its own numbers.
- A change to the shipped defaults can break a config that removes a default: check it against a config that uses the documented removal recipe, before the release.
- Read the builder's report against `$STATE/captures/`: each visible Done-when item it marks met has a capture that shows it.
- Run `make check` on the host and in the guest: `$VM sync relay-<n> $WT`, then `$VM check relay-<n>`. A green guest check does not promise green CI until **One pinned toolchain for CI, the guest and the release** lands: both are Swift 6.4.0, from different toolchains.

Then follow `AGENTS.md` steps 3, 4 and 6: push, open the pull request as a draft with the description written as [The pull request description](#the-pull-request-description) says, and wait for CI as [Waiting for CI](reference.md#waiting-for-ci) says.

Done when the draft pull request is open with its description, and `Build and test` has a result.

## 6. Review and fix

Run `/code-review high <pull request number> --max-findings all`, telling it the pull request is on `prateek/winmux` and what the change claims, so it compares paths with the base; for a second run give it the commit range and what those commits claim to fix. It runs for about ten minutes in the background. Pass `--max-findings all` on every run: without it a run reports at most ten findings, so a run that returned ten had hit its cap, not the bottom, and the last choice sticks for every `/code-review` on the machine until one runs with `--max-findings default`.

Verify each finding against the code, and check a finding's precondition in the code before declining it as rare. Fix the ones that hold, each with a test seen to fail without its fix where a test can show it, and record each declined finding with its reason in the description. Push the fixes in one push with every change they imply in the draft, the handoff and the skills: each commit after a green run costs a CI run and, under the gate, a guest check. Then wait for CI.

A third round that finds as much as the first says the rulings are wrong somewhere, not that the fixes are: reread them against the findings, and put what remains into step 7's pass.

Done when every finding is fixed or declined with a reason, and CI is green on the head.

## 7. Follow-up builder pass, at most one

Something is **pending** when a Done-when item is unmet, a visible one has no live-run evidence, a CI failure is the change's own, or a finding is too large to fix inline. Every Done-when item ends one of three ways:

- **met**, with its evidence;
- **left to Prateek**, because it needs an installed build, a real keyboard or hardware a guest lacks; it becomes a check at Land, as [Items for Prateek](#items-for-prateek) says;
- **pending**.

An item a guest could meet and the first pass did not is pending. Landing with it unticked and no follow-up pass is not one of the three.

With anything pending, fill **Every pass** and **Follow-up pass** into `$STATE/pass2.prompt.md` with the list and a ruling on each item, written as step 4's rulings are. Launch it with `pass2` names as [Launching a builder pass](reference.md#launching-a-builder-pass) says, then repeat steps 5 and 6 on the new commits.

Done when nothing is pending. Anything still pending after this pass and your own fixes is a stop.

## 8. Demos

The demos are filmed once, from the commit that will merge, so they show the fixes too. Finish the review's fixes before the storyboard goes out: the demos are then the fixes' live check, and a fix after filming costs a fresh guest, a `make check` and a whole filming.

1. Write `$STATE/storyboard.md` yourself, as the `demo` skill's step 1 says: you have read the issue, the diff and the review, and the storyboard is where you decide what a reviewer needs to see.
2. Fill **Every pass** and **Demo pass** into `$STATE/demo.prompt.md`, naming each thing no live run has seen since the builder's last one. Launch it with `demo` names as [Launching a builder pass](reference.md#launching-a-builder-pass) says.
3. Check every demo the builder made as the `demo` skill's step 5 says, and each take's reported ending against its **Watch**.
   - A take that misses its **Watch** because of the filming is filmed again: launch the demo pass once more, with the list.
   - A take that shows the change is wrong is a finding. Fix it as step 6 says, then film every demo again from the new head. If the second filming still shows it wrong, that is a stop.
   - A demo that cannot be filmed stays in the Done-when table with its reason.
4. Attach the GIFs with `gh attach --repo prateek/winmux <pull request number> <files>` and put the captions from `$STATE/demos.md` into the description.

A change with nothing to see or operate skips the builder, and the description says there is nothing to show. When every claim is a still or a transcript, collect them yourself in a fresh clone and say so in the description.

Done when the description has the demos under their captions with the Done-when table, or says there is nothing to show.

## 9. Merge

The **merge gate** holds when all of these do:

- `Build and test` is green on the head.
- The head contains the tip of `fork/fork`: `git merge-base --is-ancestor fork/fork HEAD` after a fetch. Otherwise merge `fork/fork` in, push and wait for CI.
- `make check` passed in the guest on the head itself. A **docs-only** commit, one that changes only Markdown files or `.scratch/`, leaves the result as it was, and the description says so. Run it again after any other commit; it takes a few minutes.
- Every finding is fixed or declined with a reason.
- The description has the demos or says there is nothing to show, and the demos show the head. When a commit lands after filming, film again, unless the commit cannot change what a demo shows; then the description names the filmed commit, the commits since and why no demo changes.
- Every Done-when item is met or left to Prateek, as step 7 says.
- When your harness gives you a reviewer or advisor tool that you would consult before merging and it is unavailable, a second model checks the gate against this list through the `utils-agent:acpx` skill before you merge, and the description says so.

When the gate holds, `gh pr ready <pull request number> -R prateek/winmux`, and squash-merge as `AGENTS.md` step 7 says: `gh pr merge <pr> -R prateek/winmux --squash --match-head-commit <sha> --body-file <file>`. Pass no `--subject`, so the subject stays `<title> (#<pr>)`, and no `--delete-branch`. The body ends with the closing line [The pull request description](#the-pull-request-description) names and the `Co-Authored-By` line. Prateek authorised merging under this gate; it replaces his per-merge go-ahead for the relay only.

Done when the pull request is merged.

## 10. Land

1. Update the issue body from its draft as [Issue bodies](reference.md#issue-bodies) says. GitHub closes the issue and ticks the umbrella's list itself from `Closes #<issue>`, within a minute of the merge; check both, and close or tick by hand only what it left. Then `git fetch fork`.
2. Cut the release as `AGENTS.md`'s Releases section says, after the squash merge and before removing the issue worktree, **on the host**, with the full output saved to `$STATE/release.log`. Remove a temporary release worktree after the run, failure included. The release comes from the `fork` checkout, never from the driver's branch, and a skip stands: no version named by hand to get past it. Record the outcome on the description's `Released as:` line. A failed pull or release does not undo the merge or stop the relay: report it to Prateek with the script's output, record it on that line, and continue.
3. Empty your list for Prateek: each item ends where [Items for Prateek](#items-for-prateek) says, and none of them in the brief.
4. Finish the rest of `AGENTS.md` step 8: retarget any stacked pull request after merging `fork` into it, then remove the issue worktree and both branches as [Cleaning up](reference.md#cleaning-up) says, and `$VM down relay-<issue number>`.

Done when the issue is closed, its body matches its draft, the release is recorded as cut, skipped or failed, every item for Prateek is a decision in the description, a build issue, a child of #84 or a line in #85, the issue worktree, both branches, any temporary release worktree and the guest are gone, and `fork/fork` is at the merge commit.

## 11. Hand off

Run `/ho --here Continue the issue relay; Run the issue-relay skill.` The brief names the umbrella, the next issue, what this issue left for the next one to build on, and the release version cut (or that it was skipped or failed, with the reason). It links #84 and lists nothing from it: no "for Prateek to look at", and no "still open from earlier briefs".

A brief carries what is true of this handoff. What is true of the relay goes into this skill, the builder briefs, or the `vm` and `demo` skills, in the issue's pull request or a docs pull request merged under the gate, so the next driver reads it in step 1 and nobody copies it forward. Before writing "things that will bite", move each one that will still be true in five issues to the file it belongs in.

Done when `ho` has started the next driver.

## The pull request description

The driver writes it, from `$STATE/pr.md` read as raw material: check the notes for home paths, capture file names and overclaims. It is short enough to read in two minutes, puts the summary first, and names no capture file. Besides what `AGENTS.md` step 4 asks for, it carries:

- **Decisions the relay made**, a section listing each answer the relay chose, as [Items for Prateek](#items-for-prateek) says.
- Each declined finding with its reason, from step 6.
- The demos under their captions with the Done-when table, from step 8; or a `Demos:` line saying there is nothing to show, and why.
- Any gate note step 9 asks for: a docs-only commit after the guest check, a commit after filming, a second model's gate check.

It ends with two lines:

- `Released as:` the version cut, or that the release was skipped and why, or that it failed. Write `Released as: pending` until step 10 fills it.
- `Closes #<issue>`, or `Part of #<issue>` for a part.

The squash body ends with the same closing line. GitHub reads "close", "fix" or "resolve" followed by an issue number anywhere in a pull request's description or squash body as closing that issue, even in a sentence that says the issue stays open: for a part, write the issue number next to none of those words.

## Items for Prateek

Everything you would have written under "for Prateek to look at" ends in one of four places. None of them is the brief.

- **A decision the relay made.** A question no issue settles does not stop the relay: take the recommended answer and list it in the description under **Decisions the relay made** so Prateek can reverse it. A new or vendored dependency is listed there with its tradeoff. A decision listed there is final unless he says otherwise, and no brief repeats it. When you expect him to reverse one, or it sets a rule a later issue builds on, it is also a question.
- **A defect**, found on the way or declined in review as real and out of scope, becomes a build issue. Write its draft in `.scratch/winmux-fork/build/` in the house form, create the issue from the rendered draft as [Issue bodies](reference.md#issue-bodies) says, link it as a sub-issue of the build umbrella and add it to the umbrella's child list and draft. A defect you know of before the merge has its draft in the issue's own pull request. One found at Land goes in a docs pull request of its own, merged when CI is green on a head that contains `fork/fork`; the rest of the gate has nothing to check in it. This covers defects only: an issue that adds or changes behaviour Prateek has not asked for is a question.
- **A question** becomes a child of #84: the context, the choices, your recommendation, and the issue that builds on the answer. Label that issue `blocked on Prateek` when the answer could change it.
- **A check** only Prateek can make becomes a line in **Prateek's checks on an installed build and real hardware** (#85), under the issue's title, with the exact steps and what a pass looks like. Its draft is `49-prateeks-checks.md`; change the draft and the body together.

## Stops

Stop the relay, leave everything where it is, and tell Prateek what is blocked and what you recommend, when:

- The brief names no umbrella.
- No buildable child of the umbrella is open, or the brief names an issue that is closed or still blocked.
- `ho` is not invocable.
- The golden image is missing, or a fresh guest's preflight fails.
- Something is still pending after the follow-up pass and your own fixes.
- A demo still shows the change wrong after a fix and a second filming.
- CI stays red: for a reason in the change after the follow-up pass, or for a reason outside it after one re-run, such as the runner failing to resolve a registry.
- An issue body was edited on GitHub and differs from its rendered draft.

Waiting for room for a guest, a model at capacity, a sandboxed builder and a failed release are not stops: the sections that name them say how to carry on.
