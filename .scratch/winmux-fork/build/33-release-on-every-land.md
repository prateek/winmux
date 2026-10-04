# Release a dogfood build on every land to `fork`

Part of {{UMBRELLA}}.

## What to build

Today `script/dogfood-release` runs only when Prateek asks. This issue makes a release the last step of landing: whoever merges a pull request into `fork` then cuts a release from it, on the build machine. The installed build on a daily machine follows the trunk without anyone deciding to release.

It is first in the umbrella so that every later issue reaches an installed build as it lands.

## Decisions

- **The release runs on the build machine, as the last step of landing.** The signing identity and the Sparkle private key stay on that machine. Nothing is exported to GitHub, and no GitHub job releases. Prateek chose this on 2026-10-04.
- **GitHub CI stays the gate.** `Build and test` on the pull request decides whether it merges, as today. It is free for this repository, which is public. The release is not a check; it runs after the merge.
- **Who runs it.** The `issue-relay` driver, in its Land step. For a pull request Prateek approves outside the relay, whoever merges it.
- **The script picks the version.** `script/dogfood-release --next` releases the next `<base>-dogfood.N` for the base in `VERSION`. Naming a version by hand still works. The build number stays the commit count.
- **It releases what is on `fork`.** The script runs from an up-to-date `fork` checkout and refuses to run from any other branch or with local changes.
- **The same self-signed certificate signs every release.** It is what keeps Accessibility and Screen Recording grants across upgrades.
- **A failed release does not undo the merge.** The lander reports the failure to Prateek with the script's output and carries on. The next land's release includes the change.
- **`AGENTS.md` changes with it.** The Releases section says a release follows every land and how, and step 8 of Landing work gains the release.

## Not in this issue

- A job that watches `fork`. A merge made on the GitHub web page releases nothing until the next land or a manual run.
- Notarization.
- Upstream's `release.yml`, which fires on pushes to `main`. It is left alone.
- A rollback mechanism. Rolling back is reinstalling an older cask version.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Lands that change nothing in the product.** A land whose diff touches only `.scratch/`, `.claude/`, `docs/` and Markdown files skips the release, and the lander says it was skipped. `--next` reports this and exits 0.
- **One at a time.** The script takes a lock, so two lands close together release in order.
- **Where the relay runs it.** After the squash merge and the `git pull --ff-only`, before the worktree is removed, in the trunk checkout.
- **A bad build reaches installed machines through Sparkle.** `AGENTS.md` says so, with the command that pins the cask to an older version.
- **The live run for this issue is a real release**, since `--dry-run` publishes nothing. The pull request says which version it cut.

## Done when

- [ ] `script/dogfood-release --next` on `fork` cuts the next dogfood version with no version argument, and `--next --dry-run` names it without publishing.
- [ ] The script refuses to run from a branch other than `fork` or with local changes.
- [ ] A land whose diff is only drafts and docs is skipped with a message.
- [ ] `AGENTS.md` and the `issue-relay` skill's Land step include the release.
- [ ] One release was cut this way, and `brew upgrade --cask winmux` on a machine with existing grants kept them.
- [ ] A test covers picking the next version from existing tags, and the skip rule.

## Sources

- **Dogfood releases: cut a signed build from `fork` and install it through the tap**, which built the script.
- [`script/dogfood-release`](https://github.com/prateek/winmux/blob/fork/script/dogfood-release)
