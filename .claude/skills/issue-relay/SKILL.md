---
name: issue-relay
description: Run the issue relay on prateek/winmux, where Codex builds the next child issue of #1, an Opus driver reviews, fixes and merges it, then hands off to the next driver. Use when a handoff brief or Prateek says to run or continue the relay.
---

# Issue relay

You are the **driver**. Each driver lands exactly one child issue of [#1](https://github.com/prateek/winmux/issues/1), then passes the baton. Codex is the **builder**: it writes the code, the tests and the live-run captures. You judge, fix and land. `AGENTS.md` at the repo root is the landing process; this skill adds who does each step and when the relay stops.

Run from the trunk checkout, the worktree on `fork`. The issue's worktree is removed when the issue lands, and the next driver starts beside you.

Paths below: `$SKILL` is this skill's directory, `$WT` the issue worktree, and `$STATE` is `${XDG_STATE_HOME:-$HOME/.local/state}/issue-relay/<issue number>`, which holds the builder's prompts, logs, captures and description draft.

## 1. Orient

Read the brief named in your prompt, `AGENTS.md`, and `.scratch/winmux-fork/handoff.md` end to end.

Done when you can name the issue the brief points to, or the brief points to none.

## 2. Pick the issue

Take the brief's next issue. When it names none, take the open child of #1 whose blockers are all closed, preferring the one the handoff's **Next** line names. Read the issue and its draft in `.scratch/winmux-fork/build/`.

Done when you have one issue number and its draft. When no buildable child of #1 is open, the relay is over: stop and tell Prateek.

## 3. Cut the worktree

`orca worktree create --repo id:<repo id> --name <slug> --no-parent`, with the repo id from the memory file `winmux-fork-trunk-branch.md`, then `make helper` in it.

Done when `$WT` is on a fresh branch at `fork/fork`.

## 4. Builder pass

Fill [codex-brief.md](codex-brief.md)'s **First pass** into `$STATE/pass1.prompt.md`. Launch it in the background (`run_in_background`) through the shared ACPX view, and wait for the notification:

```sh
~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --log "$STATE/pass1.log" --label sol -- \
  --cwd "$WT" --format text --suppress-reads --approve-all --timeout 14400 --prompt-retries 2 \
  --agent "$SKILL/codex-sol" exec -f "$STATE/pass1.prompt.md"
```

Done when the log ends on the builder's report, and `$WT` has its commits, `$STATE/pr.md`, and the captures the brief asks for. A builder that stopped short of that gets one resume with what is missing; a second shortfall is a stop.

## 5. Verify and open the pull request

Read the whole diff. Run `make check` yourself. Open every capture and look for usernames, home paths, machine names and other people's content. Then follow `AGENTS.md` steps 3 to 6: push, open the pull request from `$STATE/pr.md`, attach the captures with `gh attach --repo prateek/winmux`, and wait for CI.

Done when the pull request is open with its captures and `Build and test` has a result.

## 6. Review and fix

Run `/code-review high <pull request number>`. Verify each finding against the code. Fix the ones that hold, each with a test where a test can show it, and record each declined finding with its reason in the description. Push, and wait for CI.

Done when every finding is fixed or declined with a reason, and CI is green on the head.

## 7. Second builder pass, at most one

Something is **pending** when a Done-when item is unmet, a capture is missing, a CI failure is the change's own, or a finding is too large to fix inline. With anything pending, fill **Follow-up pass** into `$STATE/pass2.prompt.md` with the list, launch it as in step 4 with `pass2` names, then repeat steps 5 and 6 on the new commits.

Done when nothing is pending. Anything still pending after the second pass and your own fixes is a stop.

## 8. Merge

The merge gate holds when `Build and test` is green on the head, every finding is fixed or declined with a reason, and the description has the live run or says there is nothing to show. Then squash-merge as `AGENTS.md` step 7 says, with `--match-head-commit`. Prateek authorised merging under this gate; it replaces his per-merge go-ahead for the relay only.

A question no issue settles does not stop the relay. Take the recommended answer, and list it in the description under **Decisions the relay made** so Prateek can reverse it.

## 9. Land

Do `AGENTS.md` step 8. Before updating an issue body from its draft, diff the live body against the draft at the commit before this change; an edit made only on GitHub is a stop. Close the issue, then `git pull --ff-only` the trunk checkout.

Done when the issue is closed, its body matches its draft, the worktree and both branches are gone, and the trunk checkout is at the merge commit.

## 10. Hand off

Run `/ho --here Continue the issue relay; Run the issue-relay skill.` The brief names the next issue, what this issue left open, and anything Prateek should look at.

## Stops

Stop the relay, leave everything where it is, and tell Prateek what is blocked and what you recommend, when:

- No buildable child of #1 is open.
- Something is still pending after the second builder pass and your own fixes, or CI stays red for a reason in the change.
- An issue body was edited on GitHub and differs from its draft.

A CI failure outside the change, such as the runner failing to resolve a registry, gets one re-run first.
