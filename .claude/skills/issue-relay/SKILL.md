---
name: issue-relay
description: Run the issue relay on prateek/winmux, where Codex builds the next child issue of the umbrella issue the brief names, an Opus driver reviews, fixes and merges it, then hands off to the next driver. Use when a handoff brief or Prateek says to run or continue the relay.
---

# Issue relay

You are the **driver**. Each driver lands exactly one child issue of the **umbrella**, the issue on prateek/winmux that the brief names as the relay's umbrella, then passes the baton. Codex is the **builder**: it writes the code and the tests, checks its work in a live run, and films the demos. You judge, fix and land. `AGENTS.md` at the repo root is the landing process; this skill adds who does each step and when the relay stops.

Every debug build runs in a **guest**, a Tart VM from the `vm` skill, named `relay-<issue number>`. The host's desktop is never part of a run. A driver holds one guest: two relays can run side by side; a third waits.

Nothing in a relay waits on Prateek: no question to him through your harness, and no step held for his password, his sudo or a login. What only he can give goes where [Items for Prateek](#items-for-prateek) says, and the relay carries on. When the issue in hand needs it, label the issue `blocked on Prateek`, put the question in #84, and take the next child. The relay halts only at a **stop**, and [Stops](#stops) lists every one.

The steps say what you do and when it is done. [reference.md](reference.md) holds the mechanics they point to; open the named section when a step names it.

## Where you work

- `$SKILL` is this skill's directory, `$VM` is `.claude/skills/vm/vm`, `$WT` the issue worktree, and `$STATE` is `${XDG_STATE_HOME:-$HOME/.local/state}/issue-relay/<issue number>`, which holds the builder's prompts, logs, captures, storyboard, demos and description draft.
- Run from the worktree the brief started you in, and keep it on its branch: the next driver starts beside you and reads `$SKILL` from it. Read a pull request or another branch with `gh pr diff`, `git show`, or a worktree of its own.
- Trunk is `fork/fork` after a `git fetch fork`; write it that way, since bare `fork` names both a remote and a branch here and is ambiguous. Read it with `git show`, since another session may hold the worktree that has `fork` checked out.
- Your shell is zsh, where an unquoted `$var` holding several issue numbers is one argument: hold a list in an array.

## 1. Orient

Read the brief named in your prompt, `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, and the `vm` and `demo` skills end to end. The brief's **For the next pull request** section, when it has one, lists rules the last driver learned too late for its own pull request: they go into yours at step 6. Check that the relay can finish: the installed `ho` skill (`~/.agents/plugins/plugins/utils-agent/skills/ho/SKILL.md`) has no `disable-model-invocation` line, or step 11 cannot run, and `tart list` shows `winmux-golden`.

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

- **Rulings.** Settle in the rulings slot what the issue leaves open, before the builder guesses. A choice that `AGENTS.md`'s **Scope and compatibility** settles, such as whether an old path keeps answering, is a ruling, not a question for #84. Number them, with file and line references at a named commit and the names that must be gone afterwards. Write each ruling for the case it is about and say what stays the same in the neighbouring cases. Read it for what the person does next, not only for what the issue says. Check it against the prototype; where the prototype and the issue's **Decisions** disagree the Decisions win, and the ruling says so. Before a ruling says what an existing form of a command does, parse that form at the named commit: a ruling about a form that does not exist gets that form built, as #122's "plain `place` places the window" did. Before a ruling says existing tests pass unchanged, look for a test that pins the behaviour the issue fixes, in the Swift tests and in `nickel-helper/tests` alike, since a shipped default is pinned in both, and name each as an exception: a builder told to stop rather than edit a test stops there. A ruling on signal handling or another race names the mechanism that closes the window, such as blocking signals or setting explicit state before the raise, not the shape of a handler: a design that infers from interpreter state whether something is in flight leaves a window that each review round finds. A ruling on pointer-dependent UI state, such as hover or the selection under a still pointer, names the one source that state is derived from and where it is cleared: state written from several places is what #126's review rounds kept finding. A ruling on state that follows a held key names the event stream (`flagsChanged`, and the modifier flags each key or pointer event carries) as its source, and the live modifier read only where no event is in hand, such as a deadline: the live state can run ahead of the queued events, and #243's second and third review rounds were spent moving reads from one to the other. A ruling on a tree mutation names the tree the shipped normalization leaves as what the mutation is chosen against, not the tree before the mutation: with `enable-normalization-flatten-containers` and `enable-normalization-opposite-orientation-for-nested-containers` on by default, a split left with one child is flattened and a container then running its parent's way is flipped. #254's second to fourth review rounds were spent finding the layouts where a choice made before normalization came out turned. A red/green run follows [Red and green runs](reference.md#red-and-green-runs).
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

Run `/code-review high <pull request number> --max-findings all`, telling it the pull request is on `prateek/winmux` and what the change claims, so it compares paths with the base; for a second run give it the commit range and what those commits claim to fix. It runs for two to thirteen minutes in the background, longer on the first round of a large change. Pass `--max-findings all` on every run: without it a run reports at most ten findings, so a run that returned ten had hit its cap, not the bottom, and the last choice sticks for every `/code-review` on the machine until one runs with `--max-findings default`. Keep `all` a word of its own: `--max-findings all.` with a full stop is not a valid value, the run says it ignored the flag on its first line, and the cap of ten applies. Read that line before trusting the count. Tell it also to read the pull request with `gh pr diff` and `git show`, and not to check it out: a run on #212 left the driver's checkout detached at the pull request's head, under every session reading `$SKILL` there. After each run, `git status -sb` in your checkout should still name your branch.

Verify each finding against the code, and check its precondition in the code before you decide. A finding whose setup the issue and `AGENTS.md`'s Scope and compatibility put out of scope, or that asks WinMux to take on a helper that Scope and compatibility's **What is WinMux's** test leaves to a script over the CLI, is declined with that reason, not fixed, and a real defect among them becomes a build issue, as Items for Prateek says; one whose setup only an installed build or real hardware can show, and the code alone cannot confirm, is a check for Prateek, as Items for Prateek says, neither fixed nor declined. Fix the cause the finding names, and when the finding names a symptom, find the cause before the fix: a fix for a symptom is the next round's finding. When the fix for a finding reaches into behaviour the issue does not own, such as another command, another target, or a code path the issue's Decisions never mention, keep the narrow fix for the issue's own path and file the rest as a defect with what the review found: #241's second and third rounds cost about twenty findings and three guest checks widening a floating-window fix from tab targets to directions, then reverting it. Fix the ones that hold, each with a test seen to fail without its fix where a test can show it, and record each declined finding with its reason in the description. Before the push, classify every Done-when item as step 7 says, so you know which are left to Prateek. Then push the fixes in one push with everything else the pull request carries as of now: the changes they imply in the draft and the handoff, any relay note for this skill or the `vm` and `demo` skills, the rules the brief carried under **For the next pull request**, and the `49-prateeks-checks.md` line for each item left to Prateek, as [Items for Prateek](#items-for-prateek) says. Every push carries all of that as of its moment, since you cannot know which push is the last: each commit after a green run costs a CI run and, under the gate, a guest check. Then wait for CI.

When a round finds a window in the fix before it, or names the design as the cause, the next commit changes the design or declines the whole area; it does not patch the window. Take the design the review names in one commit, with a test for each window the rounds found; or decline it with the reason, which is the issue's Decision when one rules the design out. Each later finding in that area is still verified against the code, and one the design decision covers is declined with that decision as its reason; a real defect among them becomes a build issue. A third commit on the same window makes the item pending for step 7's pass, with the design as its ruling.

On a prototype, whose page or program ships nothing, the review's value is in the drafts it hands to a later build: tell `/code-review` to report statements a builder would follow into a wrong implementation, and decline in one place, from the first round, findings that the prototype differs from WinMux in ways its claims do not depend on. Listing those departures in its README is the decline. #130 spent four of its five rounds on the page's fidelity to native tree normalization. When the feature draft waits on Prateek's pick of look, its rulings say from the start that the visual details (each stroke, fill, shadow and preview the look touches) are settled from the pick, with their owners named, and the review declines that area from the first round: #131 spent three rounds specifying the chrome of a look he had not yet picked.

Run the next round on a commit `make check` has passed, with the range and what each fix claims. A round that finds no behavioural defect in the code the last fix changed ends the review: fix its test, docs and wording findings in the push, without another round. A behavioural defect that round finds in other code is fixed, and its fix gets the next round. A behavioural defect is a wrong result a test can show or a person can see; a log line's shape, a message's wording or a redundant check is not.

Done when every finding is fixed, declined with a reason, or a check for Prateek, and CI is green on the head.

## 7. Follow-up builder pass, at most one

Something is **pending** when a Done-when item is unmet, a visible one has no live-run evidence, a CI failure is the change's own, or a finding is too large to fix inline. Every Done-when item ends one of four ways:

- **met**, with its evidence;
- **left to Prateek**, because it needs an installed build, a real keyboard or hardware a guest lacks, or because its demo cannot be filmed, as step 8 says; it becomes a check at Land, as [Items for Prateek](#items-for-prateek) says;
- **pending**;
- **met, demo to follow**: the builder's live run showed it, with a capture in `$STATE/captures/`, and step 8 films it. An item that reads "the pull request shows …" is classed this way once the live run has shown what it names. It is ticked in the draft by every push from this classification on, and the gate checks the demo. An item whose demo cannot be filmed becomes **left to Prateek**, and its #85 line goes in at Land as Items for Prateek says, and the description names the item as left to Prateek; its untick and its `49-prateeks-checks.md` line go to the next driver under the brief's **For the next pull request**.

An item a guest could meet and the first pass did not is pending. Landing with it unticked and no follow-up pass is not one of the four.

With anything pending, fill **Every pass** and **Follow-up pass** into `$STATE/pass2.prompt.md` with the list and a ruling on each item, written as step 4's rulings are. Launch it with `pass2` names as [Launching a builder pass](reference.md#launching-a-builder-pass) says, then repeat steps 5 and 6 on the new commits.

Done when nothing is pending. Anything still pending after this pass and your own fixes is a stop.

## 8. Demos

The demos are filmed once, from the commit that will merge, so they show the fixes too. Finish the review's fixes before the storyboard goes out: the demos are then the fixes' live check, and a fix after filming costs a fresh guest, a `make check` and a whole filming.

1. Write `$STATE/storyboard.md` yourself, as the `demo` skill's step 1 says: you have read the issue, the diff and the review, and the storyboard is where you decide what a reviewer needs to see.
2. When the storyboard films the rich set, the guest must be at 1920 × 1080 before the demo pass starts: `$VM stop relay-<n>`, then `$VM up relay-<n> 1920x1080`, from your own shell. Never leave that restart to the builder: a guest it restarts from its own shell dies with that shell, as one did in #125's demo pass.
3. Fill **Every pass** and **Demo pass** into `$STATE/demo.prompt.md`, naming each thing no live run has seen since the builder's last one. The storyboard, `demos.md` and the captures live in `$STATE`, not on the branch, so filming adds no commit. Launch it with `demo` names as [Launching a builder pass](reference.md#launching-a-builder-pass) says.
4. Check every demo the builder made as the `demo` skill's step 5 says, and each take's reported ending against its **Watch**.
   - A take that misses its **Watch** because of the filming is filmed again: launch the demo pass once more, with the list.
   - A take that shows the change is wrong is a finding. Fix it as step 6 says, then film every demo again from the new head. If the second filming still shows it wrong, that is a stop.
   - A demo that cannot be filmed stays in the Done-when table with its reason, and the item is left to Prateek as step 7 says.
5. Attach the GIFs with `gh attach --repo prateek/winmux <pull request number> <files>` and put the captions from `$STATE/demos.md` into the description.

When the last builder pass filmed takes with `film` or `trace-film`, event logs included, from code that is unchanged at the head, you may render the demos from those takes instead of launching a demo pass; the description names the filmed commit.

A change with nothing to see or operate skips the builder, and the description says there is nothing to show. When every claim is a still or a transcript, collect them yourself in a fresh clone and say so in the description.

Done when the description has the demos under their captions with the Done-when table, or says there is nothing to show.

## 9. Merge

The **merge gate** holds when all of these do:

- `Build and test` is green on the head.
- The head contains the tip of `fork/fork`: `git merge-base --is-ancestor fork/fork HEAD` after a fetch. Otherwise merge `fork/fork` in, push and wait for CI; that push carries the merge and nothing else.
- `make check` passed in the guest on the head itself. A **docs-only** commit, one that changes only Markdown files or `.scratch/`, leaves the result as it was, and the description says so. Run it again after any other commit; it takes a few minutes.
- Every finding is fixed, declined with a reason, or a check for Prateek.
- The description has the demos or says there is nothing to show, and the demos show the head. An item step 7 classed **met, demo to follow** holds the gate until a demo under its caption shows its claim; a demo that shows it wrong is a finding, as step 8 says, and the fix's push carries the draft as it then stands. When a commit lands after filming, film again, unless the commit cannot change what a demo shows; then the description names the filmed commit, the commits since and why no demo changes.
- Every Done-when item is met, met with its demo showing it, or left to Prateek, as step 7 says.
- When your harness gives you a reviewer or advisor tool that you would consult before merging and it is unavailable, a second model checks the gate against this list through the `utils-agent:acpx` skill before you merge, and the description says so.

The **last push** is the one the gate's green run is on. After it the branch changes only for a finding, a demo that shows the change wrong, or the `fork/fork` merge above; a docs change learned later goes where [Items for Prateek](#items-for-prateek) and step 11 say, never into a commit of its own.

When the gate holds, `gh pr ready <pull request number> -R prateek/winmux`, and squash-merge as `AGENTS.md` step 7 says: `gh pr merge <pr> -R prateek/winmux --squash --match-head-commit <sha> --body-file <file>`. Pass no `--subject`, so the subject stays `<title> (#<pr>)`, and no `--delete-branch`. The body ends with the closing line [The pull request description](#the-pull-request-description) names and the `Co-Authored-By` line. Prateek authorised merging under this gate; it replaces his per-merge go-ahead for the relay only.

Done when the pull request is merged.

## 10. Land

1. Update the issue body from its draft as [Issue bodies](reference.md#issue-bodies) says. GitHub closes the issue and ticks the umbrella's list itself from `Closes #<issue>`, within a minute of the merge; check both, and close or tick by hand only what it left. Then `git fetch fork`.
2. Cut the release as `AGENTS.md`'s Releases section says, after the squash merge and before removing the issue worktree, **on the host**, with the full output saved to `$STATE/release.log`. Remove a temporary release worktree after the run, failure included. The release comes from the `fork` checkout, never from the driver's branch, and a skip stands: no version named by hand to get past it. Record the outcome on the description's `Released as:` line. A failed pull or release does not undo the merge or stop the relay: report it to Prateek with the script's output, record it on that line, and continue. When the pull request carries a cask change, push it to the tap now, after the release has pushed its bump, as `AGENTS.md`'s **Scope and compatibility** says; a skipped or failed release leaves it unpushed, and the description says so.
3. Empty your list for Prateek: each item ends where [Items for Prateek](#items-for-prateek) says, and none of them in the brief.
4. Finish the rest of `AGENTS.md` step 8: retarget any stacked pull request after merging `fork` into it, then remove the issue worktree and both branches as [Cleaning up](reference.md#cleaning-up) says, and `$VM down relay-<issue number>`.

Done when the issue is closed, its body matches its draft, the release is recorded as cut, skipped or failed, every item for Prateek is a decision in the description, a build issue, a child of #84, a line in #85 or an entry in `docs/dotfiles-handoff.md`, the issue worktree, both branches, any temporary release worktree and the guest are gone, and `fork/fork` is at the merge commit.

## 11. Hand off

Run `/ho --here Continue the issue relay; Run the issue-relay skill.` The brief names the umbrella, the next issue, what this issue left for the next one to build on, and the release version cut (or that it was skipped or failed, with the reason). It links #84 and lists nothing from it: no "for Prateek to look at", and no "still open from earlier briefs".

A brief carries what is true of this handoff. What is true of the relay goes into this skill, the builder briefs, or the `vm` and `demo` skills, in the issue's pull request by its last push, so the next driver reads it in step 1 and nobody copies it forward. A rule learned after the last push is the one exception: the brief names it under **For the next pull request**, with the file it belongs in, and the next driver puts it in its own pull request by that one's last push. Before writing "things that will bite", move each one that will still be true in five issues to the file it belongs in.

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

Everything you would have written under "for Prateek to look at" ends in one of five places. None of them is the brief.

- **A decision the relay made.** A question no issue settles does not stop the relay: take the recommended answer and list it in the description under **Decisions the relay made** so Prateek can reverse it. A new or vendored dependency is listed there with its tradeoff. A decision listed there is final unless he says otherwise, and no brief repeats it. When you expect him to reverse one, or it sets a rule a later issue builds on, it is also a question, unless `AGENTS.md`'s **Scope and compatibility** settles it: then it is a decision only.
- **A defect**, found on the way or declined in review as real and out of scope, becomes a build issue. Write its draft in `.scratch/winmux-fork/build/` in the house form, create the issue from the rendered draft as [Issue bodies](reference.md#issue-bodies) says, link it as a sub-issue of the build umbrella and add it to the umbrella's child list and draft. A defect you know of by the last push has its draft in the issue's own pull request. One found after it goes in a docs pull request of its own at Land, merged when CI is green on a head that contains `fork/fork`; the rest of the gate has nothing to check in it. This covers defects only: an issue that adds or changes behaviour Prateek has not asked for is a question.
- **A question** becomes a child of #84: the context, the choices, your recommendation, and the issue that builds on the answer. Label that issue `blocked on Prateek` when the answer could change it.
- **A check** only Prateek can make becomes a line in **Prateek's checks on an installed build and real hardware** (#85), under the issue's title, with the exact steps and what a pass looks like. Its draft is `49-prateeks-checks.md`: the line goes into the issue's pull request with step 6's push, once step 7's classification names the item, and the same line goes into #85's live body at Land. A check found after the last push still goes into #85's body at Land, so nothing for Prateek waits on it; its draft line goes to the next driver under the brief's **For the next pull request**.
- **A dotfiles change** is appended to `docs/dotfiles-handoff.md`, as `AGENTS.md`'s **Scope and compatibility** says, in the issue's pull request by its last push. One learned after the last push goes to the next driver under the brief's **For the next pull request**.

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
