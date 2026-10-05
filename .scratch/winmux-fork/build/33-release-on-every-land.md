# Release a dogfood build on every land to `fork`

Part of {{UMBRELLA}}.

## What to build

`script/dogfood-release --next` makes a release the last step of landing: whoever merges a pull request into `fork` then cuts a release from it, on the build machine. The installed build on a daily machine follows the trunk without anyone deciding to release.

It is first in the umbrella so that every later issue reaches an installed build as it lands.

## Decisions

- **The release runs on the build machine, as the last step of landing.** The signing identity and the Sparkle private key stay on that machine. Nothing is exported to GitHub, and no GitHub job releases. Prateek chose this on 2026-10-04.
- **GitHub CI stays the gate.** `Build and test` on the pull request decides whether it merges, as today. It is free for this repository, which is public. The release is not a check; it runs after the merge.
- **Who runs it.** The `issue-relay` driver, in its Land step. For a pull request Prateek approves outside the relay, whoever merges it.
- **The script picks the version.** `script/dogfood-release --next` releases the next `<base>-dogfood.N` for the base in `VERSION`. It reads the highest numeric N among tags for that exact base from the release remote, not local tags; with no matching tag it starts at .1. Naming a version by hand still works and is never skipped. The build number stays the commit count.
- **It releases what is on `fork`.** Publishing runs from a clean `fork` checkout. The script asks the release remote where `fork` is and refuses unless the local `fork` is there, with a message to pull. `--dry-run` keeps its branch exemption but refuses local changes, including untracked files. The build pins its starting commit and refuses publication if the checkout changes during the run (apart from the two generated version files).
- **The same self-signed certificate signs every release.** It is what keeps Accessibility and Screen Recording grants across upgrades.
- **A failed release does not undo the merge.** The lander reports the failure to Prateek with the script's output and carries on. The next land's release includes the change. The script records a publishing run that did not finish, on the build machine. The next `--next` from the same commit finishes that version when its tag was created; from a later commit it releases even when only docs changed since. The record clears only after a successful publication, never after a dry run.
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

- **Lands that change nothing in the product.** A diff from the latest release for the current base to `HEAD` that touches only `.scratch/`, `.claude/`, `docs/` and Markdown files (`.md` or `.markdown`, case-insensitive) skips the release, and the lander says it was skipped. This replaces the original per-land diff: a failed release followed by docs must not lose a product change. A run with nothing changed since the latest release skips too. When the release commit cannot be found, or an earlier publishing run did not finish, release. `--next` reports a skip and exits 0.
- **One at a time.** The script takes a lock on a file in the build machine's state directory, one per release repository, before it checks the tree and chooses a version. A second run says it is waiting. The kernel releases the lock when its holder exits or dies, so a killed release leaves nothing to clean up.
- **Where the relay runs it.** After the squash merge, find the checkout with `fork` checked out using `git worktree list`, then `git pull --ff-only` and release there before removing the issue worktree. If none holds `fork`, add a temporary worktree on it, pull, release and remove it, including on failure.
- **A bad build reaches installed machines through Sparkle.** `AGENTS.md` says so, with the command that pins the cask to an older version.
- **The live run for this issue is a host dry run.** The builder builds, signs and verifies with `--next --dry-run` and publishes nothing. The driver cuts the first real release after the merge; Prateek checks an upgrade on a daily machine with existing grants. This replaces the original real-release builder default.

## Done when

- [x] `script/dogfood-release --next` on `fork` cuts the next dogfood version with no version argument, and `--next --dry-run` names it without publishing.
- [x] The script refuses to publish from a branch other than `fork`, and refuses any run with local changes (the dry run keeps its branch exemption).
- [x] A land whose diff is only drafts and docs is skipped with a message.
- [x] `AGENTS.md` and the `issue-relay` skill's Land step include the release.
- [x] One release was cut this way, and `brew upgrade --cask winmux` on a machine with existing grants kept them. `0.5.6-dogfood.2` and `0.5.6-dogfood.3` were cut by `--next`. The upgrade was checked in a Tart guest on 2026-10-04: `.2` installed from the tap, Accessibility and Screen Recording granted to `com.zimengxiong.winmux` against that build's code requirement, then `brew upgrade --cask winmux` to `.3`, which reported both granted. The grants were written into the guest's TCC database, not clicked in System Settings, and the app was started by launchd, because Gatekeeper's Open Anyway step needs a person. An upgrade on a daily machine has not been watched.
- [x] A test covers picking the next version from existing tags, and the skip rule.

The version-selection and publishing path are built and covered by offline tests; two host `--next --dry-run` runs built, signed and verified `0.5.6-dogfood.2`. Publication was the driver's check at Land and the grant-preserving upgrade was checked in a guest afterwards; the item above records both. Host and CI-version guest `make check` passed: 62 Rust, 890 Swift and 40 Python tests, including 34 release tests.

## Sources

- **Dogfood releases: cut a signed build from `fork` and install it through the tap**, which built the script.
- [`script/dogfood-release`](https://github.com/prateek/winmux/blob/fork/script/dogfood-release)
