# WinMux fork

A personal fork of WinMux. The trunk is `fork`; `main` only mirrors upstream. The build plan is [issue #1](https://github.com/prateek/winmux/issues/1), and `.scratch/winmux-fork/handoff.md` orients a new session.

## Landing work

Every change reaches `fork` through a pull request, squash-merged after CI passes and Prateek has reviewed it.

1. **Branch.** Work in an Orca worktree cut from `fork/fork`. Work that depends on an unmerged pull request branches from that pull request's branch.
2. **Check.** Run `make check`. It is what CI runs, and it needs cargo for the `winmux-nickel` helper.
3. **Open the pull request.** Push the branch to the `fork` remote, which is SSH, and open the pull request on `prateek/winmux` against `fork`. Stacked work targets the branch it depends on.
4. **Describe it.** Say what changes and why, where the work departs from its issue, what was checked, and what was not checked.
5. **Show it.** Attach screenshots and video demos of anything a person can see or operate: UI, an animation, CLI output worth reading. Attach them with `gh attach`. A change with nothing to show says so in the description.
6. **Wait for CI.** The step is done when the `Build and test` check is green on the latest commit.
7. **Merge when Prateek says to.** Squash, and write the squash message as a commit message: a subject, then a body that explains the change. The pull request text is for the reviewer and stays on the pull request.
8. **Finish.** Each of these is part of landing:
   - Update the issue body from its draft in `.scratch/winmux-fork/build/`, so the two stay the same.
   - Retarget a stacked pull request to `fork`, after merging `fork` into its branch.
   - Remove the worktree and delete the branch, locally and on the remote.

CI runs on pull requests and on pushes to `main`, so a pull request is the only place a change to `fork` gets tested.

## Releases

`script/dogfood-release <version>` publishes a prerelease, replaces the Sparkle feed and bumps the Homebrew cask. Run it from `fork`, and only when Prateek has asked for that release. `--dry-run` builds, signs and verifies everything and publishes nothing.
