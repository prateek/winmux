---
name: issue-relay
description: Run the issue relay on prateek/winmux, where Codex builds the next child issue of #1, an Opus driver reviews, fixes and merges it, then hands off to the next driver. Use when a handoff brief or Prateek says to run or continue the relay.
---

# Issue relay

You are the **driver**. Each driver lands exactly one child issue of [#1](https://github.com/prateek/winmux/issues/1), then passes the baton. Codex is the **builder**: it writes the code and the tests, checks its work in a live run, and films the demos. You judge, fix and land. `AGENTS.md` at the repo root is the landing process; this skill adds who does each step and when the relay stops.

Run from the trunk checkout, the worktree on `fork`. The issue's worktree is removed when the issue lands, and the next driver starts beside you.

Every debug build runs in a **guest**, a Tart VM from the `vm` skill, named `relay-<issue number>`. The host's desktop is never part of a run.

Paths below: `$SKILL` is this skill's directory, `$VM` is `.claude/skills/vm/vm`, `$WT` the issue worktree, and `$STATE` is `${XDG_STATE_HOME:-$HOME/.local/state}/issue-relay/<issue number>`, which holds the builder's prompts, logs, captures, storyboard, demos and description draft.

## 1. Orient

Read the brief named in your prompt, `AGENTS.md`, `.scratch/winmux-fork/handoff.md`, and the `vm` and `demo` skills end to end. Confirm the relay can finish: the installed `ho` skill (`~/.agents/plugins/plugins/utils-agent/skills/ho/SKILL.md`) must lack `disable-model-invocation`, or step 11 cannot run, and `tart list` must show `winmux-golden`.

Done when you can name the issue the brief points to, or the brief points to none, `ho` is invocable, and the golden image exists.

## 2. Pick the issue

Take the brief's next issue. When it names none, take the open child of #1 whose blockers are all closed, preferring the one the handoff's **Next** line names. A child the handoff lists as **Done, with checks left** is not buildable: its remaining checks are Prateek's, as are releases. Read the issue and its draft in `.scratch/winmux-fork/build/`.

Done when you have one issue number and its draft. When no buildable child of #1 is open, the relay is over: stop and tell Prateek.

## 3. Cut the worktree and bring up the guest

`git fetch fork`, then `orca worktree create --repo id:b2cfff9e-e8d3-4db1-9795-83a57e421be8 --name <slug> --no-parent`, then `make helper` in it. Then `$VM up relay-<issue number>`.

Done when `$WT` is on a fresh branch at `fork/fork` and the guest's preflight passes.

## 4. Builder pass

Fill [codex-brief.md](codex-brief.md)'s **First pass** into `$STATE/pass1.prompt.md`. Launch it in the background (`run_in_background`) through the shared ACPX view, and wait for the notification:

```sh
~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --log "$STATE/pass1.log" --label sol -- \
  --cwd "$WT" --format text --suppress-reads --approve-all --timeout 14400 --prompt-retries 2 \
  --agent "$SKILL/codex-sol" exec -f "$STATE/pass1.prompt.md"
```

Done when the log ends on the builder's report, and `$WT` has its commits and `$STATE` has `pr.md` and `report.md`. A builder that stopped short, by timeout or otherwise, leaves its work in `$WT`; what is missing becomes pending work for step 7.

## 5. Verify and open the pull request

Read the whole diff. Run `make check` yourself, on the host and in the guest (`$VM sync relay-<n> $WT`, then `$VM check relay-<n>`). Then follow `AGENTS.md` steps 3, 4 and 6: push, open the pull request as a draft from `$STATE/pr.md`, and wait for CI. The demos come in step 8.

Done when the draft pull request is open and `Build and test` has a result.

## 6. Review and fix

Run `/code-review high <pull request number>`, telling it the pull request is on `prateek/winmux`. Verify each finding against the code. Fix the ones that hold, each with a test seen to fail without its fix where a test can show it, and record each declined finding with its reason in the description. Push, and wait for CI.

Done when every finding is fixed or declined with a reason, and CI is green on the head.

## 7. Second builder pass, at most one

Something is **pending** when a Done-when item is unmet, a CI failure is the change's own, or a finding is too large to fix inline. With anything pending, fill **Follow-up pass** into `$STATE/pass2.prompt.md` with the list and a ruling on each item, launch it as in step 4 with `pass2` names, then repeat steps 5 and 6 on the new commits.

Done when nothing is pending. Anything still pending after the second pass and your own fixes is a stop.

## 8. Demos

The demos are filmed once, from the commit that will merge, so they show the fixes too.

Write `$STATE/storyboard.md` yourself, as the `demo` skill's step 1 says: you have read the issue, the diff and the review, and the storyboard is where you decide what a reviewer needs to see. Then fill **Demo pass** into `$STATE/demo.prompt.md` and launch it as in step 4 with `demo` names.

Check every demo the builder made as the `demo` skill's step 5 says, and each take's reported ending against its **Watch**. Attach the GIFs with `gh attach --repo prateek/winmux`, put the captions from `$STATE/demos.md` into the description, and `gh pr ready`.

A change with nothing to see or operate skips the builder: the description says there is nothing to show.

Done when the description has the demos under their captions with the Done-when table, or says there is nothing to show.

## 9. Merge

The merge gate holds when `Build and test` is green on the head, every finding is fixed or declined with a reason, and the description has the demos or says there is nothing to show. Then squash-merge as `AGENTS.md` step 7 says, with `--match-head-commit`. Prateek authorised merging under this gate; it replaces his per-merge go-ahead for the relay only.

A question no issue settles does not stop the relay. Take the recommended answer, and list it in the description under **Decisions the relay made** so Prateek can reverse it.

## 10. Land

Do `AGENTS.md` step 8, and `$VM down relay-<issue number>`. An issue body is its draft **rendered**: without the draft's first two lines (the title heading and the blank after it), with `{{UMBRELLA}}` replaced by `#1`. Before updating a body, compare the live body with the draft rendered at the commit before this change, ignoring a trailing newline; any other difference is an edit made only on GitHub, and a stop. Close the issue, then `git pull --ff-only` the trunk checkout.

Done when the issue is closed, its body matches its draft, the worktree, both branches and the guest are gone, and the trunk checkout is at the merge commit.

## 11. Hand off

Run `/ho --here Continue the issue relay; Run the issue-relay skill.` The brief names the next issue, what this issue left open, and anything Prateek should look at.

## Stops

Stop the relay, leave everything where it is, and tell Prateek what is blocked and what you recommend, when:

- No buildable child of #1 is open, or the brief names an issue that is closed or still blocked.
- `ho` is not invocable.
- The golden image is missing, or a fresh guest's preflight fails.
- Something is still pending after the second builder pass and your own fixes.
- CI stays red: for a reason in the change after the second pass, or for a reason outside it after one re-run, such as the runner failing to resolve a registry.
- An issue body was edited on GitHub and differs from its rendered draft.
