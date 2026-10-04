# WinMux fork

A personal fork of WinMux. The trunk is `fork`; `main` only mirrors upstream. The first build plan, [issue #1](https://github.com/prateek/winmux/issues/1), is built; the open work is [issue #55](https://github.com/prateek/winmux/issues/55), and `.scratch/winmux-fork/handoff.md` orients a new session.

## Landing work

Every change reaches `fork` through a pull request, squash-merged after CI passes and Prateek has reviewed it. The `issue-relay` skill's driver merges under that skill's merge gate instead of waiting for him.

1. **Branch.** Work in an Orca worktree cut from `fork/fork`. Work that depends on an unmerged pull request branches from that pull request's branch.
2. **Check.** Run `make check`. It is what CI runs, and it needs cargo for the `winmux-nickel` helper.
3. **Open the pull request.** Push the branch to the `fork` remote, which is SSH, and open the pull request on `prateek/winmux` against `fork`. Stacked work targets the branch it depends on.
4. **Describe it.** Say what changes and why, where the work departs from its issue, what was checked, and what was not checked.
5. **Show it.** Attach screenshots and video demos of anything a person can see or operate: UI, an animation, CLI output worth reading. Attach them with `gh attach`. A change with nothing to show says so in the description.
6. **Wait for CI.** The step is done when the `Build and test` check is green on the latest commit.
7. **Merge when Prateek says to**, or, for the `issue-relay` skill, when its merge gate holds. Squash, and write the squash message as a commit message: a subject, then a body that explains the change. The pull request text is for the reviewer and stays on the pull request.
8. **Finish.** Each of these is part of landing:
   - Update the issue body from its draft in `.scratch/winmux-fork/build/`, so the two stay the same.
   - Retarget a stacked pull request to `fork`, after merging `fork` into its branch.
   - Cut the dogfood release as described below, after the squash merge and pull, before removing the issue worktree.
   - Remove the worktree and delete the branch, locally and on the remote.

CI runs on pull requests and on pushes to `main`, so a pull request is the only place a change to `fork` gets tested.

## Releases

A dogfood release follows every land to `fork`. The `issue-relay` driver runs it in Land; outside the relay, whoever merges the pull request runs it. Signing keys stay on the build machine. GitHub CI remains the merge gate; the release runs after the merge.

Find the checkout with `refs/heads/fork` in `git worktree list --porcelain`, then run `git pull --ff-only` and `script/dogfood-release --next` there. If no worktree has `fork` checked out, add a temporary one with `git worktree add <temporary-directory> fork` (create `fork` from `fork/fork` if the local branch is absent), pull and release there, then remove the temporary worktree. Do this after the squash merge, before removing the issue worktree. Keep the release's full output and report its version, skip or failure.

`--next` reads the base from `VERSION` and the highest numeric dogfood suffix from the release remote's tags. It skips a diff that touches only `.scratch/`, `.claude/`, `docs/` and Markdown files (`.md` or `.markdown`, case-insensitive), measured from the latest release for that base to `HEAD`. If that commit is unavailable, it releases. An explicitly named version is never skipped. Publishing requires a clean `fork` checkout at the remote's `fork`; `--dry-run` permits other branches but still requires a clean tree. It builds, signs and verifies everything and publishes nothing. The build is tied to its starting commit; a checkout changed during the run refuses publication. A host-wide directory lock serializes release runs; a dead owner's lock (or one without a valid PID after 30 seconds) requires an operator to confirm no release is running before removing it.

A failed release does not undo the merge or stop the relay. Report it to Prateek with the script's output and continue landing; the next land's release includes the change. A local pending-publication marker prevents a docs-only skip after a run failed between creating the version tag and updating Sparkle or the cask; it clears only after a successful publishing run. Report a docs-only skip as a successful skip.

A bad build reaches installed machines through Sparkle. To roll back, quit WinMux and reinstall an older release using the tap's cask revision for that version (both its version and SHA-256 must match the package). Then `brew pin --cask winmux` pins that installed version against Homebrew upgrades. The tap declares `auto_updates true`, so the pin does not stop Sparkle: while WinMux is quit, run `defaults write com.zimengxiong.winmux SUEnableAutomaticChecks -bool false` and `defaults write com.zimengxiong.winmux SUAutomaticallyUpdate -bool false` before relaunching the older build. `brew unpin --cask winmux` resumes Homebrew upgrades. See [Homebrew pin](https://docs.brew.sh/Manpage#pin-options-installed_formulainstalled_cask-).
