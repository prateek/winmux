# WinMux fork

A personal fork of WinMux. The trunk is `fork`; `main` only mirrors upstream. The first build plan, [issue #1](https://github.com/prateek/winmux/issues/1), is built; the open work is [issue #55](https://github.com/prateek/winmux/issues/55), and `.scratch/winmux-fork/handoff.md` orients a new session. Questions and checks that wait on Prateek are children of [issue #84](https://github.com/prateek/winmux/issues/84); nothing waits on him anywhere else.

## Landing work

Every change reaches `fork` through a pull request, squash-merged after CI passes and Prateek has reviewed it. The `issue-relay` skill's driver merges under that skill's merge gate instead of waiting for him.

1. **Branch.** Work in an Orca worktree cut from `fork/fork`. Work that depends on an unmerged pull request branches from that pull request's branch.
2. **Check.** Run `make check`. It is what CI runs, and it needs cargo for the `winmux-nickel` helper.
3. **Open the pull request.** Push the branch to the `fork` remote, which is SSH, and open the pull request on `prateek/winmux` against `fork`. Stacked work targets the branch it depends on.
4. **Describe it.** Say what changes and why, where the work departs from its issue, what was checked, and what was not checked.
5. **Show it.** Attach screenshots and video demos of anything a person can see or operate: UI, an animation, CLI output worth reading. Attach them with `gh attach`. A change with nothing to show says so in the description.
6. **Wait for CI.** The step is done when the `Build and test` check is green on the latest commit, and that commit contains the tip of `fork/fork`. When `fork` has moved since, merge it into the branch and wait again: nothing tests a push to `fork`, and the release ships what the merge produces.
7. **Merge when Prateek says to**, or, for the `issue-relay` skill, when its merge gate holds. Squash, and write the squash message as a commit message: a subject, then a body that explains the change. The pull request text is for the reviewer and stays on the pull request.
8. **Finish.** Each of these is part of landing:
   - Update the issue body from its draft in `.scratch/winmux-fork/build/`, so the two stay the same.
   - Retarget a stacked pull request to `fork`, after merging `fork` into its branch.
   - Cut the dogfood release as described below, after the squash merge and pull, before removing the issue worktree.
   - Remove the worktree and delete the branch, locally and on the remote.

CI runs on pull requests and on pushes to `main`, so a pull request is the only place a change to `fork` gets tested.

## Releases

A dogfood release follows every land to `fork`. The `issue-relay` driver cuts it in its Land step; outside the relay, whoever merges the pull request does. It runs on the build machine, where the signing keys stay. GitHub CI remains the merge gate, and the release runs after the merge.

**Cutting it.** After the squash merge and before removing the issue worktree:

1. Find the checkout that has `fork` checked out: the record with `branch refs/heads/fork` in `git worktree list --porcelain`. If there is none, add a temporary one with `git worktree add <directory> fork`, creating `fork` from `fork/fork` when the local branch is absent, and remove it after the release. If the add fails because `fork` is checked out elsewhere, another lander's release is running there: wait and look again.
2. Run `git pull --ff-only` there, then `script/dogfood-release --next`, and keep its full output.
3. Report the version it cut, or that it skipped, or that it failed.

**What `--next` does.**

- **Version.** The base comes from `VERSION`, and the number is one more than the highest `v<base>-dogfood.N` tag on the release remote. A version named by hand still works and is never skipped.
- **Skip.** It publishes nothing and exits 0 when nothing changed since the latest release for that base, or when everything that changed is under `.scratch/`, `.claude/` or `docs/` or is a Markdown file. When that release's commit cannot be found, it releases.
- **Refusals.** Publishing needs `fork` checked out, at the remote's `fork`, with no local changes. `--dry-run` builds, signs and verifies everything and publishes nothing; it runs on any branch and still needs a clean tree.
- **One at a time.** A lock on a file under `$XDG_STATE_HOME/winmux-release/` makes a second run wait for the first. The kernel releases it when its holder dies, so a killed release leaves nothing to clean up.
- **The commit it started on.** The run refuses to publish when the checkout's `HEAD` or files change while it builds. A `git pull` by a second lander during a build does this to the first; the second lander's run then releases both changes.

**When it fails.** A failed release does not undo the merge or stop the relay. Report it to Prateek with the script's output and carry on; the next land's release includes the change. The script records a publishing run that did not finish. The next `--next` from the same commit finishes that version if its tag was created, and from a later commit it releases even when only docs changed since.

**A bad build** reaches installed machines through Sparkle. To go back to an older version:

1. Quit WinMux and reinstall from the tap's cask at the revision for that version, where both its version and SHA-256 match the package.
2. `brew pin --cask winmux` holds that version against `brew upgrade`; `brew unpin --cask winmux` lets it go.
3. The cask declares `auto_updates true`, so the pin does not stop Sparkle. Before starting the older build, run `defaults write com.zimengxiong.winmux SUEnableAutomaticChecks -bool false` and `defaults write com.zimengxiong.winmux SUAutomaticallyUpdate -bool false`.
