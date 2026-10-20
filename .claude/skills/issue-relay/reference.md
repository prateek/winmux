# Issue relay: reference

The mechanics [SKILL.md](SKILL.md)'s steps point to, in the order the steps reach them. Paths are as `SKILL.md` defines them.

## The guest

The guest is the driver's from step 3 to Land. Bring it up yourself: a guest a builder starts from its own shell dies with that shell's session.

- After every builder pass, read `tart list`. `$VM up` a stopped guest again, which keeps its disk and its build.
- When a builder left it resized, rebooted or showing a prompt, `$VM down` it and bring up a fresh one for your own `make check`. Give the demo pass a fresh clone after a long builder pass.
- The demo pass may restart the guest at 4 cores and 6144 MB when filming stutters, as its brief says; beside one default guest that is exactly the cap.
- When `up` refuses the two-guest limit or the resource cap, say you are waiting and retry every few minutes until room is free. This is a wait, not a stop. A fresh guest failing preflight is still a stop.

## Launching a builder pass

Launch each pass in the background (`run_in_background`) through the shared ACPX view, and wait for the notification. For the first pass, with `pass1` names:

```sh
TART_HOME=<TART_HOME> ~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --log "$STATE/pass1.log" --label sol -- \
  --cwd "$WT" --format text --suppress-reads --approve-all --timeout 14400 --prompt-retries 2 \
  --agent "$SKILL/codex-sol" exec -f "$STATE/pass1.prompt.md"
```

The follow-up and demo passes use the same line with `pass2` and `demo` in place of `pass1`. `--timeout` is in seconds: four hours as written, matching the brief's `<hours>`.

**Check the policy** after every launch, the follow-up and demo passes included. Once the log shows the builder's first `[tool]` line, run `$SKILL/codex-policy "$WT"`. It finds the pass's rollout, prints the approval and sandbox policy the pass is running with, and fails when that is not full access with approvals off. A failing pass runs sandboxed, with no network, a reviewer on every escalated command, and slower. That is not a stop: tell Prateek in your final message, with the line it printed.

**Read how it ended.** The notification is the signal that the builder ended; `<log>.exit` holds its exit code and is the fallback when a notification is missed.

- The log ends `[done] end_turn` when the builder finished its turn.
- Exit 129 means the pane was closed, not that the builder failed.
- Exit 0 is not the report: check that the pass's report and, for a building pass, `pr.md` exist, since a builder can end with its code committed and its paperwork missing.
- A launch can end within a minute with exit 0, `[done] end_turn` and the line "Selected model is at capacity" in its log, having changed nothing. When there are no commits and no report, wait two minutes and launch again.
- A capacity cutoff can also come mid-pass, after the builder has changed files, with no commit and no report. Relaunch the same prompt with a note before it that names the uncommitted work and the logs or takes it left, tells the builder to continue from `git diff` rather than start over, and to commit as soon as its tests pass. #129 needed this three times.

## Red and green runs

A test seen to fail without its fix, in step 6 or in a builder pass, is only evidence when the run that failed was built from the code you think it was:

- `swift build` colours its errors, so `grep " error:"` misses them. Strip the escapes first: `sed 's/\x1b\[[0-9;]*m//g'`.
- A failed build leaves the previous test binary in place, and `swift test --skip-build` runs it. Require `Build complete!` in the log before trusting a run.
- When you add a test, check that the executed test count moved. #254 lost most of a review round to a "red" and a "green" that were both stale binaries.

## Waiting for CI

- After a push, wait until a run exists for the head commit: `gh pr checks` says "no checks reported" for about a minute, and `--watch` can return the previous run's result.
- Wait in the background, since a run outlasts a foreground command: `gh run watch <id> --exit-status`.
- Read the conclusion from `gh pr view --json statusCheckRollup,headRefOid`, matching `headRefOid` to your head. `gh pr checks --watch` can report the run before yours.
- Read the first red run's log at once, before any re-run, and fetch a timed-out job's log straight away, because it does not last.
- Once a re-run has passed, `gh run view <id> --log-failed` prints nothing: the red attempt's log is `gh run view <id> --attempt <n> --log-failed`.

## Issue bodies

An issue body is its draft **rendered**:

- without the draft's first two lines, the title heading and the blank after it;
- with `{{UMBRELLA}}` replaced by the number of the umbrella the issue is a child of, as `#<number>`: #84 for **Prateek's checks**, the umbrella the brief names for a build issue;
- with `{{CHILDREN}}` replaced by one `- [ ] #<number>` line per child, in order.

Before updating a body, compare the live body with the draft rendered at the commit before this change, ignoring a trailing newline. Any other difference is an edit made only on GitHub, and a stop. Make the comparison at Land, with a command whose output you read:

```sh
diff <(printf '%s\n' "$(sed 's/^- \[x\]/- [ ]/' live.md)") <(printf '%s\n' "$(cat expected.md)")
```

It drops trailing newlines from both. A ticked box is not a difference: GitHub ticks an umbrella's list, and Prateek ticks his checks. Then update the body from the draft rendered at the merge.

An umbrella's child list is the exception to rendering `{{CHILDREN}}`. #55's and #271's lists are in build order, kept by hand: not the order the sub-issues API returns, and #55's leaves out #48 and #51, which the prose names. Rendering it from the API reorders it. Compare only the prose with the draft, and add a new child's line to the live list by hand. #55 is at GitHub's limit of 100 sub-issues: linking a new build issue to it fails with HTTP 422 ("Parent cannot have more than 100 sub-issues"). The hand-kept list is the one GitHub ticks, so add the new child there, and say in the pull request description that it is not linked.

#84 and #85 are edited in place and never rendered over: add your line to the live body and the same line to the draft, and leave every tick as it is.

## Cleaning up

- `orca worktree rm --worktree path:<path> --force` removes the worktree in the background: wait until `git worktree list` no longer shows it.
- Orca deletes the local branch only when it can prove it merged, which a squash hides from it: run `git branch -D prateek/<slug>` if `git branch --list` still shows it.
- Delete the remote branch yourself with `git push fork --delete prateek/<slug>`.
- Read the worktree list from `git worktree list --porcelain`, since a path can contain spaces.

## How long things take

For setting `<hours>` and knowing when something is stuck:

| What | How long |
| --- | --- |
| A builder pass | 25 minutes to 4 hours |
| `make check` on host and guest together | 5 to 6 minutes |
| CI | 10 to 14 minutes, with a 30-minute limit |
| `/code-review high` | 2 to 13 minutes, longer on the first round of a large change |
| A demo pass | 15 to 50 minutes |
| The release | 4 to 8 minutes |
| An image build | 15 minutes |
